# Eleven AWS resources planned against an empty state: the provider makes no
# resource API calls, so fake keys (given as the stack's Environment) plan the
# same as real ones. Used to check a run fits the Helm chart's 1536 MiB
# default sandbox (openplanhq/openplan#513).
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "s" {
  count      = 6
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index)
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.main.id
}

resource "aws_s3_bucket" "b" {
  bucket = "openplan-mem-test-bucket-xyz"
}

resource "aws_iam_role" "r" {
  name = "r"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_instance" "i" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.s[0].id
}
