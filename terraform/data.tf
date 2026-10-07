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