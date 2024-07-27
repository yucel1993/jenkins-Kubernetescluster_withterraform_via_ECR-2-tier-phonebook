/*This Terraform Template creates a jenkins server on AWS EC2 Instance
  Jenkins Server is enabled with Git and Docker.
  Jenkins Server will run on Amazon Linux 2023 EC2 Instance with
  custom security group allowing HTTP(80, 8080) and SSH (22) connections from anywhere. 
*/

provider "aws" {
  region = "us-east-1"
  //  access_key = ""
  //  secret_key = ""
  //  If you have entered your credentials in AWS CLI before, you do not need to use these arguments.
}

data "aws_caller_identity" "current" {}

locals {
  key_pair        = "yourpemkey"                   # you need to change this line
  instance_type   = "t3a.medium"
  user            = "just_a_name"
}

variable "sg-ports" {
  default = [80, 22, 8080]
}

resource "aws_security_group" "ec2-sec-gr" {
  name = "jenkins-sec-gr-${local.user}"
  tags = {
    Name = "jenkins-sec-gr"
  }
  dynamic "ingress" {
    for_each = var.sg-ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "roleforjenkins" {
  name                = "ecr_jenkins_permission_${local.user}"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess", "arn:aws:iam::aws:policy/AdministratorAccess"]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "jenkinsprofile-${local.user}"
  role = aws_iam_role.roleforjenkins.name
}

data "aws_ami" "al2023" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
  
  filter {
    name = "name"
    values = ["al2023-ami-2023*"]
  }
}

resource "aws_instance" "jenkins-server" {
  ami           = data.aws_ami.al2023.id
  instance_type = local.instance_type
  key_name      = local.key_pair
  root_block_device {
    volume_size = 16
  }
  vpc_security_group_ids = [aws_security_group.ec2-sec-gr.id]
  tags = {
    Name = "Jenkins-Server-${local.user}"
  }
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  user_data            = <<-EOF
          #! /bin/bash
          # update os
          dnf update -y
          # install git
          dnf install git -y
          # set server hostname as Jenkins-Server
          hostnamectl set-hostname "Jenkins-Server"
          # install java 17 and jenkins
          wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
          rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
          dnf upgrade -y
          dnf install fontconfig java-17-amazon-corretto-devel -y
          dnf install jenkins -y
          systemctl enable jenkins
          systemctl start jenkins
          # install docker
          dnf install docker -y
          systemctl start docker
          systemctl enable docker
          #add ec2-user and jenkins users to docker group
          usermod -a -G docker ec2-user
          usermod -a -G docker jenkins
          # configure docker as cloud agent for jenkins
          systemctl daemon-reload
          systemctl restart docker
          systemctl restart jenkins
          EOF
}

output "jenkins-dns-url" {
  value = "http://${aws_instance.jenkins-server.public_ip}:8080"
}

output "ssh-connection" {
  value = "ssh -i ${local.key_pair}.pem ec2-user@${aws_instance.jenkins-server.public_ip}"
}