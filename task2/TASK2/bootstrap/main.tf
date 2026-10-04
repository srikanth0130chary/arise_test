# Run this ONCE (with local state) to create the bucket + lock table.
# The backend can't create its own bucket, so this has to be done first.

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "bucket_name" {
  description = "Globally unique name for the state bucket"
  type        = string
  default     = "mycompany-tf-state-dev-12345"
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

# keep old versions of the state so we can roll back
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Terraform needs the hash key to be exactly "LockID"
resource "aws_dynamodb_table" "lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "bucket" {
  value = aws_s3_bucket.state.id
}

output "lock_table" {
  value = aws_dynamodb_table.lock.name
}
