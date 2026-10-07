resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/devops-reliability"
  retention_in_days = 7

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_running_task_count" {
  alarm_name          = "devops-reliability-ecs-running-task-count"
  alarm_description   = "Alarm when the ECS service has fewer than one running task or stops reporting metrics"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  threshold           = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Minimum"
  alarm_actions       = [aws_sns_topic.alarm_notifications.arn]
  ok_actions          = [aws_sns_topic.alarm_notifications.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  # Treat missing telemetry as a failure so an outage cannot silently pass
  treat_missing_data = "breaching"

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

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

resource "aws_sns_topic_policy" "alarm_notifications" {
  arn = aws_sns_topic.alarm_notifications.arn

  # Allow only this alarm, in this account, to publish notifications.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarmPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alarm_notifications.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_metric_alarm.ecs_running_task_count.arn
          }
          StringEquals = {
            "aws:SourceAccount" = aws_sns_topic.alarm_notifications.owner
          }
        }
      }
    ]
  })
}