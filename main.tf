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
        }
      ]
    }]

    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 10
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
        },
        {
          name  = "ZIPKIN_URL"
          value = "http://${aws_lb.zipkin.dns_name}:9411/api/v2/spans"
        }
      ]
    }]

    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 10
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
          value = "https://api.torres-05.com"
        }
      ]
    }]

    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 10
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

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
  }

  depends_on = [aws_internet_gateway.main_igw]

}

resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
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




resource "aws_security_group" "alb" {
  name_prefix = "todos-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-security-group"
  }
}

resource "aws_lb" "todos_api" {
  name               = "todos-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public_subnet[*].id

  enable_deletion_protection = false

  tags = {
    Name = "todos-api-alb"
  }
}

# Target Group para TODOs API
resource "aws_lb_target_group" "todos_api" {
  name        = "todos-api-tg"
  port        = 8082
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "todos-api-target-group"
  }
}

# Certificado SSL en ACM para api.torres-05.com
resource "aws_acm_certificate" "todos_api" {
  domain_name       = "api.torres-05.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "todos-api-certificate"
  }
}

# Listener HTTP (puerto 80)
resource "aws_lb_listener" "todos_api_http" {
  load_balancer_arn = aws_lb.todos_api.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "todos_api_https" {
  load_balancer_arn = aws_lb.todos_api.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.todos_api.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.todos_api.arn
  }

  depends_on = [aws_acm_certificate_validation.todos_api]
}

resource "aws_acm_certificate_validation" "todos_api" {
  certificate_arn = aws_acm_certificate.todos_api.arn
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
          value = "http://${aws_lb.zipkin.dns_name}:9411/api/v2/spans"
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

  load_balancer {
    target_group_arn = aws_lb_target_group.todos_api.arn
    container_name   = "todos-api"
    container_port   = 8082
  }

  # Agregar dependencias explícitas
  depends_on = [
    aws_lb_listener.todos_api_http,
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
          value = "http://${aws_lb.zipkin.dns_name}:9411/api/v2/spans"
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
      image = "openzipkin/zipkin"

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

  load_balancer {
    target_group_arn = aws_lb_target_group.zipkin.arn
    container_name   = "zipkin"
    container_port   = 9411
  }

  service_registries {
    registry_arn = aws_service_discovery_service.zipkin.arn
  }

  depends_on = [
    aws_lb_listener.zipkin,
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


resource "aws_security_group" "alb_zipkin" {
  name_prefix = "zipkin-alb-"
  description = "Security group for Zipkin ALB"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  ingress {
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Zipkin port from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zipkin-alb-sg"
  }
}

# Load Balancer para Zipkin
resource "aws_lb" "zipkin" {
  name               = "zipkin-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_zipkin.id]
  subnets            = aws_subnet.public_subnet[*].id

  enable_deletion_protection = false

  tags = {
    Name = "zipkin-alb"
  }
}

# Target Group para Zipkin
resource "aws_lb_target_group" "zipkin" {
  name        = "zipkin-tg"
  port        = 9411
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "zipkin-target-group"
  }
}

# Listener para Zipkin
resource "aws_lb_listener" "zipkin" {
  load_balancer_arn = aws_lb.zipkin.arn
  port              = "9411"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.zipkin.arn
  }
}


# OUTPUTS
output "todos_api_load_balancer_dns" {
  description = "DNS name of the TODOs API Load Balancer"
  value       = aws_lb.todos_api.dns_name
}

output "todos_api_url" {
  description = "URL to access TODOs API"
  value       = "http://${aws_lb.todos_api.dns_name}"
}

output "zipkin_load_balancer_dns" {
  description = "DNS name of the Zipkin Load Balancer"
  value       = aws_lb.zipkin.dns_name
}

output "zipkin_url" {
  description = "URL to access Zipkin UI"
  value       = "http://${aws_lb.zipkin.dns_name}:9411"
}

output "load_balancer_arn" {
  description = "ARN of the TODOs API Load Balancer"
  value       = aws_lb.todos_api.arn
}

output "target_group_arn" {
  description = "ARN of the TODOs API Target Group"
  value       = aws_lb_target_group.todos_api.arn
}


output "certificate_validation_records" {
  description = "DNS records needed to validate the certificate"
  value = {
    for dvo in aws_acm_certificate.todos_api.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
}
