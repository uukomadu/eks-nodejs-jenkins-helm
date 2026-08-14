# IAM Role for Worker Nodes EKS Instances
resource "aws_iam_role" "eks-cluster-role" {
  name = "${var.eks_cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

# Attach EKS Cluster Policy to Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks-cluster-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# The main EKS Cluster
resource "aws_eks_cluster" "main-eks-cluster" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks-cluster-role.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_id
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# IAM Role for Worker Nodes EC2 Instances
resource "aws_iam_role" "eks_node_role" {
  name = "${var.eks_cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach Required Policies to Worker Node Role
resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  ])

  role       = aws_iam_role.eks_node_role.name
  policy_arn = each.value
}

# Crate EKS Managed Node Group
resource "aws_eks_node_group" "eks-worker-node" {
  for_each        = var.node_groups
  cluster_name    = aws_eks_cluster.main-eks-cluster.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_id

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  scaling_config {
    desired_size = each.value.scaling_config.desired_size
    max_size     = each.value.scaling_config.max_size
    min_size     = each.value.scaling_config.min_size
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policy
  ]
}

# Tag every managed node group's Auto Scaling group for Cluster Autoscaler discovery.
resource "aws_autoscaling_group_tag" "cluster_autoscaler_enabled" {
  for_each = aws_eks_node_group.eks-worker-node

  autoscaling_group_name = each.value.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }
}

# Limit auto-discovery to Auto Scaling groups owned by this EKS cluster.
resource "aws_autoscaling_group_tag" "cluster_autoscaler_cluster" {
  for_each = aws_eks_node_group.eks-worker-node

  autoscaling_group_name = each.value.resources[0].autoscaling_groups[0].name

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.eks_cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }
}
