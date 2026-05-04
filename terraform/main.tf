terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "RepairDesk"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repo        = "repairdesk-infra"
    }
  }
}

# ACM for CloudFront MUST be us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "RepairDesk"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
