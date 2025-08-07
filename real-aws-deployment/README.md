# Dynamic AWS Deployment System for ML Fraud Detection Applications

## Overview

This project provides a comprehensive, dynamic deployment system for machine learning fraud detection applications on AWS infrastructure. The system automatically discovers applications from a repository and enables deployment across three different AWS architectures: EC2, ECS, and ECS with Application Load Balancer.

## Key Features

### Dynamic Application Discovery
The system automatically scans the repository structure and identifies all available machine learning applications. Each application is analyzed for its specific requirements including Python version, dependencies, and configuration files.

### Multiple Deployment Options
Choose from three proven AWS deployment architectures:
- **EC2 Single Instance**: Cost-effective solution for development and testing
- **ECS Fargate**: Serverless container deployment with automatic scaling
- **ECS with Application Load Balancer**: High availability setup with load balancing and auto-scaling

### Automated Infrastructure Management
Complete infrastructure provisioning using Terraform with automatic resource cleanup and cost optimization features.

## Supported Applications

The system currently supports 12 different machine learning applications:

### Deep Learning Applications
1. **flask-cnn-app-py39** - Convolutional Neural Network implementation
2. **flask-cnn-app** - Alternative CNN implementation
3. **flask-lstm-app-py39** - Long Short-Term Memory network
4. **flask-lstm-app** - Alternative LSTM implementation
5. **flask-transformers-app-py39** - Transformer-based models
6. **flask-transformers-app** - Alternative transformer implementation

### Machine Learning Applications
7. **flask-stacking-app** - Ensemble stacking methods
8. **flask-stacking-dl-app** - Deep learning stacking
9. **flask-lgbm-app** - LightGBM implementation
10. **flask-lgbm-app_py39** - Python 3.9 LightGBM version
11. **flask-logreg-app** - Logistic regression models
12. **flask-xgboost-app** - XGBoost implementation

## Prerequisites

### AWS Account Setup
- Active AWS account with appropriate permissions
- AWS CLI installed and configured
- Terraform installed (version 1.0 or higher)
- Docker installed for container operations

### Required AWS Permissions
The deployment requires the following AWS services:
- EC2 (instances, security groups, key pairs)
- ECS (clusters, services, task definitions)
- ECR (container registry)
- ELB (application load balancers)
- VPC (networking components)
- IAM (roles and policies)

### System Requirements
- Linux or macOS environment
- Bash shell (version 4.0 or higher)
- Internet connectivity for downloading dependencies
- Minimum 4GB RAM for local operations
- 10GB free disk space for container images

## Installation Guide

### Step 1: Download and Extract
Download the deployment package and extract it to your preferred directory:

```bash
unzip aws-fraud-detection-deployment.zip
cd aws-fraud-detection-deployment
```

### Step 2: Configure AWS Credentials
Set up your AWS credentials using one of these methods:

**Option A: AWS CLI Configuration**
```bash
aws configure
```

**Option B: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

**Option C: Use Provided Credentials Template**
```bash
cp templates/credentials ~/.aws/credentials
cp templates/config ~/.aws/config
# Edit the files with your actual credentials
```

### Step 3: Verify Prerequisites
Run the verification script to ensure all requirements are met:

```bash
./verify_prerequisites.sh
```

### Step 4: Initialize the System
Make the deployment script executable and run initial setup:

```bash
chmod +x dynamic_deployment_system.sh
./dynamic_deployment_system.sh
```

## Usage Instructions

### Basic Deployment Process

1. **Start the Deployment System**
   ```bash
   ./dynamic_deployment_system.sh
   ```

2. **Select Infrastructure Type**
   The system will present three options:
   - `1` for EC2 (Single Instance)
   - `2` for ECS (Fargate - Single Environment)
   - `3` for ECS + Load Balancer (High Availability)

3. **Choose Application**
   Select from the list of 12 available applications. Each application shows its Python version and type.

4. **Confirm Deployment**
   Review the configuration and confirm to proceed with deployment.

5. **Monitor Progress**
   The system will display real-time progress updates during infrastructure creation and application deployment.

6. **Access Your Application**
   Once deployment completes, the system provides the URL to access your application.

### Advanced Usage

#### Automated Deployment
For scripted deployments, you can provide inputs programmatically:

```bash
echo -e "3\n1\ny" | ./dynamic_deployment_system.sh
```

This example deploys the first application (flask-cnn-app-py39) on ECS with Load Balancer.

#### Custom Configuration
Modify the application configurations by editing the generated Terraform files before applying:

