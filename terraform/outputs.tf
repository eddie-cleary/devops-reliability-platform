output "service_repository_url" {
  value = data.aws_ecr_repository.service.repository_url
}

output "monitor_repository_url" {
  value = data.aws_ecr_repository.monitor.repository_url
}