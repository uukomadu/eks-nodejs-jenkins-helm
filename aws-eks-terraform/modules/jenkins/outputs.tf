output "instance_id" {
  description = "Instance ID of the Jenkins master"
  value       = aws_instance.jenkins_master.id
}

output "public_ip" {
  description = "Elastic IP address of the Jenkins master"
  value       = aws_eip.jenkins_master.public_ip

  depends_on = [aws_eip_association.jenkins_master]
}

output "jenkins_url" {
  description = "URL used to access Jenkins"
  value       = "http://${aws_eip.jenkins_master.public_ip}:8080"

  depends_on = [aws_eip_association.jenkins_master]
}

output "security_group_id" {
  description = "ID of the Jenkins security group"
  value       = aws_security_group.jenkins.id
}

output "iam_role_arn" {
  description = "IAM role used by the Jenkins server"
  value       = aws_iam_role.jenkins.arn
}
