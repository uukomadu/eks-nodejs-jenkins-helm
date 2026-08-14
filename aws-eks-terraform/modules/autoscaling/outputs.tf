output "cluster_autoscaler_role_arn" {
  description = "IAM role assumed by Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "cluster_autoscaler_release_name" {
  description = "Name of the Cluster Autoscaler Helm release"
  value       = helm_release.cluster_autoscaler.name
}

output "metrics_server_release_name" {
  description = "Name of the Metrics Server Helm release"
  value       = helm_release.metrics_server.name
}
