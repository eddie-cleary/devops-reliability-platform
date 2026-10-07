resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/devops-reliability"
  retention_in_days = 7

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}