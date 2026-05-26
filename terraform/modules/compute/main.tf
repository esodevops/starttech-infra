# -------------------------------------------------
# Compute Module - Main Resources
# Creates: ALB, Target Group, EC2 Launch Template,
#          Auto Scaling Group, and Scaling Policies
# -------------------------------------------------

# ---- Application Load Balancer ----
# The ALB sits in public subnets and distributes
# incoming HTTP traffic to healthy backend instances
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false # publicly accessible
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# ---- ALB Target Group ----
# Defines how the ALB routes traffic and checks instance health
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-backend-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health" # backend must expose GET /health
    interval            = 30        # check every 30 seconds
    timeout             = 5
    healthy_threshold   = 2 # 2 passing checks = healthy
    unhealthy_threshold = 3 # 3 failing checks = unhealthy
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-backend-tg"
    Environment = var.environment
  }
}

# ---- ALB Listener ----
# Forwards all HTTP:80 traffic to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ---- IAM Role for EC2 ----
# Allows EC2 instances to write logs to CloudWatch
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach the AWS managed policy that allows CloudWatch Logs and SSM access
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Create instance profile (this is what gets attached to EC2 instances)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ---- EC2 Launch Template ----
# Defines the configuration for every new instance the ASG creates
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-backend-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  # Attach the IAM profile so instances can write to CloudWatch
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false # instances are in private subnets
    security_groups             = [var.backend_security_group_id]
  }

  # Render the startup script with runtime values
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    docker_image         = var.docker_image
    mongo_uri            = var.mongo_uri
    redis_endpoint       = var.redis_endpoint
    allowed_origins      = var.allowed_origins
    cloudwatch_log_group = var.cloudwatch_log_group
    aws_region           = var.aws_region
  }))

  # Always use the latest version of this template when ASG creates instances
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-launch-template"
    Environment = var.environment
  }
}

# ---- Auto Scaling Group ----
# Automatically adds/removes instances based on traffic load
resource "aws_autoscaling_group" "backend" {
  name                = "${var.project_name}-asg"
  min_size            = var.min_instances
  max_size            = var.max_instances
  desired_capacity    = var.desired_instances
  vpc_zone_identifier = var.private_subnet_ids # launch in private subnets

  # Register new instances with the ALB target group
  target_group_arns = [aws_lb_target_group.backend.arn]

  # Replace instances one at a time during updates (rolling update)
  health_check_type         = "ELB"
  health_check_grace_period = 120 # wait 2 min before checking health of new instances

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  # Rolling update: replace 1 instance at a time with no downtime
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}

# ---- Auto Scaling Policy: Scale Out ----
# Add an instance when average CPU goes above 70%
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1   # add 1 instance
  cooldown               = 300 # wait 5 min before scaling again
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend.name
  }

  alarm_actions     = [aws_autoscaling_policy.scale_out.arn]
  alarm_description = "Scale out when CPU > 70%"
}

# ---- Auto Scaling Policy: Scale In ----
# Remove an instance when average CPU drops below 30%
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1 # remove 1 instance
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend.name
  }

  alarm_actions     = [aws_autoscaling_policy.scale_in.arn]
  alarm_description = "Scale in when CPU < 30%"
}
