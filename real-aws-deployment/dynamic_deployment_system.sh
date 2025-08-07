#!/bin/bash

# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================
export DOCKERHUB_USERNAME=""
export DOCKERHUB_TOKEN=""


if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
    echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
fi


set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to scan applications
scan_applications() {
    print_header "SCANNING REAL APPLICATIONS FROM REPOSITORY"
    
    if [ ! -d "realtime-ml-fraud-detection" ]; then
        print_status "Cloning repository..."
        git clone https://github.com/lucasbraga461/realtime-ml-fraud-detection.git
    fi
    
    cd realtime-ml-fraud-detection/apps
    
    # Find all applications (directories with app.py)
    applications=()
    app_paths=()
    app_configs=()
    
    print_status "Discovering applications..."
    
    while IFS= read -r -d '' app_file; do
        app_dir=$(dirname "$app_file")
        app_name=$(basename "$app_dir")
        
        # Get relative path from apps directory
        #rel_path=$(realpath --relative-to="$(pwd)" "$app_dir")
        rel_path=$(python3 -c "import os.path; print(os.path.relpath('$app_dir', '$(pwd)'))")
        # Check for configuration files
        dockerfile=""
        requirements=""
        python_version="3.9"
        
        if [ -f "$app_dir/Dockerfile" ]; then
            dockerfile="$app_dir/Dockerfile"
        fi
        
        if [ -f "$app_dir/requirements.txt" ]; then
            requirements="$app_dir/requirements.txt"
        fi
        
        # Try to detect Python version from Dockerfile
        if [ -f "$dockerfile" ]; then
            py_ver=$(grep -o "python[0-9]\.[0-9]" "$dockerfile" | head -1 | sed 's/python//')
            if [ ! -z "$py_ver" ]; then
                python_version="$py_ver"
            fi
        fi
        
        applications+=("$app_name")
        app_paths+=("$rel_path")

        #echo $app_paths "#########################################################"

        app_configs+=("$python_version|$dockerfile|$requirements")
        
        print_status "Found application: $app_name (Python $python_version)"
        
    done < <(find . -name "app.py" -type f -print0)
    
    cd ../..
    
    if [ ${#applications[@]} -eq 0 ]; then
        print_error "No applications found in repository!"
        exit 1
    fi
    
    print_status "Total applications found: ${#applications[@]}"
}

# Function to show deployment menu
show_deployment_menu() {
    print_header "DEPLOYMENT INFRASTRUCTURE SELECTION"
    echo "Please select the deployment infrastructure:"
    echo "1) EC2 (Single Instance)"
    echo "2) ECS (Fargate - Single Environment)"
    echo "3) ECS + Load Balancer (High Availability)"
    echo ""
    read -p "Enter your choice (1-3): " infra_choice
    
    case $infra_choice in
        1) deployment_type="ec2" ;;
        2) deployment_type="ecs" ;;
        3) deployment_type="ecs_alb" ;;
        *) print_error "Invalid choice!"; exit 1 ;;
    esac
    
    print_status "Selected infrastructure: $deployment_type"
}

