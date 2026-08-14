variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL published by EKS"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider associated with EKS"
  type        = string
}

variable "aws_region" {
  description = "AWS region that contains the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version used to select a matching Cluster Autoscaler image"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace used by cluster services"
  type        = string
  default     = "kube-system"
}

variable "cluster_autoscaler_service_account_name" {
  description = "Kubernetes service account used by Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "tags" {
  description = "Tags added to autoscaling IAM resources"
  type        = map(string)
  default     = {}
}
