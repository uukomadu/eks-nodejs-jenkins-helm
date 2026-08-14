variable "project_name" {
  description = "Project name used in GitOps resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region containing the ECR repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name form"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch used by the GitOps workflow"
  type        = string
  default     = "gitops"
}

variable "ecr_repository_name" {
  description = "ECR repository that stores application images"
  type        = string
  default     = "node-app"
}

variable "tags" {
  description = "Tags applied to AWS GitOps resources"
  type        = map(string)
  default     = {}
}
