# Build a trust policy restricted to the Cluster Autoscaler Kubernetes service account.
data "aws_iam_policy_document" "cluster_autoscaler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.cluster_autoscaler_service_account_name}"]
    }
  }
}

# Create the IAM role assumed by Cluster Autoscaler through IRSA.
resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.cluster_name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role.json
  tags               = var.tags
}

# Define the AWS discovery and scaling permissions required by Cluster Autoscaler.
data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

# Create and attach the customer-managed Cluster Autoscaler IAM policy.
resource "aws_iam_policy" "cluster_autoscaler" {
  name   = "${var.cluster_name}-ClusterAutoscalerPolicy"
  policy = data.aws_iam_policy_document.cluster_autoscaler.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# Install Metrics Server so the HPA can read pod CPU and memory utilization.
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = var.namespace

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-preferred-address-types=InternalIP\\,ExternalIP\\,Hostname"
    }
  ]
}

# Install Cluster Autoscaler with node-group auto-discovery and its IRSA role.
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = var.namespace

  set = [
    { name = "autoDiscovery.clusterName", value = var.cluster_name },
    { name = "awsRegion", value = var.aws_region },
    { name = "image.tag", value = "v${var.cluster_version}.0" },
    { name = "rbac.serviceAccount.create", value = "true" },
    { name = "rbac.serviceAccount.name", value = var.cluster_autoscaler_service_account_name },
    { name = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.cluster_autoscaler.arn },
    { name = "extraArgs.balance-similar-node-groups", value = "true" },
    { name = "extraArgs.skip-nodes-with-system-pods", value = "false" },
    { name = "priorityClassName", value = "system-cluster-critical" }
  ]

  depends_on = [aws_iam_role_policy_attachment.cluster_autoscaler]
}