```bash
# After running the deployment script but before confirming
cd deployment_ecs_alb_flask-cnn-app-py39
nano main.tf
terraform plan
terraform apply
```

#### Resource Cleanup
To remove deployed resources and avoid ongoing costs:

```bash
cd deployment_directory
terraform destroy
```

## Architecture Details

### EC2 Deployment Architecture
- Single EC2 instance (t3.xlarge for ML workloads)
- Elastic IP for consistent access
- Security groups with port 8502 access
- Automated Docker container deployment
- SSH access for debugging and maintenance

### ECS Deployment Architecture
- ECS Fargate cluster for serverless operation
- ECR repository for container images
- CloudWatch logging for monitoring
- Public subnet deployment with internet access
- Automatic container health checks

### ECS with Load Balancer Architecture
- Application Load Balancer for high availability
- Multiple availability zones for redundancy
- Auto-scaling based on CPU utilization (2-10 instances)
- Target group health checks
- SSL termination capability (configurable)

## Cost Optimization

### Estimated Costs (US East 1)
- **EC2 Deployment**: $2.50-4.00 per day
- **ECS Deployment**: $1.50-3.00 per day
- **ECS + ALB Deployment**: $3.00-6.00 per day

### Cost Reduction Strategies
1. Use smaller instance types for development
2. Implement scheduled start/stop for non-production environments
3. Enable auto-scaling to match actual demand
4. Regular cleanup of unused resources
5. Monitor costs using AWS Cost Explorer

## Security Considerations

### Network Security
- Security groups restrict access to necessary ports only
- Private subnets for sensitive components (when applicable)
- VPC isolation from other AWS resources
- Regular security group auditing

### Application Security
- Container image scanning before deployment
- Secrets management through AWS Systems Manager
- IAM roles with minimal required permissions
- Regular dependency updates for security patches

### Access Control
- SSH key-based access for EC2 instances
- IAM roles for service-to-service communication
- Application-level authentication where implemented
- Audit logging for all administrative actions

## Troubleshooting

### Common Issues and Solutions

#### Deployment Failures
**Issue**: Terraform apply fails with resource limits
**Solution**: Check AWS service limits and request increases if needed

**Issue**: Docker build fails during ECS deployment
**Solution**: Verify Docker daemon is running and has sufficient disk space

**Issue**: Application not accessible after deployment
**Solution**: Check security group rules and ensure port 8502 is open

#### Performance Issues
**Issue**: Application responds slowly
**Solution**: Consider upgrading instance type or increasing container resources

**Issue**: High memory usage
**Solution**: Optimize application code or increase memory allocation

#### Network Issues
**Issue**: Cannot access application URL
**Solution**: Verify DNS resolution and security group configuration

**Issue**: Load balancer health checks failing
**Solution**: Ensure application responds on the health check endpoint

### Debug Mode
Enable verbose logging for troubleshooting:

```bash
export TF_LOG=DEBUG
./dynamic_deployment_system.sh
```

### Log Locations
- Terraform logs: `terraform.log`
- Application logs: Check CloudWatch Logs (ECS) or SSH to instance (EC2)
- Deployment logs: `deploy_*.log` files

## Monitoring and Maintenance

### Health Monitoring
- Application health checks every 30 seconds
- CloudWatch metrics for resource utilization
- Automated alerting for failures (configurable)
- Log aggregation for troubleshooting

### Regular Maintenance Tasks
1. Update container images monthly
2. Review and rotate access keys quarterly
3. Update Terraform modules for security patches
4. Monitor costs and optimize resource allocation
5. Backup important configurations

### Scaling Considerations
- Monitor application performance metrics
- Adjust auto-scaling policies based on usage patterns
- Consider multi-region deployment for global applications
- Implement caching strategies for improved performance

## Support and Contributing

### Getting Help
- Review this documentation thoroughly
- Check the troubleshooting section for common issues
- Examine log files for specific error messages
- Verify AWS service status for regional issues

### Best Practices
- Always test deployments in a development environment first
- Use version control for configuration changes
- Implement proper backup and disaster recovery procedures
- Follow AWS Well-Architected Framework principles
- Regular security assessments and updates

### System Requirements for Development
- Understanding of AWS services and Terraform
- Basic knowledge of Docker and containerization
- Familiarity with machine learning application deployment
- Experience with bash scripting and Linux systems

This documentation provides comprehensive guidance for deploying and managing machine learning fraud detection applications on AWS using our dynamic deployment system. The system is designed to be both powerful for production use and accessible for development and testing scenarios.

