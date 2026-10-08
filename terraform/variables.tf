variable "aws_region" {
  description = "AWS region for project resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile used by Terraform"
  type        = string
  default     = "devops-reliability"
}

variable "service_image_tag" {
  description = "ECR image tag for the reliability service"
  type        = string
}

variable "monitor_image_tag" {
  description = "ECR image tag for the reliability monitor"
  type        = string
}