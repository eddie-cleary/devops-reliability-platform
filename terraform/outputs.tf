output "service_repository_url" {
  value = data.aws_ecr_repository.service.repository_url
}

output "monitor_repository_url" {
  value = data.aws_ecr_repository.monitor.repository_url
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}