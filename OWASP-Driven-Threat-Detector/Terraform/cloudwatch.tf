# CloudWatch Alarm:
# Goal: Monitor if CPU usage exceeds a threshold (80%)

resource "aws_cloudwatch_metric_alarm" "my_cpu_usage" {
  alarm_name                = "my_cpu_usage"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors ec2 cpu utilization"
  insufficient_data_actions = []
  alarm_actions = [aws_sns_topic.alarm_topic.arn]
}

# CloudWatch Log:
# Goal: Store application logs from EC2 instances

resource "aws_cloudwatch_log_group" "my_app_logs" {
  name = "/myapp/logs"
  tags = {
    Environment = "production"
    Application = "serviceA"
  }
}

# CloudWatch Metric Filter:
# Extract metrics (login attempts, error counts...)

resource "aws_cloudwatch_log_metric_filter" "my_error_counts" {
  name           = "My_Error_Count"
  pattern        = "ERROR"
  log_group_name = aws_cloudwatch_log_group.my_app_logs.name

  metric_transformation {
    name      = "EventCount"
    namespace = "MyApp/Monitoring"
    value     = "1"
  }
}

# Send Alerts to your email:
# When CPU alarm triggers an email will be received.

resource "aws_sns_topic" "my_alarm_topic" {
  name = "my_cloudwatch_alerts_topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.my_alarm_topic.arn
  protocol  = "email"
  endpoint  = var.alert_email
}