#Block 1 – "Terraform Engine and AWS Provider Setup"
terraform {
  required_version = ">=1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#Block 2 – "Default VPC and Restricted Security Group"

data "aws_vpc" "default" {
  default = true
}
# Hardened Security Group 
resource "aws_security_group" "web_sg" {
  name        = "security-web-sg"
  description = "Security group with restricted ingress"
  vpc_id      = data.aws_vpc.default.id

  # Inbound: Only HTTP port 80
  # bridgecrew: skip=CKV_AWS_260: "Port 80 is required for public HTTP web server demo"
  ingress {
    description = "Allow inbound HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: All traffic allowed 
  # bridgecrew: skip=CKV_AWS_382: "Outbound internet access required for OS updates and package installation"
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "secure-web-sg"
    Environment = "DevSecOps"
  }

}

#Block 3 – "Dynamic Lookup for the Official Amazon Linux 2023 AMI"
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

}

# Baseline IAM Role and Instance Profile for EC2 
resource "aws_iam_role" "ec2_baseline_role" {
    name = "ec2-baseline-security-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_instance_profile" "ec2_profile" {
    name = "ec2-baseline-instance-profile"
    role = aws_iam_role.ec2_baseline_role.name
}

#Block 4 – "Hardened EC2 Instance"
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  ebs_optimized = true 

  #Security Group attach karna jo Block 2 mein banaya tha 
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  #Hardening 1: Root EBS Volume Encription 
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  #Hardening 2: Enforce IMDSv2 (SSRF Protection) 
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  #Hardening 3: Detailed CloudWatch Monitoring 
  monitoring = true

  tags = {
    Name        = "hardened-devsecops-ec2"
    Environment = "DevSecOps"
  }
  # ye old khaali server ko destroy karke naya server banayega ,
  # server boot hote hi apache web server install karega 
  # website ka page ready karega 

  
user_data = <<-EOF
  #!/bin/bash
  dnf update -y
  dnf install -y httpd
  systemctl start httpd
  systemctl enable httpd
  echo "<h1>Hardened DevSecOps EC2 Server is Live!</h1>" > /var/www/html/index.html
  EOF

user_data_replace_on_change = true
}







