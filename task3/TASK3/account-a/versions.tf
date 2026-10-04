terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  # safety check so this can't be applied to the wrong account by mistake
  allowed_account_ids = [var.account_a_id]
}
