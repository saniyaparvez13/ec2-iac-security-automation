# 1. EC2 Instance Public IP Address
output "ec2_public_ip" {
  description = "Public IP address of the hardened EC2 instance"
  value       = aws_instance.web_server.public_ip
}

# 2. EC2 Instance ID
output "ec2_instance_id" {
  description = "ID of the created EC2 instance"
  value       = aws_instance.web_server.id
}

# 3. Security Group ID
output "security_group_id" {
  description = "ID of the hardened Security Group"
  value       = aws_security_group.web_sg.id
}

