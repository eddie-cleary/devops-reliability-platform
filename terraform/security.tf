resource "aws_security_group" "ecs_host" {
  name        = "devops-reliability-ecs-host"
  description = "Security group for ECS EC2 hosts"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "devops-reliability-ecs-host"
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_host_egress" {
  security_group_id = aws_security_group.ecs_host.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_security_group" "ecs_task" {
  name        = "devops-reliability-ecs-task"
  description = "Security group for ECS application tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "devops-reliability-ecs-task"
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_task_egress" {
  security_group_id = aws_security_group.ecs_task.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_task_ingress" {
  security_group_id = aws_security_group.ecs_task.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 8000
  to_port     = 8000
  ip_protocol = "tcp"
}

resource "aws_security_group" "alb" {
  name        = "devops-reliability-alb"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "devops-reliability-alb"
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress" {
  security_group_id = aws_security_group.alb.id

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}