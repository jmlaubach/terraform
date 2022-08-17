# # Set up the backend for ECS tasks

terraform {
    backend "s3" {
      bucket         = "jlaubach-terraform-state-ecs"
      key            = "global/s3/terraform.tfstate"
      region         = "us-east-1"
      dynamodb_table = "jlaubach-terraform-lock-ecs"
      encrypt        = true
      shared_credentials_file = "/Users/jlaubach/.aws/credentials"
    }
}