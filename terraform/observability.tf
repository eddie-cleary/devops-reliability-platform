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
