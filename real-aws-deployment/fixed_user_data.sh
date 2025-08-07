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

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting real application deployment at $(date)"

# Update system
yum update -y

# Install required packages
yum install -y git docker python3 python3-pip python3-devel gcc gcc-c++ make

# Install Python 3.9 from source (required for TensorFlow compatibility)
cd /tmp
wget https://www.python.org/ftp/python/3.9.12/Python-3.9.12.tgz
tar xzf Python-3.9.12.tgz
cd Python-3.9.12
./configure --enable-optimizations
make altinstall
ln -sf /usr/local/bin/python3.9 /usr/local/bin/python3.9

# Start Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Clone the real repository
cd /home/ec2-user
git clone https://github.com/lucasbraga461/realtime-ml-fraud-detection.git
chown -R ec2-user:ec2-user realtime-ml-fraud-detection

# Navigate to the specific real application directory
cd realtime-ml-fraud-detection/apps/deep_learning/${app_name}

# Create virtual environment with Python 3.9
/usr/local/bin/python3.9 -m venv venv
chown -R ec2-user:ec2-user venv

# Install dependencies as ec2-user
sudo -u ec2-user bash << 'EOF'
cd /home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install TensorFlow CPU version (more stable for EC2)
pip install tensorflow-cpu==2.19.0

# Install other dependencies
pip install Flask==2.2.5
pip install flask_httpauth==4.8.0
pip install keras==3.9.2
pip install numpy==1.26.0
pip install gunicorn==20.1.0

# Create logs directory
mkdir -p logs

# Test if TensorFlow works
python -c "import tensorflow as tf; print('TensorFlow version:', tf.__version__); print('TensorFlow working:', tf.reduce_sum(tf.random.normal([1000, 1000])))"

EOF

# Create systemd service for the real application
cat > /etc/systemd/system/${app_name}.service << EOL
[Unit]
Description=${app_name} Real Flask ML Application with TensorFlow
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}
Environment=PATH=/home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}/venv/bin
Environment=PYTHONPATH=/home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}
ExecStart=/home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}/venv/bin/python app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

# Start the real application service
systemctl daemon-reload
systemctl enable ${app_name}
systemctl start ${app_name}

# Wait for service to start
sleep 30

# Check service status
systemctl status ${app_name}

# Test if application is responding
curl -f http://localhost:8502 || echo "Application not responding yet"

# Log completion
echo "Real application deployment completed at $(date)"
echo "Application: ${app_name}"
echo "TensorFlow installed and tested"
echo "Service status: $(systemctl is-active ${app_name})"

