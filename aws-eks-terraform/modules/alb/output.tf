# Expose the IRSA role ARN for auditing and integration with other modules.
output "controller_role_arn" {
  description = "IAM role assumed by the AWS Load Balancer Controller"
  value       = aws_iam_role.controller.arn
}

# Expose the release name for operational checks and downstream dependencies.
output "helm_release_name" {
  description = "Name of the controller Helm release"
  value       = helm_release.controller.name
}
