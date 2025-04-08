provider "aws" {
  region = "us-east-1" # Change region if needed
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu) AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "gitlab_key" {
  key_name   = "gitlab-key"
  public_key = file("~/.ssh/id_rsa.pub") # Update path as needed
}

resource "aws_security_group" "gitlab_sg" {
  name        = "gitlab-sg"
  description = "Allow SSH, HTTP, and HTTPS"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "gitlab" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.medium" # adjust as needed
  key_name               = aws_key_pair.gitlab_key.key_name
  vpc_security_group_ids = [aws_security_group.gitlab_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y curl openssh-server ca-certificates tzdata perl
              curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | bash
              EXTERNAL_URL="http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" apt-get install -y gitlab-ee
              EOF

  tags = {
    Name = "GitLab-EE"
  }
}
