resource "aws_ecs_cluster" "main" {
  name = "devops-reliability-cluster"

  # Publish the service-level RunningTaskCount metric used by the availability alarm.
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "devops-reliability-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  vpc_security_group_ids = [
    aws_security_group.ecs_host.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    EOF
  )
}

resource "aws_autoscaling_group" "ecs" {
  name = "devops-reliability-ecs-asg"

  min_size         = 0
  desired_capacity = 1
  max_size         = 1

  vpc_zone_identifier = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  # Preserve the management tag ECS adds for its capacity provider.
  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ecs" {
  name = "devops-reliability-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status = "ENABLED"
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    aws_ecs_capacity_provider.ecs.name
  ]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs.name
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "reliability-platform"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "512"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "reliability-service"
      image     = "${data.aws_ecr_repository.service.repository_url}:${var.service_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/healthy', timeout=2)\" || exit 1"
        ]

        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "service"
        }
      }
    },
    {
      name      = "reliability-monitor"
      image     = "${data.aws_ecr_repository.monitor.repository_url}:${var.monitor_image_tag}"
      essential = true
      command = [
        "--url",
        "http://127.0.0.1:8000/healthy",
        "--interval",
        "10",
        "--latency-warning",
        "1000",
        "--latency-critical",
        "3000",
        "--timeout",
        "5"
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "monitor"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "reliability-platform"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs.name
    weight            = 1
  }

  network_configuration {
    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id
    ]

    security_groups = [
      aws_security_group.ecs_task.id
    ]
  }
}
