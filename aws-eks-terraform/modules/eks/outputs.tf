output "cluster_endpoint" {
  description = "Endpoint for the EKS Kubernetes API server"
  value       = aws_eks_cluster.main-eks-cluster.endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main-eks-cluster.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main-eks-cluster.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate data for the EKS API server"
  value       = aws_eks_cluster.main-eks-cluster.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL used to configure IRSA"
  value       = aws_eks_cluster.main-eks-cluster.identity[0].oidc[0].issuer
}
