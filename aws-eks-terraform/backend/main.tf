terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.58.0"
    }
  }
}
provider "aws" {
  # Configuration options
  region = "us-east-2"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "tech-challenge-2-bucket"

  lifecycle {
    prevent_destroy = false
  }
}

terraform {
  backend "s3" {
    bucket       = "tech-challenge-2-bucket"
    key          = "dev/terraform-state-file"
    use_lockfile = true
    encrypt      = true
    region       = "us-east-2"
  }
}
