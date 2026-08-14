# Read the EKS OIDC endpoint certificate so AWS can validate tokens issued by the cluster.
data "tls_certificate" "eks" {
  url = var.cluster_oidc_issuer_url
}

# Register the EKS OIDC issuer with IAM, enabling Kubernetes service accounts to use IRSA.
resource "aws_iam_openid_connect_provider" "eks" {
  url             = var.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

# Build the trust policy that allows only the controller service account to assume its IAM role.
data "aws_iam_policy_document" "controller_assume_role" {
  # Permit role assumption with a Kubernetes-issued OIDC web identity token.
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    # Trust the OIDC provider associated with this EKS cluster.
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    # Require tokens to be intended for the AWS Security Token Service.
    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict access to the exact namespace and service account used by the controller.
    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

# Create the IAM role assumed by the controller pod through IRSA.
resource "aws_iam_role" "controller" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.controller_assume_role.json
  tags               = var.tags
}

# Define the AWS API permissions needed to discover and manage ALB-related resources.
data "aws_iam_policy_document" "controller" {
  # Allow read-only discovery of VPC, EC2, and Elastic Load Balancing resources.
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTrustStores",
      "elasticloadbalancing:DescribeListenerAttributes"
    ]
    resources = ["*"]
  }

  # Allow optional integrations with certificates, authentication, WAF, and Shield.
  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }

  # Allow the controller to create, update, and delete ALBs and their supporting resources.
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule"
    ]
    resources = ["*"]
  }
}

# Create the customer-managed IAM policy from the controller permissions document.
resource "aws_iam_policy" "controller" {
  name   = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = data.aws_iam_policy_document.controller.json
  tags   = var.tags
}

# Attach the controller policy to the IRSA role before the Helm deployment starts.
resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

# Install the AWS Load Balancer Controller into EKS using the official Helm chart.
resource "helm_release" "controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_version
  namespace  = var.namespace

  # Pass cluster discovery settings and annotate the service account with its IRSA role.
  set = [
    { name = "clusterName", value = var.cluster_name },
    { name = "region", value = var.aws_region },
    { name = "vpcId", value = var.vpc_id },
    { name = "serviceAccount.create", value = "true" },
    { name = "serviceAccount.name", value = var.service_account_name },
    { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.controller.arn }
  ]

  depends_on = [aws_iam_role_policy_attachment.controller]
}
