#!/bin/bash

# Update system
set -xe  # debug: print commands as they run

apt-get update -y

apt-get install -y wget unzip openjdk-17-jdk awscli postgresql-client

# Get database credentials from SSM Parameter Store
DB_ENDPOINT=$(aws ssm get-parameter --name "/dev/sonarqube/db_endpoint" --region us-east-1 --query 'Parameter.Value' --output text)
DB_USERNAME=$(aws ssm get-parameter --name "/dev/sonarqube/db_username" --with-decryption --region us-east-1 --query 'Parameter.Value' --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/dev/sonarqube/db_password" --with-decryption --region us-east-1 --query 'Parameter.Value' --output text)
DB_NAME=$(aws ssm get-parameter --name "/dev/sonarqube/db_name" --region us-east-1 --query 'Parameter.Value' --output text)

# Create sonarqube user
if ! id -u sonarqube >/dev/null 2>&1; then
    useradd -m sonarqube
fi

# Download and install SonarQube
cd /opt

# Download SonarQube if not already present
if [ ! -f "sonarqube-25.5.0.107428.zip" ]; then
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.5.0.107428.zip
fi

# Extract SonarQube
if [ -f "sonarqube-25.5.0.107428.zip" ]; then
    unzip -q sonarqube-25.5.0.107428.zip
    mv sonarqube-10.7.0.96327 sonarqube
    rm sonarqube-25.5.0.107428.zip
fi

# Set proper permissions and ownership
chmod +x /opt/sonarqube/bin/linux-x86-64/sonar.sh
chown -R sonarqube:sonarqube /opt/sonarqube

echo "Waiting for DB to become available..."
for i in {1..30}; do
  nc -zv $DB_ENDPOINT 5432 && break
  echo "Waiting for DB... retry $i/30"
  sleep 10
done

# Configure SonarQube
cat > /opt/sonarqube/conf/sonar.properties << EOF
# Database configuration
sonar.jdbc.username=${DB_USERNAME}
sonar.jdbc.password=${DB_PASSWORD}
sonar.jdbc.url=jdbc:postgresql://${DB_ENDPOINT}/${DB_NAME}

# Web server configuration
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Elasticsearch configuration
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError

# General configuration
sonar.path.data=/opt/sonarqube/data
sonar.path.temp=/opt/sonarqube/temp
EOF

# Set system limits for Elasticsearch
cat >> /etc/security/limits.conf << EOF
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
EOF

# Set kernel parameters
cat >> /etc/sysctl.conf << EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

# Apply kernel parameters
sysctl -p

# Create systemd service
cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOF

# Enable and start SonarQube service
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

# Wait for SonarQube to start
sleep 60

# Check if SonarQube is running
systemctl status sonarqube