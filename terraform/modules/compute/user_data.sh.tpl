#!/bin/bash
# -------------------------------------------------
# EC2 User Data Script
# This script runs once when a new EC2 instance
# starts. It installs Docker and runs the backend.
# -------------------------------------------------

set -e  # Exit immediately on any error

# Update OS packages
yum update -y

# Install Docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Pull and run the backend Docker container
docker pull ${docker_image}
INSTANCE_ID=$(curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/instance-id || hostname)

docker run -d \
  --name backend \
  --restart always \
  --log-driver=awslogs \
  --log-opt awslogs-region="${aws_region}" \
  --log-opt awslogs-group="${cloudwatch_log_group}" \
  --log-opt awslogs-create-group=false \
  --log-opt awslogs-stream="backend-logs" \
  -p 8080:8080 \
  -e MONGO_URI="${mongo_uri}" \
  -e ALLOWED_ORIGINS="${allowed_origins}" \
  -e ENABLE_CACHE="true" \
  -e REDIS_ADDR="${redis_endpoint}:6379" \
  -e LOG_FORMAT="json" \
  -e PORT=8080 \
  ${docker_image}
