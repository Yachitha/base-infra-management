# Configure AWS Provider
provider "aws" {
  region = "us-east-1"  # Using us-east-1 as it often has the lowest prices
}

# VPC Configuration
resource "aws_vpc" "keycloak_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "keycloak-vpc"
  }
}

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.keycloak_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "keycloak-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.keycloak_vpc.id

  tags = {
    Name = "keycloak-igw"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.keycloak_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "keycloak-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for Keycloak
resource "aws_security_group" "keycloak_sg" {
  name        = "keycloak-security-group"
  description = "Security group for Keycloak server"
  vpc_id      = aws_vpc.keycloak_vpc.id

  # Allow inbound HTTP traffic
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound HTTPS traffic
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH traffic (for administration)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "keycloak-sg"
  }
}

# EC2 Instance for Keycloak
resource "aws_instance" "keycloak_server" {
  ami           = "ami-0aa7d40eeae50c9a9"  # Amazon Linux 2 AMI ID (update as needed)
  instance_type = "t2.micro"  # Free tier eligible
  subnet_id     = aws_subnet.public_subnet.id
  
  vpc_security_group_ids = [aws_security_group.keycloak_sg.id]
  
  root_block_device {
    volume_size = 8  # Minimum size in GB
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              
              # Pull and run Keycloak container
              docker run -d \
                --name keycloak \
                -p 8080:8080 \
                -e KEYCLOAK_ADMIN= \
                -e KEYCLOAK_ADMIN_PASSWORD= \
                quay.io/keycloak/keycloak:latest \
                start-dev
              EOF

  tags = {
    Name = "keycloak-server"
  }
}

# Output the public IP of the EC2 instance
output "keycloak_public_ip" {
  value = aws_instance.keycloak_server.public_ip
}