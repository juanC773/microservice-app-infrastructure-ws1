# Resource AZURE Group Module
module "resource_group" {
  source = "./modules/resource-group"

  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.common_tags
}

# Networking AZURE Module
module "networking" {
  source = "./modules/networking"

  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  vnet_name           = var.vnet_name
  address_space       = var.vnet_address_space
  subnet_name         = var.subnet_name
  address_prefixes    = var.subnet_address_prefixes
  subnet_delegation = {
    name         = "Microsoft.App.enviroments"
    service_name = "Microsoft.App/environments"
    actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
  tags = var.common_tags
}

# Container Environment Module
module "container_environment" {
  source = "./modules/container-environment"

  resource_group_name          = module.resource_group.resource_group_name
  location                     = module.resource_group.resource_group_location
  environment_name             = var.container_environment_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
  log_analytics_sku            = var.log_analytics_sku
  log_retention_days           = var.log_retention_days
  tags                         = var.common_tags
}

# Users App
module "users_app" {
  source = "./modules/container-app"

  app_name                     = "users-app"
  resource_group_name          = module.resource_group.resource_group_name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {

    min_replicas = 1
    max_replicas = 10

    containers = [{
      name   = "users-app-container"
      image  = "torres05/users-api-ws1:latest"
      cpu    = 0.5
      memory = "1.0Gi"
      env_vars = [
        {
          name  = "SERVER_PORT"
          value = "8083"
        },
        {
          name  = "SERVER_ADDRESS"
          value = "0.0.0.0"
        },
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        },
        {
          name  = "ZIPKIN_URL"
          value = "http://34.222.102.63:9411/api/v2/spans"
        }
      ]
    }]

    # Auto scaling por requests HTTP concurrentes
    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 10
    }]

    # Auto scaling por CPU
    cpu_scale_rules = [{
      name                     = "cpu-usage"
      cpu_percentage_threshold = 75
    }]

    # Auto scaling por Memoria
    memory_scale_rules = [{
      name                        = "memory-usage"
      memory_percentage_threshold = 80
    }]

  }

  ingress = {
    external_enabled   = true
    target_port        = 8083
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags = var.common_tags
}

# Auth App
module "auth_app" {
  source = "./modules/container-app"

  app_name                     = "auth-app"
  resource_group_name          = module.resource_group.resource_group_name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {

    min_replicas = 1
    max_replicas = 10

    containers = [{
      name   = "auth-app-container"
      image  = "torres05/auth-api-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env_vars = [
        {
          name  = "AUTH_API_PORT"
          value = "8000"
        },
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        },
        {
          name  = "USERS_API_ADDRESS"
          value = "http://users-app"
        }
      ]
    }]

    # Auto scaling por requests HTTP concurrentes
    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 10
    }]

    # Auto scaling por CPU
    cpu_scale_rules = [{
      name                     = "cpu-usage"
      cpu_percentage_threshold = 75
    }]

    # Auto scaling por Memoria
    memory_scale_rules = [{
      name                        = "memory-usage"
      memory_percentage_threshold = 80
    }]

  }

  ingress = {
    external_enabled   = true
    target_port        = 8000
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags       = var.common_tags
  depends_on = [module.users_app]
}


# Frontend App
module "frontend_app" {
  source = "./modules/container-app"

  app_name                     = "frontend-app"
  resource_group_name          = module.resource_group.resource_group_name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {

    min_replicas = 1
    max_replicas = 5

    containers = [{
      name   = "frontend-app-container"
      image  = "juanc7773/frontend-ws1:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      env_vars = [
        {
          name  = "AUTH_API_ADDRESS"
          value = "https://auth-app.${module.container_environment.container_app_environment_domain}"
        },
        {
          name  = "TODOS_API_ADDRESS"
          value = "https://${aws_cloudfront_distribution.todos_api.domain_name}"
        }
      ]
    }]

    # Auto scaling por requests HTTP concurrentes
    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 10
    }]

    # Auto scaling por CPU
    cpu_scale_rules = [{
      name                     = "cpu-usage"
      cpu_percentage_threshold = 75
    }]

    # Auto scaling por Memoria
    memory_scale_rules = [{
      name                        = "memory-usage"
      memory_percentage_threshold = 80
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 80
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags       = var.common_tags
  depends_on = [module.auth_app, aws_ecs_service.todos_api]
}





# AWS infrastructure

# NETWORKING

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_rta" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_subnet" "public_subnet" {
  count      = 2
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.${count.index + 1}.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main_igw]

}

resource "aws_subnet" "private_subnet" {
  count      = 2
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.${count.index + 10}.0/24"

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }

}






# ECS Cluster (equivalente al Container Environment de Azure)
resource "aws_ecs_cluster" "main_cluster" {
  name = "todos-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.todos_logs.name
      }
    }
  }
}



# TODOs API

