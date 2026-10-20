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

resource "aws_lb_target_group" "alb_tg" {
  name                 = "devops-reliability-alb-tg"
  port                 = 8000
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path              = "/healthy"
    interval          = 15
    healthy_threshold = 2
  }

  tags = {
    Name        = "devops-reliability-alb-tg"
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}