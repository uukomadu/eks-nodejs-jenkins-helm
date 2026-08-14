variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"
}

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