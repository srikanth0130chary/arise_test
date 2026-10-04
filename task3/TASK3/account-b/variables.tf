variable "region" {
  type    = string
  default = "us-east-1"
}

variable "account_a_id" {
  type    = string
  default = "000000000000"
}

variable "account_b_id" {
  type    = string
  default = "111111111111"
}

variable "bucket_name" {
  description = "The one S3 bucket roleC gets full access to (must already exist)"
  type        = string
  default     = "my-task3-bucket" # placeholder, change this
}
