terraform {
  required_version = ">=1.6.0"
  required_providers {
    aws ={
        source = "hashicorp/aws"
        version = "~>5.0"
    }
  }
  # For a local lab , local backend is sufficient
  # backend "local" {}
}
provider "aws" {
  region = var.aws_region
  profile = "personal-k8s" # I have a separate AWS profile for my k8s labs
}