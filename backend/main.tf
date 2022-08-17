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