# Function to show application menu
show_application_menu() {
    print_header "APPLICATION SELECTION"
    echo "Please select the application to deploy:"
    
    for i in "${!applications[@]}"; do
        config=(${app_configs[$i]//|/ })
        python_ver=${config[0]}
        echo "$((i+1))) ${applications[$i]} (Python $python_ver)"
    done
    
    echo ""
    read -p "Enter your choice (1-${#applications[@]}): " app_choice
    
    if [ $app_choice -lt 1 ] || [ $app_choice -gt ${#applications[@]} ]; then
        print_error "Invalid choice!"
        exit 1
    fi
    
    selected_app_index=$((app_choice-1))
    selected_app=${applications[$selected_app_index]}
    selected_path=${app_paths[$selected_app_index]}
    
    config=(${app_configs[$selected_app_index]//|/ })
    selected_python=${config[0]}
    selected_dockerfile=${config[1]}
    selected_requirements=${config[2]}
    
    print_status "Selected application: $selected_app"
    print_status "Application path: $selected_path"
    print_status "Python version: $selected_python"
}

# Function to generate Terraform configuration
generate_terraform_config() {
    print_header "GENERATING TERRAFORM CONFIGURATION"
    
    # Create deployment directory
    deployment_dir="deployment_${deployment_type}_${selected_app}"
    mkdir -p "$deployment_dir"
    cd "$deployment_dir"
    
    # Generate main.tf based on deployment type
    case $deployment_type in
        "ec2")
            generate_ec2_config
            ;;
        "ecs")
            generate_ecs_config
            ;;
        "ecs_alb")
            generate_ecs_alb_config
            ;;
    esac
    
    print_status "Terraform configuration generated in: $deployment_dir"
}

# Function to generate EC2 configuration
generate_ec2_config() {
    cat > main.tf << EOF
# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${selected_app}-vpc"
    App  = "$selected_app"
    Type = "Real-Application"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${selected_app}-igw"
    App  = "$selected_app"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${selected_app}-public-subnet"
    App  = "$selected_app"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${selected_app}-public-rt"
    App  = "$selected_app"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web" {
  name_prefix = "${selected_app}-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8502
    to_port     = 8502
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${selected_app}-sg"
    App  = "$selected_app"
  }
}

# Key Pair
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${selected_app}-key"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "${selected_app}-key"
    App  = "$selected_app"
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${selected_app}-key.pem"
  file_permission = "0400"
}

# AMI Data
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.xlarge"
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = aws_subnet.public.id

  user_data = base64encode(templatefile("user_data.sh", {
    app_name     = "$selected_app"
    app_path     = "$selected_path"
    python_version = "$selected_python"
  }))

  tags = {
    Name = "${selected_app}-instance"
    App  = "$selected_app"
    Type = "Real-Application"
  }
}

# Elastic IP
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name = "${selected_app}-eip"
    App  = "$selected_app"
  }
}

# Outputs
output "app_url" {
  value = "http://\${aws_eip.web.public_ip}:8502"
}

output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_eip.web.public_ip
}

output "ssh_command" {
  value = "ssh -i ${selected_app}-key.pem ec2-user@\${aws_eip.web.public_ip}"
}
EOF

    # Generate user_data script
    cat > user_data.sh << 'EOF'
#!/bin/bash

# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting deployment of ${app_name} at $(date)"

# Update system
yum update -y

# Install Docker
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Clone repository
cd /home/ec2-user
git clone https://github.com/lucasbraga461/realtime-ml-fraud-detection.git
chown -R ec2-user:ec2-user realtime-ml-fraud-detection

# Navigate to application directory
cd realtime-ml-fraud-detection/apps/${app_path}

# Build and run Docker container
sudo docker build -t ${app_name} .
sudo docker run -d -p 8502:8502 --name ${app_name}-container ${app_name}

# Wait for container to start
sleep 30

# Test application
curl -f http://localhost:8502 || echo "Application not responding yet"

echo "Deployment completed at $(date)"
EOF
}

