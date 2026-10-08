# Keep container logs available across runtime teardown and recreation.
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/devops-reliability"
  retention_in_days = 7

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

# Keep the notification endpoint confirmed across runtime teardown.
resource "aws_sns_topic" "alarm_notifications" {
  name = "devops-reliability-alarm-notifications"

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarm_notifications.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}