variable "aws_region" {
  description = "AWS region containing the existing EKS cluster and ECR repository"
  type        = string
  default     = "us-east-2"
}

variable "eks_cluster_name" {
  description = "Existing EKS cluster created by the main Terraform stack"
  type        = string
  default     = "devops-eks-cluster"
}

variable "project_name" {
  description = "Project name used for GitOps IAM resources"
  type        = string
  default     = "devops-code-challenge2"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the Actions role"
  type        = string
  default     = "uukomadu/devops-code-challenge2"
}

variable "ecr_repository_name" {
  description = "Existing ECR repository that receives application images"
  type        = string
  default     = "node-app"
}
