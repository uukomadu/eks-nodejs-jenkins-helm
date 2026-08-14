variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"
}

variable "vpc_id" {
  description = "VPC ID for EKS cluster"
  type        = string
  default     = "eks-project"
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"
}

variable "cluster_version" {
  description = "Cluster version"
  type        = string
  default     = "eks-cluster-version"
}

variable "node_groups" {
  description = "EKS node group configuration variable"

  type = map(
    object({
      instance_types = list(string)
      capacity_type  = string

      scaling_config = object({
        desired_size = number
        max_size     = number
        min_size     = number
      })
    })
  )
}