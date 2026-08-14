variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidr" {
  description = "public subnet CIDR block"
  type        = list(string)
}

variable "private_subnet_cidr" {
  description = "private subnet CIDR block"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "Name of EKS cluster"
  type        = string
}

variable "project_name" {
  description = "Name of project"
  type        = string
  default     = "devops-code-challenge2"
}

variable "environment" {
  description = "Name of environment"
  type        = string
  default     = "dev"
}

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

variable "jenkins_instance_type" {
  description = "EC2 instance type used by Jenkins"
  type        = string
  default     = "t3.small"
}

variable "jenkins_key_name" {
  description = "Existing EC2 key pair used to configure Jenkins over SSH"
  type        = string
  default     = "1PU"
}

variable "jenkins_allowed_cidr_blocks" {
  description = "IPv4 CIDRs allowed to access the Jenkins server"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
