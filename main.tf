terraform {
  backend "s3" {
    bucket         = "bucket-name"
    key            = "terraform/ssm-patch-manager/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.0"
    }
  }
  required_version = ">= 0.13"
 }
