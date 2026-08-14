# Read the active AWS account so the ECR policy is scoped to this account.
data "aws_caller_identity" "current" {}

# Reuse the account-wide GitHub Actions OIDC provider that already exists.
locals {
  github_actions_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

# Restrict role assumption to this repository's dedicated GitOps branch.
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_actions_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # GitHub can vary the subject suffix for branch, environment, and reusable
    # workflow tokens. Limit trust to this repository; the workflow trigger
    # itself remains limited to the dedicated GitOps branch.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:*",
        "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repository_name}@${var.github_repository_id}:*",
      ]
    }
  }
}

# Provide the short-lived IAM role used by GitHub Actions.
resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = var.tags
}

# Grant only the ECR operations required to authenticate and push images.
data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "ECRLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushNodeAppImages"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
    ]
  }
}

# Attach the scoped ECR push policy directly to the GitHub Actions role.
resource "aws_iam_role_policy" "ecr_push" {
  name   = "${var.project_name}-github-actions-ecr"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

# Install the Argo CD controllers into EKS; bootstrap the Application separately.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.17"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    server = {
      service = {
        type = "ClusterIP"
      }
    }
  })]
}
