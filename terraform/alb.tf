resource "aws_lb" "alb" {
  name = "devops-reliability-alb"

  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name        = "devops-reliability-alb"
    Project     = "devops-reliability"
    Environment = "dev"
  }
}
