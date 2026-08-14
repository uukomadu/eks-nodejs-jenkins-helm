# Identifies the EKS cluster watched by the AWS Load Balancer Controller.
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# Supplies the cluster identity provider used to establish IRSA trust.
variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL exposed by the EKS cluster"
  type        = string
}

# Tells the controller which AWS region to use for API operations.
variable "aws_region" {
  description = "AWS region containing the EKS cluster"
  type        = string
}

# Limits load balancer discovery and creation to the EKS cluster VPC.
variable "vpc_id" {
  description = "VPC in which the controller creates load balancers"
  type        = string
}

# Pins the controller Helm chart to a predictable release.
variable "chart_version" {
  description = "AWS Load Balancer Controller Helm chart version"
  type        = string
  default     = "1.8.1"
}

# Selects the namespace where the controller is installed.
variable "namespace" {
  description = "Kubernetes namespace for the controller"
  type        = string
  default     = "kube-system"
}

# Names the Kubernetes service account mapped to the IAM role.
variable "service_account_name" {
  description = "Kubernetes service account used by the controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

# Adds caller-provided ownership and environment metadata to IAM resources.
variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
