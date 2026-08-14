vpc_cidr = "10.0.0.0/16"

public_subnet_cidr = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnet_cidr = [
  "10.0.10.0/24",
  "10.0.20.0/24"
]

availability_zones = [
  "us-east-2a",
  "us-east-2b"
]

eks_cluster_name = "devops-eks-cluster"

project_name = "devops-code-challenge2"

environment = "dev"

aws_region = "us-east-2"

cluster_version = "1.36"

node_groups = {
  standard_workers = {
    instance_types = ["t3.small"]
    capacity_type  = "ON_DEMAND"

    scaling_config = {
      desired_size = 1
      max_size     = 4
      min_size     = 1
    }
  }
}

# Jenkins server settings
jenkins_instance_type = "t3.small"

# Existing EC2 key pair used to connect to the Jenkins server.
jenkins_key_name = "1PU"

# Matches challenge1 so the Jenkins site is reachable for project review.
jenkins_allowed_cidr_blocks = ["0.0.0.0/0"]

# Namespace used by the Helm release configured in Jenkins.
application_namespace = "node-app"
