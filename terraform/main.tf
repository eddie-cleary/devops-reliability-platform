provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_ecr_repository" "service" {
  name                 = "reliability-service"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "monitor" {
  name                 = "reliability-monitor"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}