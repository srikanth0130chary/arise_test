# Remote state in S3, locking with DynamoDB.
# Backend blocks can't use variables, so these values are hardcoded.
# Change the bucket name (must be globally unique) and region to match
# what you created in ./bootstrap
terraform {
  backend "s3" {
    bucket         = "mycompany-tf-state-dev-12345"
    key            = "task1/ec2/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
