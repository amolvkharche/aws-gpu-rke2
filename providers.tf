provider "aws" {
  region     = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
  default_tags {
    tags = {
      ClusterName = var.cluster_name
      ManagedBy   = "Terraform"
    }
  }
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = "${path.module}/kubeconfig.yaml"
  }
}
