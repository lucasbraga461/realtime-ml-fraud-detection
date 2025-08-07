#!/bin/bash

# Update system
yum update -y

# Install required packages
yum install -y git docker python3 python3-pip

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

# Install Python dependencies using the real requirements.txt
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create logs directory if needed
mkdir -p logs

# Create systemd service for the real application
cat > /etc/systemd/system/${app_name}.service << EOL
[Unit]
Description=${app_name} Real Flask ML Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}
Environment=PATH=/home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}/venv/bin
ExecStart=/home/ec2-user/realtime-ml-fraud-detection/apps/deep_learning/${app_name}/venv/bin/python app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Start the real application service
systemctl daemon-reload
systemctl enable ${app_name}
systemctl start ${app_name}

# Log completion
echo "Real application deployment completed at $(date)" >> /var/log/user-data.log
echo "Application: ${app_name}" >> /var/log/user-data.log
