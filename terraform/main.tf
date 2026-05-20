# =============================================================================
# main.tf — Infraestrutura AWS ECS com Terraform
# Cria: ECS Cluster, Task Definition, Service, IAM Role e CloudWatch Logs
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Variáveis ---

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Nome da aplicação"
  type        = string
  default     = "trainee-devops-api"
}

variable "container_image" {
  description = "URI da imagem Docker no registry"
  type        = string
}

variable "container_port" {
  description = "Porta do container"
  type        = number
  default     = 5000
}

variable "desired_count" {
  description = "Número de tasks ECS rodando"
  type        = number
  default     = 2
}

# --- IAM Role para execução das tasks ECS ---
# Permite ao ECS puxar imagens do registry e escrever logs no CloudWatch

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- CloudWatch Log Group ---

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 30
}

# --- ECS Cluster ---

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# --- ECS Task Definition ---
# Define o container, recursos de CPU/memória e configurações de execução

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name      = var.app_name
    image     = var.container_image
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    healthCheck = {
      command     = ["CMD-SHELL", "wget -q --spider http://localhost:${var.container_port}/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# --- ECS Service ---
# Garante que o número desejado de tasks esteja sempre rodando

resource "aws_ecs_service" "app" {
  name            = var.app_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # Substitua pelos IDs reais das suas subnets e security group
  network_configuration {
    subnets          = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"]
    security_groups  = ["sg-xxxxxxxxx"]
    assign_public_ip = true
  }
}

# --- Outputs ---

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "log_group" {
  value = aws_cloudwatch_log_group.app.name
}