# Function to generate ECS configuration
generate_ecs_config() {
    cat > main.tf << EOF
# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_region" "current" {}

# VPC Configuration (same as EC2)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${selected_app}-vpc"
    App  = "$selected_app"
    Type = "Real-Application"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${selected_app}-igw"
    App  = "$selected_app"
  }
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${selected_app}-public-subnet-1"
    App  = "$selected_app"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${selected_app}-public-subnet-2"
    App  = "$selected_app"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${selected_app}-public-rt"
    App  = "$selected_app"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "ecs" {
  name_prefix = "${selected_app}-ecs-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 8502
    to_port     = 8502
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${selected_app}-ecs-sg"
    App  = "$selected_app"
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name = "${selected_app}"

  tags = {
    Name = "${selected_app}-ecr"
    App  = "$selected_app"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${selected_app}-cluster"

  tags = {
    Name = "${selected_app}-cluster"
    App  = "$selected_app"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${selected_app}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name  = "${selected_app}"
      image = "\${aws_ecr_repository.app.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8502
          hostPort      = 8502
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${selected_app}"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${selected_app}-task"
    App  = "$selected_app"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${selected_app}"
  retention_in_days = 7

  tags = {
    Name = "${selected_app}-logs"
    App  = "$selected_app"
  }
}

# IAM Role for ECS Execution
resource "aws_iam_role" "ecs_execution" {
  name = "${selected_app}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${selected_app}-ecs-execution-role"
    App  = "$selected_app"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${selected_app}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  tags = {
    Name = "${selected_app}-service"
    App  = "$selected_app"
  }
}

# Outputs
output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "current_region" {
  value = data.aws_region.current.name
}

EOF

# Generate deployment script
cat > deploy.sh << EOF
#!/bin/bash
echo "############################" Generate deployment script ############################"
# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

set -e

# Get ECR repository URL
ECR_URL="\$(terraform output -raw ecr_repository_url)"

CURRENT_REGION="\$(terraform output -raw current_region)"


echo "Building and pushing Docker image..."

echo  "BUILDING AND PUSHING DOCKER IMAGE"

# Login to ECR
echo "Logging into AWS ECR..."
echo "\$(aws ecr get-login-password --region us-east-1)" | docker login --username AWS --password-stdin "\$ECR_URL"

# Clone repository if it doesn't exist
if [ ! -d "realtime-ml-fraud-detection" ]; then
    echo "Cloning application repository..."
    git clone https://github.com/lucasbraga461/realtime-ml-fraud-detection.git
fi

# Build Docker image
cd realtime-ml-fraud-detection/apps/$selected_path

docker build -t $applications .
docker tag $applications:latest "\$ECR_URL":latest

# Push to ECR
docker push "\$ECR_URL":latest
docker buildx build --platform linux/amd64,linux/arm64 -t "\$ECR_URL":latest --push .

echo  "Image pushed successfully!"

# Update ECS service
aws ecs update-service --cluster ${selected_app}-cluster --service ${selected_app}-service --force-new-deployment --region "\$CURRENT_REGION" > /dev/null

echo "ECS service updated!"

EOF

    chmod +x deploy.sh
}

# Function to generate ECS with ALB configuration
generate_ecs_alb_config() {
    cat > main.tf << EOF
# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_region" "current" {}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${selected_app}-vpc"
    App  = "$selected_app"
    Type = "Real-Application"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${selected_app}-igw"
    App  = "$selected_app"
  }
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${selected_app}-public-subnet-1"
    App  = "$selected_app"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${selected_app}-public-subnet-2"
    App  = "$selected_app"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${selected_app}-public-rt"
    App  = "$selected_app"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "alb" {
  name_prefix = "${selected_app}-alb-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${selected_app}-alb-sg"
    App  = "$selected_app"
  }
}

resource "aws_security_group" "ecs" {
  name_prefix = "${selected_app}-ecs-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8502
    to_port         = 8502
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${selected_app}-ecs-sg"
    App  = "$selected_app"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${selected_app}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "${selected_app}-alb"
    App  = "$selected_app"
  }
}

# Target Group
resource "aws_lb_target_group" "app" {
  name        = "${selected_app}-tg"
  port        = 8502
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name = "${selected_app}-tg"
    App  = "$selected_app"
  }
}

