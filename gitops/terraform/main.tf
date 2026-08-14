terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.58.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  # Keep GitOps resources isolated from the main challenge Terraform state.
  backend "s3" {
    bucket       = "tech-challenge-2-bucket"
    key          = "gitops/terraform-state-file"
    use_lockfile = true
    encrypt      = true
    region       = "us-east-2"
  }
}

provider "aws" {
  region = var.aws_region
}

# Read the existing cluster provisioned by the main challenge Terraform stack.
data "aws_eks_cluster" "main" {
  name = var.eks_cluster_name
}

# Authenticate Helm to the existing EKS API without storing Kubernetes tokens.
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
    }
  }
}

# Create GitHub's OIDC role and install Argo CD without changing the main stack.
module "gitops" {
  source = "../../aws-eks-terraform/modules/gitops"

  project_name        = var.project_name
  aws_region          = var.aws_region
  github_repository   = var.github_repository
  github_branch       = "gitops"
  ecr_repository_name = var.ecr_repository_name
  tags = {
    Project     = var.project_name
    Environment = "gitops"
  }
}
