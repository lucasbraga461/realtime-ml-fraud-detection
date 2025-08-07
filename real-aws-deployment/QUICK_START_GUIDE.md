# Quick Start Guide

## Get Started in 5 Minutes

This guide will help you deploy your first machine learning fraud detection application on AWS in just a few minutes.

## Prerequisites Check

Before starting, ensure you have:
- [ ] AWS account with admin permissions
- [ ] AWS CLI installed and configured
- [ ] Terraform installed (version 1.0+)
- [ ] Docker installed and running
- [ ] Local Linux/macOS environment with bash

## Step-by-Step Deployment

### Step 1: Download and Setup (2 minutes)

1. **Extract the deployment package:**
   ```bash
   unzip aws-fraud-detection-deployment.zip
   cd aws-fraud-detection-deployment
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x *.sh
   ```

3. **Verify your AWS credentials:**
   ```bash
   aws sts get-caller-identity
   ```

### Step 2: Deploy Your First Application (3 minutes)
Inside the dynamic_deployment_system.sh setup your docker credentials(token)
   export DOCKERHUB_USERNAME=""
   export DOCKERHUB_TOKEN=""

1. **Start the deployment system:**
   ```bash
   ./dynamic_deployment_system.sh
   ```

2. **Follow the interactive prompts:**
   - **Infrastructure Selection**: Choose `1` for EC2 (fastest deployment)
   - **Application Selection**: Choose `3` for LSTM application (proven to work)
   - **Confirmation**: Type `y` to proceed

3. **Wait for deployment:**
   - The system will create AWS resources automatically
   - Deployment typically takes 5-8 minutes
   - You'll see real-time progress updates

### Step 3: Access Your Application

1. **Get the application URL:**
   - The system will display the URL when deployment completes
   - Example: `http://12.34.56.78:8502`

2. **Test the application:**
   ```bash
   curl http://YOUR_APPLICATION_URL
   ```

3. **Open in browser:**
   - Navigate to the provided URL
   - You should see the fraud detection application interface

## What You Just Deployed

### Infrastructure Created
- **VPC**: Isolated network environment
- **EC2 Instance**: t3.xlarge instance running your application
- **Security Group**: Firewall rules allowing access on port 8502
- **Elastic IP**: Static IP address for consistent access
- **Key Pair**: SSH access for debugging

### Application Features
- **Web Interface**: User-friendly fraud detection interface
- **REST API**: Programmatic access for integration
- **Machine Learning Model**: Pre-trained LSTM model for fraud detection
- **Authentication**: Basic authentication system
- **Monitoring**: Built-in health checks and logging

## Quick Commands Reference

### Check Application Status
```bash
# Test if application is responding
curl -I http://YOUR_APPLICATION_URL

# Check application health
curl http://YOUR_APPLICATION_URL/health
```

### SSH into EC2 Instance
```bash
# Navigate to deployment directory
cd deployment_ec2_flask-lstm-app-py39

# SSH using generated key
ssh -i flask-lstm-app-py39-key.pem ec2-user@YOUR_IP_ADDRESS
```

### View Application Logs
```bash
# SSH into instance first, then:
sudo docker logs flask-lstm-app-py39-container
```

### Clean Up Resources
```bash
# Navigate to deployment directory
cd deployment_ec2_flask-lstm-app-py39

# Destroy all resources
terraform destroy -auto-approve
```

## Next Steps

### Try Different Deployments
1. **ECS Deployment**: More scalable, serverless option
   ```bash
   ./dynamic_deployment_system.sh
   # Choose option 2 for ECS
   ```

2. **ECS with Load Balancer**: Production-ready with high availability
   ```bash
   ./dynamic_deployment_system.sh
   # Choose option 3 for ECS + ALB
   ```

### Explore Different Applications
Try deploying other machine learning models:
- **CNN Application**: Choose option 1 (Convolutional Neural Network)
- **XGBoost Application**: Choose option 12 (Gradient Boosting)
- **LightGBM Application**: Choose option 9 (Light Gradient Boosting)

### API Integration Example
```python
import requests
import json

# Application URL from deployment
url = "http://YOUR_APPLICATION_URL"

# Sample fraud detection request
data = {
    "Feature_1": 1.0,
    "Feature_2": 0.5,
    "Feature_3": -0.2,
    "Feature_4": 1.8
}

# Make prediction request
response = requests.post(f"{url}/predict", json=data)
result = response.json()

print(f"Fraud Probability: {result['score']}")
print(f"Model Used: {result['model_name']}")
```

## Troubleshooting Quick Fixes

### Application Not Accessible
```bash
# Check security group allows port 8502
aws ec2 describe-security-groups --group-ids YOUR_SG_ID

# Verify application is running
ssh -i YOUR_KEY.pem ec2-user@YOUR_IP "sudo docker ps"
```

### Deployment Fails
```bash
# Check AWS service limits
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A

# Verify Terraform state
terraform show
```

### High Costs
```bash
# Check running instances
aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`]'

# Stop instance when not needed
aws ec2 stop-instances --instance-ids YOUR_INSTANCE_ID
```

## Cost Estimation

### Daily Costs (US East 1)
- **EC2 t3.xlarge**: ~$3.50/day
- **Elastic IP**: ~$0.36/day (when not attached)
- **EBS Storage**: ~$0.30/day
- **Data Transfer**: Variable based on usage

### Monthly Estimate
- **Development Usage**: $50-80/month
- **Production Usage**: $100-200/month
- **High Availability Setup**: $200-400/month

## Security Notes

### Default Security
- SSH access restricted to your IP
- Application port (8502) open to internet
- All other ports blocked by default
- Instance uses latest Amazon Linux 2

### Recommended Enhancements
1. **Restrict Application Access**: Limit port 8502 to specific IPs
2. **Enable SSL**: Add SSL certificate for HTTPS
3. **Update Regularly**: Keep system and dependencies updated
4. **Monitor Access**: Enable CloudTrail for audit logging

## Support Resources

### Documentation
- **Full README**: Complete system documentation
- **Architecture Guide**: Detailed infrastructure explanations
- **API Documentation**: Application-specific API details

### Useful Commands
```bash
# View all available applications
./dynamic_deployment_system.sh | grep "Found application"

# Check Terraform version
terraform version

# Verify Docker installation
docker --version

# Test AWS connectivity
aws ec2 describe-regions
```

### Getting Help
1. Check the main README.md for detailed documentation
2. Review Terraform logs for infrastructure issues
3. Examine application logs for runtime problems
4. Verify AWS service status for regional issues

This quick start guide gets you up and running with a working fraud detection application on AWS. For production deployments, review the complete documentation for security, monitoring, and scaling considerations.

