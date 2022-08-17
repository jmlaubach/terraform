# # Create S3 bucket to host terraform state file

resource "aws_s3_bucket" "state-bucket" {
    bucket = "jlaubach-terraform-state-ecs"
    versioning {
      enabled = true
    }
    server_side_encryption_configuration {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }
}

resource "aws_dynamodb_table" "state-lock" {
    name         = "jlaubach-terraform-lock-ecs"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "LockID"
    attribute {
      name = "LockID"
      type = "S"
    } 
}

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