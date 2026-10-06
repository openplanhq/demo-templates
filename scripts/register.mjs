#!/usr/bin/env node
/**
 * Register every module in this repository with an openplan instance.
 *
 * openplan has no API tokens: the only way to a session is its OIDC sign-in.
 * So this signs in the way a browser would -- follows /v1/auth/login to the
 * identity provider, fills the password form, and keeps the session cookie the
 * callback sets -- then calls the same API the Register template page does.
 * That works against Dex's password login, which is what the local stack runs.
 *
 * A module is registered from GitHub, not from this checkout: push first. The
 * checkout only says which modules exist.
 *
 * Credentials come from the environment. On openplan's local stack they are
 * Dex's static user, from openplan's deploy/dex/config.yaml:
 *   export OPENPLAN_USER=admin@openplan.local
 *   export OPENPLAN_PASS=<its password, in openplan's docs/authentication.md>
 *
 * Usage:
 *   node scripts/register.mjs
 *   node scripts/register.mjs --only vpc-network,redis-cache
 *   node scripts/register.mjs --sync          # re-register, picking up new commits
 *   node scripts/register.mjs --dry-run       # sign in and list, register nothing
 *
 * Flags:
 *   --url <origin>      openplan's address (default http://localhost:5173)
 *   --repo <owner/name> the GitHub repository (default openplanhq/demo-templates)
 *   --ref <ref>         branch, tag or commit to register (default main)
 *   --only <names>      comma-separated module names; default every module
 *   --sync              register modules that already are, too. openplan
 *                       records a new revision only if the ref moved.
 *   --concurrency <n>   registrations in flight at once (default 4)
 *   --dry-run           print what would be registered and stop
 */
import { readdirSync } from "node:fs";

const argv = process.argv.slice(2);
const options = { url: "http://localhost:5173", repo: "openplanhq/demo-templates", ref: "main", only: null, sync: false, concurrency: 4, dryRun: false };
for (let i = 0; i < argv.length; i++) {
  const next = () => {
    if (i + 1 >= argv.length) fail(`${argv[i]} needs a value.`);
    return argv[++i];
  };
  if (argv[i] === "--url") options.url = next();
  else if (argv[i] === "--repo") options.repo = next();
  else if (argv[i] === "--ref") options.ref = next();
  else if (argv[i] === "--only") options.only = new Set(next().split(",").map((name) => name.trim()).filter(Boolean));
  else if (argv[i] === "--sync") options.sync = true;
  else if (argv[i] === "--concurrency") options.concurrency = Number(next());
  else if (argv[i] === "--dry-run") options.dryRun = true;
  else fail(`Unknown flag ${argv[i]}. See the top of scripts/register.mjs for usage.`);
}

const [repoOwner, repoName, ...rest] = options.repo.split("/");
if (!repoOwner || !repoName || rest.length) fail("--repo takes owner/name, such as openplanhq/demo-templates.");
if (!Number.isInteger(options.concurrency) || options.concurrency < 1) fail("--concurrency takes a whole number of at least 1.");
if (typeof Headers.prototype.getSetCookie !== "function") fail(`Node 20 or newer is needed; this is ${process.version}.`);

const user = process.env.OPENPLAN_USER;
const pass = process.env.OPENPLAN_PASS;
if (!user || !pass) fail("Set OPENPLAN_USER and OPENPLAN_PASS to the account to sign in as. See the top of scripts/register.mjs.");

// Registration is asynchronous: a registration record comes back at once and
// ends in one of these.
const TERMINAL = new Set(["completed", "invalid", "failed"]);
const POLL_INTERVAL_MS = 1000;
const REGISTRATION_TIMEOUT_MS = 5 * 60 * 1000;

const modules = discoverModules();
if (options.only) {
  const unknown = [...options.only].filter((name) => !modules.includes(name));
  if (unknown.length) fail(`No module named ${unknown.join(", ")} under modules/.`);
}
const wanted = modules.filter((name) => !options.only || options.only.has(name));

const jar = cookieJar();
await signIn();

const me = await api("GET", "/v1/me");
if (!me.globalCapabilities?.canPublishTemplate) {
  fail(`Signed in as ${me.email || me.displayName}, who may not register templates.`);
}
const tenant = encodeURIComponent(me.tenantID);

// A template is a repository, a root path and a ref; one that already has a
// revision is skipped unless --sync asks for it again.
const revisions = (await api("GET", `/v1/tenants/${tenant}/template-revisions`)) ?? [];
const registered = new Set(
  revisions
    .filter((revision) => revision.repo_owner === repoOwner && revision.repo_name === repoName && revision.source_ref === options.ref)
    .map((revision) => revision.root_path),
);
const todo = wanted.filter((name) => options.sync || !registered.has(rootPath(name)));
const skipped = wanted.length - todo.length;

console.log(`Signed in to ${options.url} as ${me.email || me.displayName}.`);
console.log(`${wanted.length} modules in ${options.repo}@${options.ref}: ${todo.length} to register, ${skipped} already registered.`);
if (options.dryRun) {
  for (const name of todo) console.log(`  would register  ${rootPath(name)}`);
  process.exit(0);
}

const results = await mapWithConcurrency(todo, options.concurrency, async (name) => {
  const result = await register(name);
  const detail = result.status === "completed" ? result.template_revision_id : result.error_summary || result.error;
  console.log(`${result.status.padEnd(10)}  ${rootPath(name).padEnd(34)}  ${detail}`);
  return result;
});

