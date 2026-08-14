output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "argocd_release_name" {
  description = "Name of the Argo CD Helm release"
  value       = helm_release.argocd.name
}
