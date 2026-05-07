# -------------------------------------------------
# Monitoring Module - Main Resources
# Creates: CloudWatch Log Groups, SNS topic for
#          alerts, and ALB error rate alarms
# -------------------------------------------------

# ---- SNS Topic for Alerts ----
# All CloudWatch alarms send notifications here
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
  }
}

# Subscribe an email address to receive alert notifications
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
  # Note: AWS will send a confirmation email — you must click the link to activate
}

# ---- CloudWatch Log Groups ----
# Each service gets its own log group

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/starttech/${var.environment}/backend"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-backend-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "frontend_access" {
  name              = "/starttech/${var.environment}/cloudfront"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-cloudfront-logs"
    Environment = var.environment
  }
}

# ---- Alarm: High ALB 5xx Error Rate ----
# Fires when the backend is returning too many server errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-high"
  alarm_description   = "Backend is returning too many 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# ---- Alarm: High ALB Response Time ----
# Fires when the backend is responding slowly (p99 > 3 seconds)
resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${var.project_name}-alb-latency-high"
  alarm_description   = "Backend response time is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 3

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ---- CloudWatch Dashboard ----
# A single-page overview of the most important metrics
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "ALB Request Count"
          period  = 60
          stat    = "Sum"
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "ALB 5xx Errors"
          period  = 60
          stat    = "Sum"
          metrics = [["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix]]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "ALB Response Time (p99)"
          period  = 60
          stat    = "p99"
          metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]]
        }
      }
    ]
  })
}
