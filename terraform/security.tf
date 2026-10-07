resource "aws_security_group" "ecs_host" {
  name        = "devops-reliability-ecs-host"
  description = "Security group for ECS EC2 hosts"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devops-reliability-ecs-host"
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_security_group" "ecs_task" {
  name        = "devops-reliability-ecs-task"
  description = "Security group for ECS application tasks"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "devops-reliability-ecs-task"
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_task_http" {
  security_group_id = aws_security_group.ecs_task.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 8000
  to_port     = 8000
  ip_protocol = "tcp"
}