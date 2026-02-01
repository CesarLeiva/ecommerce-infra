terraform {
  required_version = ">= 1.13.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Provider para recursos globales (WAF de CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}