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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
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

module "vpc" {
  source = "./modules/vpc"

  aws_region          = var.aws_region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zones  = var.availability_zones
  eks_cluster_name    = var.eks_cluster_name
}

module "eks" {
  source = "./modules/eks"

  aws_region       = var.aws_region
  eks_cluster_name = var.eks_cluster_name
  cluster_version  = var.cluster_version
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.private_subnet_ids
  node_groups      = var.node_groups
}

module "alb" {
  source = "./modules/alb"

  cluster_name            = module.eks.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  aws_region              = var.aws_region
  vpc_id                  = module.vpc.vpc_id
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [module.eks]
}

module "autoscaling" {
  source = "./modules/autoscaling"

  cluster_name            = module.eks.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn       = module.alb.oidc_provider_arn
  aws_region              = var.aws_region
  cluster_version         = var.cluster_version
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [module.eks, module.alb]
}

module "jenkins" {
  source = "./modules/jenkins"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_id    = module.vpc.public_subnet_ids[0]
  eks_cluster_arn     = module.eks.cluster_arn
  instance_type       = var.jenkins_instance_type
  key_name            = var.jenkins_key_name
  allowed_cidr_blocks = var.jenkins_allowed_cidr_blocks
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# Allow the Jenkins instance role to authenticate to the EKS cluster.
resource "aws_eks_access_entry" "jenkins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.jenkins.iam_role_arn
  type          = "STANDARD"
}

# Grant Jenkins cluster administration so it can create the application namespace and deploy the Helm release.
resource "aws_eks_access_policy_association" "jenkins" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.jenkins.iam_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.jenkins]
}