const failed = results.filter((result) => result.status !== "completed");
console.log(`\n${results.length - failed.length} registered, ${skipped} already registered, ${failed.length} failed.`);
process.exit(failed.length ? 1 : 0);

function discoverModules() {
  const directory = new URL("../modules/", import.meta.url);
  return readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .filter((entry) => readdirSync(new URL(`${entry.name}/`, directory)).some((file) => file.endsWith(".tf")))
    .map((entry) => entry.name)
    .sort();
}

function rootPath(name) {
  return `modules/${name}`;
}

async function register(name) {
  let registration;
  try {
    registration = await api("POST", `/v1/tenants/${tenant}/template-revisions`, {
      repo_owner: repoOwner,
      repo_name: repoName,
      source_ref: options.ref,
      root_path: rootPath(name),
    });
  } catch (error) {
    return { status: "rejected", error: error.message };
  }

  const deadline = Date.now() + REGISTRATION_TIMEOUT_MS;
  while (!TERMINAL.has(registration.status)) {
    if (Date.now() > deadline) return { status: "timed-out", error: `still ${registration.status} after five minutes` };
    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
    registration = await api("GET", `/v1/tenants/${tenant}/template-registrations/${encodeURIComponent(registration.id)}`);
  }
  return registration;
}

// Follows the sign-in redirects by hand, so every cookie set along the way is
// kept, and answers the identity provider's password form when it shows one.
async function signIn() {
  let request = { url: new URL("/v1/auth/login", options.url).href, method: "GET" };
  let submitted = false;
  for (let hop = 0; hop < 20; hop++) {
    const response = await send(request.url, { method: request.method, body: request.body });
    if (response.status >= 300 && response.status < 400 && response.headers.has("location")) {
      request = { url: new URL(response.headers.get("location"), request.url).href, method: "GET" };
      continue;
    }

    const body = await response.text();
    const form = passwordForm(body);
    if (!form) {
      if (response.ok && (await sessionWorks())) return;
      fail(`Sign-in did not finish: ${request.url} answered ${response.status}.`);
    }
    // The provider shows the form again when it refuses the password.
    if (submitted) fail(`The identity provider refused the password for ${user}.`);
    submitted = true;
    request = {
      url: new URL(form.action, request.url).href,
      method: "POST",
      body: new URLSearchParams({ [form.loginField]: user, [form.passwordField]: pass }),
    };
  }
  fail("Sign-in redirected too many times.");
}

// The first <form> holding a password input, with its action and the names of
// its login and password fields. Written for Dex's login page.
function passwordForm(html) {
  for (const [, attributes, inner] of html.matchAll(/<form\b([^>]*)>([\s\S]*?)<\/form>/gi)) {
    const inputs = [...inner.matchAll(/<input\b[^>]*>/gi)].map(([tag]) => ({
      name: attribute(tag, "name"),
      type: (attribute(tag, "type") || "text").toLowerCase(),
    }));
    const password = inputs.find((input) => input.type === "password");
    const login = inputs.find((input) => ["text", "email"].includes(input.type) && input.name);
    if (password?.name && login) {
      return { action: decodeEntities(attribute(attributes, "action") || ""), loginField: login.name, passwordField: password.name };
    }
  }
  return null;
}

function attribute(tag, name) {
  return tag.match(new RegExp(`\\b${name}\\s*=\\s*"([^"]*)"`, "i"))?.[1] ?? null;
}

function decodeEntities(text) {
  return text.replace(/&amp;/g, "&").replace(/&#34;|&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
}

async function sessionWorks() {
  const response = await send(new URL("/v1/me", options.url).href, { method: "GET" });
  return response.ok;
}

async function api(method, path, body) {
  const response = await send(new URL(path, options.url).href, {
    method,
    headers: { accept: "application/json", ...(body ? { "content-type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${method} ${path} answered ${response.status}: ${json?.message || json?.error || text}`);
  }
  return json;
}

async function send(url, { method, headers = {}, body }) {
  const cookie = jar.header(url);
  const response = await fetch(url, {
    method,
    body,
    redirect: "manual",
    headers: { ...headers, ...(cookie ? { cookie } : {}) },
  });
  jar.store(url, response.headers.getSetCookie());
  return response;
}

async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let next = 0;
  const lanes = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const index = next++;
      results[index] = await worker(items[index]);
    }
  });
  await Promise.all(lanes);
  return results;
}

function fail(message) {
  console.error(message);
  process.exit(2);
}

// Cookies by host. Enough for a sign-in: paths, expiry dates and the Secure
// flag are not honoured, only removal by Max-Age=0.
function cookieJar() {
  const hosts = new Map();
  return {
    store(url, setCookies) {
      const { hostname } = new URL(url);
      const cookies = hosts.get(hostname) ?? new Map();
      for (const setCookie of setCookies) {
        const [pair, ...attributes] = setCookie.split(";");
        const at = pair.indexOf("=");
        if (at < 1) continue;
        const name = pair.slice(0, at).trim();
        if (attributes.some((attribute) => /^\s*max-age\s*=\s*(0|-\d+)\s*$/i.test(attribute))) cookies.delete(name);
        else cookies.set(name, pair.slice(at + 1).trim());
      }
      hosts.set(hostname, cookies);
    },
    header(url) {
      const cookies = hosts.get(new URL(url).hostname);
      return cookies ? [...cookies].map(([name, value]) => `${name}=${value}`).join("; ") : "";
    },
  };
}