resource "aws_cloudwatch_log_group" "todos_logs" {
  name              = "/ecs/todos-api"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# Task Definition para TODOs API
resource "aws_ecs_task_definition" "todos_api" {
  family                   = "todos-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "todos-api"
      image = "juanc7773/todos-api-ws1:latest"

      portMappings = [
        {
          containerPort = 8082
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "JWT_SECRET"
          value = var.jwt_secret
        },
        {
          name  = "TODO_API_PORT"
          value = "8082"
        },
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.redis.cache_nodes.0.address
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        },
        {
          name  = "REDIS_CHANNEL"
          value = "log_channel"
        },
        {
          name  = "ZIPKIN_URL"
          value = "http://34.222.102.63:9411/api/v2/spans"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.todos_logs.name
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])
}


# ECS Service para TODOs API
resource "aws_ecs_service" "todos_api" {
  name            = "todos-api"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.todos_api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public_subnet[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = true
  }


  # Agregar dependencias explícitas
  depends_on = [
    aws_internet_gateway.main_igw,
    aws_route_table.public_rt,
    aws_route_table_association.public_rta
  ]
}


resource "aws_security_group" "ecs_services" {
  name_prefix = "todos-ecs-"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permite comunicación interna entre servicios
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Service Discovery Namespace (para comunicación interna) para todos api 
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name = "todos.internal"
  vpc  = aws_vpc.main_vpc.id
}

####################################################
resource "aws_cloudfront_distribution" "todos_api" {
  origin {
    domain_name = "ec2-52-12-100-10.us-west-2.compute.amazonaws.com"
    origin_id   = "todos-api-http"

    custom_origin_config {
      http_port              = 8082
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled = true
  comment = "CloudFront for TODOs API - Temporary HTTPS"

  default_cache_behavior {
    target_origin_id       = "todos-api-http"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "todos-api-temporary-https"
  }
}

output "todos_api_https_url" {
  value = "https://${aws_cloudfront_distribution.todos_api.domain_name}"
}


##################################





# Redis como ElastiCache 

resource "aws_cloudwatch_log_group" "redis_logs" {
  name              = "/ecs/redis"
  retention_in_days = 7
}


resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-subnet-group"
  subnet_ids = aws_subnet.private_subnet[*].id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "todos-redis"
  engine               = "redis"
  engine_version       = "6.2" # Compatible con Node.js 8.17.0
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.ecs_services.id]

  apply_immediately = true
  tags = {
    Name = "todos-redis-cache"
  }
}



# LOG MESSAGE PROCESSOR

# Log Message Processor

resource "aws_cloudwatch_log_group" "log_processor_logs" {
  name              = "/ecs/log-message-processor"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "log_processor" {
  family                   = "log-message-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "log-message-processor"
      image = "juanc7773/log-message-processor:latest"

      environment = [
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_cluster.redis.cache_nodes.0.address
        },
        {
          name  = "REDIS_PORT"
          value = "6379"
        },
        {
          name  = "REDIS_CHANNEL"
          value = "log_channel"
        },
        {
          name  = "ZIPKIN_URL"
          value = "http://34.222.102.63:9411/api/v2/spans"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_processor_logs.name
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true
    }
  ])
}

resource "aws_ecs_service" "log_processor" {
  name            = "log-message-processor"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.log_processor.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private_subnet[*].id
    security_groups  = [aws_security_group.ecs_services.id]
    assign_public_ip = false
  }

  depends_on = [aws_elasticache_cluster.redis]
}






# ZIPKIN

# CloudWatch Log Group para Zipkin
resource "aws_cloudwatch_log_group" "zipkin_logs" {
  name              = "/ecs/zipkin"
  retention_in_days = 7

  tags = {
    Name = "zipkin-logs"
  }
}

# Task Definition para Zipkin
resource "aws_ecs_task_definition" "zipkin" {
  family                   = "zipkin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "zipkin"
      image = "openzipkin/zipkin:2.23"

      portMappings = [
        {
          containerPort = 9411
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "STORAGE_TYPE"
          value = "mem"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.zipkin_logs.name
          "awslogs-region"        = "us-west-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      essential = true

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9411/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

resource "aws_security_group" "zipkin" {
  name_prefix = "zipkin-"
  description = "Security group for Zipkin service"
  vpc_id      = aws_vpc.main_vpc.id

  # Permitir tráfico desde servicios internos
  ingress {
    from_port       = 9411
    to_port         = 9411
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_services.id]
    description     = "Allow internal ECS services to send traces"
  }

  ingress {
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Azure services and UI access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zipkin-sg"
  }
}

# ECS Service para Zipkin
resource "aws_ecs_service" "zipkin" {
  name            = "zipkin"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.zipkin.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public_subnet[*].id
    security_groups  = [aws_security_group.zipkin.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.zipkin.arn
  }

  depends_on = [
    aws_internet_gateway.main_igw,
    aws_route_table.public_rt,
    aws_route_table_association.public_rta
  ]

  tags = {
    Name = "zipkin-service"
  }
}

resource "aws_service_discovery_service" "zipkin" {
  name = "zipkin"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ============================================
# OUTPUTS para facilitar la configuración
# ============================================

output "zipkin_service_discovery_endpoint" {
  description = "Endpoint interno de Zipkin para servicios en AWS"
  value       = "http://zipkin.todos.internal:9411"
}



