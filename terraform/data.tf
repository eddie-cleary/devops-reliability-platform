data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# ECR Repositories are data sources because the /bootstrap terraform stack owns them
data "aws_ecr_repository" "service" {
  name = "reliability-service"
}

data "aws_ecr_repository" "monitor" {
  name = "reliability-monitor"
}

# Look up observability resources that are managed by the persistent bootstrap stack.
data "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/devops-reliability"
}

data "aws_sns_topic" "alarm_notifications" {
  name = "devops-reliability-alarm-notifications"
}

data "aws_caller_identity" "current" {}