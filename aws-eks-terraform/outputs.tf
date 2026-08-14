output "cluster_endpoint" {
  description = "Endpoint for the EKS Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "alb_controller_role_arn" {
  description = "IAM role used by the AWS Load Balancer Controller"
  value       = module.alb.controller_role_arn
}

output "jenkins_url" {
  description = "URL of the Jenkins web interface"
  value       = module.jenkins.jenkins_url
}

output "jenkins_instance_id" {
  description = "EC2 instance ID of the Jenkins master"
  value       = module.jenkins.instance_id
}

output "jenkins_security_group_id" {
  description = "Security group attached to the Jenkins server"
  value       = module.jenkins.security_group_id
}

output "jenkins_iam_role_arn" {
  description = "IAM role authorized to push to ECR and deploy to EKS"
  value       = module.jenkins.iam_role_arn
}
