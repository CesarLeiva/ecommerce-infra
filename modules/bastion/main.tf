# ===================================
# Data Sources
# ===================================
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ===================================
# Key Pair
# ===================================
resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion" {
  key_name   = "${var.prefix}-${var.env}-bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh

  tags = {
    Name        = "${var.prefix}-${var.env}-bastion-key"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# Security Group
# ===================================
resource "aws_security_group" "bastion" {
  name        = "${var.prefix}-${var.env}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-bastion-sg"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# IAM Role for SSM Session Manager
# ===================================
resource "aws_iam_role" "bastion" {
  name = "${var.prefix}-${var.env}-bastion-role"

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

  tags = {
    Name        = "${var.prefix}-${var.env}-bastion-role"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach AWS managed policy for CloudWatch
resource "aws_iam_role_policy_attachment" "bastion_cloudwatch" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.prefix}-${var.env}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name        = "${var.prefix}-${var.env}-bastion-profile"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# User Data Script
# ===================================
locals {
  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    yum update -y
    
    # Install PostgreSQL client
    amazon-linux-extras install -y postgresql14
    
    # Install Docker for ECS CLI and container management
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ec2-user
    
    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    
    # Install ECS CLI
    curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest
    chmod +x /usr/local/bin/ecs-cli
    
    # Install Session Manager plugin
    yum install -y https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm
    
    # Install common tools
    yum install -y htop nano vim wget curl jq git telnet nc
    
    # Install Redis CLI
    amazon-linux-extras install -y redis6
    
    # Configure CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm
    rm -f ./amazon-cloudwatch-agent.rpm
    
    # Signal completion
    echo "Bastion host setup completed successfully" > /var/log/bastion-setup.log
  EOF
}

# ===================================
# EC2 Instance
# ===================================
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.bastion.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  user_data_base64       = base64encode(local.user_data)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size
    encrypted             = true
    kms_key_id            = var.kms_key_arn
    delete_on_termination = true

    tags = {
      Name        = "${var.prefix}-${var.env}-bastion-volume"
      Environment = var.env
      ManagedBy   = "Terraform"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-bastion"
    Environment = var.env
    Role        = "Bastion"
    ManagedBy   = "Terraform"
  }
}

# ===================================
# Elastic IP (Optional)
# ===================================
resource "aws_eip" "bastion" {
  count    = var.enable_elastic_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.bastion.id

  tags = {
    Name        = "${var.prefix}-${var.env}-bastion-eip"
    Environment = var.env
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_instance.bastion]
}
