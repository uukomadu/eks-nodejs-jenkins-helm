variable "project_name" {
  description = "Project name used for Jenkins resource names"
  type        = string
}

variable "environment" {
  description = "Environment tag applied to Jenkins resources"
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC in which Jenkins is provisioned"
  type        = string
}

variable "public_subnet_id" {
  description = "Existing public subnet used by Jenkins"
  type        = string
}

variable "eks_cluster_arn" {
  description = "ARN of the EKS cluster Jenkins deploys to"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type used for Jenkins"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing EC2 key pair used to configure Jenkins over SSH"
  type        = string
}

variable "root_volume_size" {
  description = "Encrypted Jenkins root disk size in GiB"
  type        = number
  default     = 30
}

variable "allowed_cidr_blocks" {
  description = "IPv4 CIDRs allowed to access SSH and Jenkins web ports"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Additional tags applied to Jenkins resources"
  type        = map(string)
  default     = {}
}
