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

data "aws_iam_policy_document" "ecs_instance_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_instance" {
  name               = "DevOpsReliabilityECSInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume_role.json

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "DevOpsReliabilityECSInstanceProfile"
  role = aws_iam_role.ecs_instance.name
}

resource "aws_ecs_cluster" "main" {
  name = "devops-reliability-cluster"

  tags = {
    Project     = "devops-reliability"
    Environment = "dev"
  }
}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
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
      image     = "${aws_ecr_repository.service.repository_url}:${var.service_image_tag}"
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
    },
    {
      name      = "reliability-monitor"
      image     = "${aws_ecr_repository.monitor.repository_url}:${var.monitor_image_tag}"
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