# ALB Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${selected_app}-listener"
    App  = "$selected_app"
  }
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name = "${selected_app}"

  tags = {
    Name = "${selected_app}-ecr"
    App  = "$selected_app"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${selected_app}-cluster"

  tags = {
    Name = "${selected_app}-cluster"
    App  = "$selected_app"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${selected_app}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name  = "${selected_app}"
      image = "\${aws_ecr_repository.app.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8502
          hostPort      = 8502
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${selected_app}"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${selected_app}-task"
    App  = "$selected_app"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${selected_app}"
  retention_in_days = 7

  tags = {
    Name = "${selected_app}-logs"
    App  = "$selected_app"
  }
}

# IAM Role for ECS Execution
resource "aws_iam_role" "ecs_execution" {
  name = "${selected_app}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${selected_app}-ecs-execution-role"
    App  = "$selected_app"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Service with ALB
resource "aws_ecs_service" "app" {
  name            = "${selected_app}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${selected_app}"
    container_port   = 8502
  }

  depends_on = [aws_lb_listener.app]

  tags = {
    Name = "${selected_app}-service"
    App  = "$selected_app"
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/\${aws_ecs_cluster.main.name}/\${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy
resource "aws_appautoscaling_policy" "ecs_policy" {
  name               = "${selected_app}-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Outputs
output "load_balancer_url" {
  value = "http://\${aws_lb.main.dns_name}"
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "current_region" {
  value = data.aws_region.current.name
}

EOF

    # Generate deployment script (same as ECS)
 cat > deploy.sh << EOF
#!/bin/bash
echo "############################" Generate deployment script ############################"
# =============================================================================
# Credit Card Fraud Detection  V5 - Centralized Configuration Module
# Author: Rodrigo Marins Piaba (Fanaticos4tech)
# E-mail: rodrigomarinsp@gmail.com
# Project: https://github.com/rodrigomarinsp/fsah-neural
# =============================================================================
# Centralized Configuration Module 
# Central point of the system
# =============================================================================

set -e

# Get ECR repository URL
ECR_URL="\$(terraform output -raw ecr_repository_url)"

CURRENT_REGION="\$(terraform output -raw current_region)"


echo "Building and pushing Docker image..."

echo  "BUILDING AND PUSHING DOCKER IMAGE"

# Login to ECR
echo "Logging into AWS ECR..."
echo "\$(aws ecr get-login-password --region us-east-1)" | docker login --username AWS --password-stdin "\$ECR_URL"

# Clone repository if it doesn't exist
if [ ! -d "realtime-ml-fraud-detection" ]; then
    echo "Cloning application repository..."
    git clone https://github.com/lucasbraga461/realtime-ml-fraud-detection.git
fi

# Build Docker image
cd realtime-ml-fraud-detection/apps/$selected_path

docker build -t $applications .
docker tag $applications:latest "\$ECR_URL":latest

# Push to ECR
docker push "\$ECR_URL":latest
docker buildx build --platform linux/amd64,linux/arm64 -t "\$ECR_URL":latest --push .

echo  "Image pushed successfully!"

# Update ECS service
aws ecs update-service --cluster ${selected_app}-cluster --service ${selected_app}-service --force-new-deployment --region "\$CURRENT_REGION" > /dev/null

echo "ECS service updated!"

EOF

    chmod +x deploy.sh
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_header "DEPLOYING INFRASTRUCTURE"
    
    print_status "Initializing Terraform..."
    terraform init
    
    print_status "Planning deployment..."
    terraform plan
    
    echo ""
    read -p "Do you want to proceed with deployment? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_status "Applying Terraform configuration..."
        terraform apply -auto-approve
        
        if [ $deployment_type != "ec2" ]; then
            print_status "Running deployment script..."
            ./deploy.sh
        fi
        
        print_status "Deployment completed successfully!"
        
        # Show outputs
        print_header "DEPLOYMENT RESULTS"
        terraform output
        
    else
        print_warning "Deployment cancelled."
    fi
}

# Main execution
main() {
    print_header "DYNAMIC AWS DEPLOYMENT SYSTEM"
    print_status "Real Application Deployment from Repository"
    
    # Scan applications
    scan_applications
    
    # Show menus
    show_deployment_menu
    show_application_menu
    
    # Generate configuration
    generate_terraform_config
    
    # Deploy
    deploy_infrastructure
    
    print_status "Process completed!"
}

# Run main function
main "$@"

