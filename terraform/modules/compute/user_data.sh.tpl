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

# Install the CloudWatch agent (for sending logs to CloudWatch)
yum install -y amazon-cloudwatch-agent

# Write the CloudWatch agent config
# It will collect the Docker container logs from /var/log/app/
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/*.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%dT%H:%M:%SZ"
          }
        ]
      }
    }
  }
}
EOF

# Start the CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Create the log directory for the app
mkdir -p /var/log/app

# Pull and run the backend Docker container
docker pull ${docker_image}

docker run -d \
  --name backend \
  --restart always \
  -p 8080:8080 \
  -e MONGO_URI="${mongo_uri}" \
  -e ALLOWED_ORIGINS="${allowed_origins}" \
  -e REDIS_ADDR="${redis_endpoint}:6379" \
  -e PORT=8080 \
  -v /var/log/app:/var/log/app \
  ${docker_image}
