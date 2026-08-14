output "github_actions_role_arn" {
  description = "IAM role to save as the AWS_GITHUB_ACTIONS_ROLE_ARN repository variable"
  value       = module.gitops.github_actions_role_arn
}

output "argocd_release_name" {
  description = "Name of the Argo CD Helm release"
  value       = module.gitops.argocd_release_name
}
