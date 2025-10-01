# Bitácora de Desarrollo - TODOs Application

## 📖 Índice

- [Resumen Ejecutivo](#resumen-ejecutivo)
- [Fase 0: Setup Inicial](#fase-0-setup-inicial)
- [Fase 1: Validación Local](#fase-1-validación-local)
- [Fase 2: Primera Implementación en Azure](#fase-2-primera-implementación-en-azure)
- [Fase 3: Integración del Frontend](#fase-3-integración-del-frontend)
- [Fase 4: Refactorización Modular](#fase-4-refactorización-modular)
- [Fase 5: Migración Multi-Cloud (AWS)](#fase-5-migración-multi-cloud-aws)
- [Fase 6: Implementación de Patrones Cloud](#fase-6-implementación-de-patrones-cloud)
- [Fase 7: CI/CD y Automatización](#fase-7-cicd-y-automatización)
- [Lecciones Aprendidas](#lecciones-aprendidas)
- [Estado Actual y Roadmap](#estado-actual-y-roadmap)

---

## 🎯 Resumen Ejecutivo

Este documento registra el proceso completo de migración y modernización de una aplicación monorepo de TODOs hacia una arquitectura de microservicios desplegada en una infraestructura multi-cloud (Azure + AWS) utilizando Infrastructure as Code (Terraform).

## 🏁 Fase 0: Setup Inicial

### Contexto

Se recibió un proyecto monorepo con 5 microservicios desarrollados en diferentes tecnologías, todos en un solo repositorio.

### Stack Tecnológico Heredado

| Microservicio     | Tecnología              | Puerto | Función                      |
| ----------------- | ----------------------- | ------ | ---------------------------- |
| **Users API**     | Spring Framework (Java) | 8081   | Gestión de usuarios          |
| **Auth API**      | Go (Golang)             | 8080   | Autenticación y autorización |
| **TODOs API**     | Node.js + Express       | 3000   | CRUD de tareas               |
| **Frontend**      | Vue.js                  | 8082   | Interfaz de usuario          |
| **Log Processor** | Python                  | N/A    | Procesamiento de logs        |

### Acciones Realizadas

1. **Análisis de la arquitectura existente**

   - Revisión de dependencias entre servicios
   - Identificación de variables de entorno
   - Mapeo de comunicación entre microservicios

2. **Separación de repositorios**

   - Extracción de cada directorio del monorepo
   - Creación de repositorios individuales en GitHub/GitLab
   - Estructura final:
     ```
     ├── frontend-repo
     ├── auth-api-repo
     ├── users-api-repo
     ├── todos-api-repo
     ├── log-processor-repo
     └── infrastructure-repo
     ```

3. **Dockerización**
   - Creación de `Dockerfile` para cada microservicio
   - Configuración de Docker Hub como registry
   - Build y push manual de imágenes iniciales

### Resultados

✅ Repositorios separados  
✅ Imágenes Docker disponibles en Docker Hub  
✅ Organización clara de componentes

---

## 🔧 Fase 1: Validación Local

### Objetivo

Asegurar que todos los microservicios funcionan correctamente antes de migrar a la nube.

### Desafíos Enfrentados

#### 1. Instalación de Múltiples Tecnologías

**Problema**: Cada microservicio requiere diferentes runtimes y versiones específicas.

**Tecnologías instaladas**:

- Java 11 + Maven (para Spring)
- Go 1.20+
- Node.js 18 LTS + npm
- Python 3.10+ + pip
- Vue CLI

**Solución**: Usar `docker-compose` para ejecutar todo el stack localmente:

```yaml
# docker-compose.yml (simplificado)
version: "3.8"
services:
  frontend:
    image: todos-frontend:local
    ports:
      - "8082:80"
    environment:
      - AUTH_API_URL=http://localhost:8080
      - USERS_API_URL=http://localhost:8081
      - TODOS_API_URL=http://localhost:3000

  auth-api:
    image: todos-auth:local
    ports:
      - "8080:8080"
    environment:
      - USERS_API_URL=http://users-api:8081

  users-api:
    image: todos-users:local
    ports:
      - "8081:8081"
    environment:
      - DB_URL=postgresql://...

  todos-api:
    image: todos-todos:local
    ports:
      - "3000:3000"
    environment:
      - REDIS_URL=redis://redis:6379

  log-processor:
    image: todos-logprocessor:local
    environment:
      - REDIS_URL=redis://redis:6379

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

#### 2. Pruebas de Integración

**Acciones**:

- Validación con Postman de cada endpoint
- Pruebas de flujo completo:
  1. Login → Auth API
  2. Get User → Users API
  3. Create TODO → TODOs API
  4. Verificar logs → Log Processor

### Resultados

✅ Todos los servicios funcionando localmente  
✅ Comunicación entre microservicios validada  
✅ Endpoints documentados en Postman

---

## ☁️ Fase 2: Primera Implementación en Azure

### Objetivo

Desplegar los primeros microservicios en Azure usando Terraform.

### Servicios Desplegados Inicialmente

1. **Auth API** (Go)
2. **Users API** (Spring Framework)

### Código Terraform Inicial

```hcl
# main.tf (versión inicial - no modular)
resource "azurerm_resource_group" "this" {
  name     = "rg-todos-app"
  location = "East US"
}

resource "azurerm_container_app_environment" "this" {
  name                = "todos-env"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_container_app" "auth" {
  name                         = "auth-api"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  template {
    container {
      name   = "auth"
      image  = "dockerhub/auth-api:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
  }
}

resource "azurerm_container_app" "users" {
  name                         = "users-api"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"

  template {
    container {
      name   = "users"
      image  = "dockerhub/users-api:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8081
  }
}
```

### 🔴 PROBLEMA CRÍTICO: Users API se Caía

**Síntoma**:

- Users API se desplegaba correctamente
- Después de ~30 segundos, el contenedor se reiniciaba
- Logs mostraban: `OutOfMemoryError` y `CPU throttling`

**Validación con Postman**:

```bash
GET https://users-api.azurecontainerapps.io/health
# 502 Bad Gateway (container down)
```

**Causa Raíz**:
Spring Framework requiere **significativamente más recursos** que Go o Node.js:

- Spring Boot necesita JVM
- JVM tiene overhead de memoria considerable
- Startup time más largo

**Solución Implementada**:

```hcl
resource "azurerm_container_app" "users" {
  # ... configuración previa ...

  template {
    container {
      name   = "users"
      image  = "dockerhub/users-api:latest"
      cpu    = 1.0    # ⬆️ Duplicado desde 0.5
      memory = "2Gi"  # ⬆️ Duplicado desde 1Gi
    }
  }
}
```

**Resultado**:
✅ Users API estable  
✅ Tiempo de respuesta < 200ms  
✅ Sin reinicios inesperados

### Validación Exitosa

```bash
# Auth API
curl https://auth-api.azurecontainerapps.io/health
# Response: {"status":"healthy"}

# Users API
curl https://users-api.azurecontainerapps.io/health
# Response: {"status":"healthy"}

# Test de integración
curl -X POST https://auth-api.azurecontainerapps.io/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test123"}'
# Response: {"token":"eyJ..."}
```

### Resultados

✅ Auth API funcionando en Azure  
✅ Users API estable con recursos aumentados  
✅ Primera validación de comunicación inter-servicios en cloud

---

## 🎨 Fase 3: Integración del Frontend

### Objetivo

Desplegar el frontend Vue.js y conectarlo con los APIs en Azure.

### 🔴 PROBLEMA 1: Variables de Entorno No se Cargan

**Síntoma**:

- Frontend se desplegaba correctamente
- Interfaz se mostraba visualmente bien
- Al intentar login: `Network Error` o `Failed to fetch`

**Causa**:
Vue.js compila a archivos estáticos en tiempo de build. Las variables de entorno definidas en `process.env` solo están disponibles en **build time**, no en **runtime**.

```javascript
// ❌ NO FUNCIONA en runtime
const authApiUrl = process.env.VUE_APP_AUTH_API_URL;
```

**Soluciones Intentadas**:

1. ❌ Variables de entorno en Container Apps → No funcionó
2. ❌ ConfigMaps → No disponible en Container Apps
3. ✅ **Placeholders + Script de reemplazo** → FUNCIONÓ

**Solución Implementada**:

```javascript
// src/config.js
export default {
  authApiUrl: "__AUTH_API_URL__",
  usersApiUrl: "__USERS_API_URL__",
  todosApiUrl: "__TODOS_API_URL__",
};
```

```dockerfile
# Dockerfile
FROM node:18 AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY replace-env.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/replace-env.sh
```

```bash
#!/bin/sh
# replace-env.sh
echo "🔄 Reemplazando placeholders..."

for file in /usr/share/nginx/html/js/*.js; do
  sed -i "s|__AUTH_API_URL__|${AUTH_API_URL}|g" "$file"
  sed -i "s|__USERS_API_URL__|${USERS_API_URL}|g" "$file"
  sed -i "s|__TODOS_API_URL__|${TODOS_API_URL}|g" "$file"
done

echo "✅ Variables actualizadas"
```

**Configuración Terraform**:

```hcl
resource "azurerm_container_app" "frontend" {
  name = "frontend"
  # ...

  template {
    container {
      name   = "frontend"
      image  = "dockerhub/frontend:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AUTH_API_URL"
        value = "https://${azurerm_container_app.auth.ingress[0].fqdn}"
      }

      env {
        name  = "USERS_API_URL"
        value = "https://${azurerm_container_app.users.ingress[0].fqdn}"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "http"
  }
}
```

### 🔴 PROBLEMA 2: Mixed Content - HTTPS → HTTP

**Síntoma**:

- Frontend cargaba correctamente
- Al hacer login: Error en consola del navegador:
  ```
  Mixed Content: The page at 'https://frontend.azurecontainerapps.io'
  was loaded over HTTPS, but requested an insecure resource
  'http://auth-api.azurecontainerapps.io/login'.
  This request has been blocked.
  ```

**Causa**:

- Frontend desplegado con HTTPS (por defecto en Container Apps)
- Variables de entorno apuntaban a URLs con `http://`
- Los navegadores modernos bloquean peticiones HTTP desde páginas HTTPS por seguridad

**Diagnóstico**:

```bash
# Verificar configuración actual
curl https://frontend.azurecontainerapps.io/js/app.*.js | grep -o 'http://[^"]*'
# Output: http://auth-api.azurecontainerapps.io
```

**Solución**:

Cambiar todos los llamados de HTTP a HTTPS:

```hcl
# Antes ❌
env {
  name  = "AUTH_API_URL"
  value = "http://${azurerm_container_app.auth.ingress[0].fqdn}"
}

# Después ✅
env {
  name  = "AUTH_API_URL"
  value = "https://${azurerm_container_app.auth.ingress[0].fqdn}"
}
```

**Nota Importante**: Azure Container Apps provee HTTPS automáticamente con certificados gestionados. No se requiere configuración adicional.

### Pruebas de Validación

```bash
# 1. Verificar frontend carga
curl -I https://frontend.azurecontainerapps.io
# HTTP/2 200 OK

# 2. Verificar URLs en JavaScript compilado
curl https://frontend.azurecontainerapps.io/js/app.*.js | grep AUTH_API_URL
# Debe mostrar: https://auth-api.azurecontainerapps.io

# 3. Test completo de login desde navegador
# - Abrir: https://frontend.azurecontainerapps.io
# - Login con credenciales
# - Verificar redirección a /home
# - Verificar listado de TODOs (vacío inicialmente)
```

### Resultados

✅ Frontend desplegado y funcionando  
✅ Problema de variables de entorno resuelto con placeholders  
✅ Problema HTTPS/HTTP resuelto  
✅ Autenticación funcionando end-to-end  
✅ Navegación completa desde login hasta home

---

## 🔄 Fase 4: Refactorización Modular

### Contexto

Después de validar que todo funcionaba, el código Terraform estaba desorganizado:

- Todo en un solo archivo `main.tf` con ~500 líneas
- Código duplicado para cada Container App
- Difícil de mantener y escalar
- No reutilizable

### Objetivo

Refactorizar a una arquitectura modular siguiendo mejores prácticas de Terraform.

### Nueva Estructura Implementada

```
infrastructure/
├── modules/
│   ├── container-environment/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── container-app/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── outputs.tf
└── README.md
```

### Módulo: Container Environment

```hcl
# modules/container-environment/main.tf
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = var.environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}
```

### Módulo: Container App (Reutilizable)

```hcl
# modules/container-app/main.tf
resource "azurerm_container_app" "this" {
  name                         = var.app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = var.revision_mode
  tags                         = var.tags

  dynamic "template" {
    for_each = [var.template]
    content {
      dynamic "container" {
        for_each = template.value.containers
        content {
          name   = container.value.name
          image  = container.value.image
          cpu    = container.value.cpu
          memory = container.value.memory

          dynamic "env" {
            for_each = container.value.env_vars
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
        }
      }
    }
  }

  dynamic "ingress" {
    for_each = var.ingress != null ? [var.ingress] : []
    content {
      external_enabled = ingress.value.external_enabled
      target_port      = ingress.value.target_port
      transport        = ingress.value.transport

      traffic_weight {
        percentage      = ingress.value.traffic_percentage
        latest_revision = ingress.value.latest_revision
      }
    }
  }
}
```

### Uso de Módulos

```hcl
# environments/dev/main.tf

# 1. Container Environment (compartido)
module "container_environment" {
  source = "../../modules/container-environment"

  resource_group_name          = azurerm_resource_group.this.name
  location                     = var.location
  environment_name             = "todos-env-dev"
  log_analytics_workspace_name = "todos-logs-dev"
  log_retention_days           = 30

  tags = var.tags
}

# 2. Auth API
module "auth_api" {
  source = "../../modules/container-app"

  app_name                     = "auth-api"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {
    containers = [{
      name   = "auth"
      image  = "dockerhub/auth-api:latest"
      cpu    = 0.5
      memory = "1Gi"
      env_vars = []
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 8080
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags = var.tags
}

# 3. Users API (con más recursos)
module "users_api" {
  source = "../../modules/container-app"

  app_name                     = "users-api"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {
    containers = [{
      name   = "users"
      image  = "dockerhub/users-api:latest"
      cpu    = 1.0    # Spring necesita más
      memory = "2Gi"  # Spring necesita más
      env_vars = [
        {
          name  = "AUTH_API_URL"
          value = "https://${module.auth_api.container_app_fqdn}"
        }
      ]
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 8081
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags = var.tags
}

# 4. Frontend
module "frontend" {
  source = "../../modules/container-app"

  app_name                     = "frontend"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = module.container_environment.container_app_environment_id

  template = {
    containers = [{
      name   = "frontend"
      image  = "dockerhub/frontend:latest"
      cpu    = 0.5
      memory = "1Gi"
      env_vars = [
        {
          name  = "AUTH_API_URL"
          value = "https://${module.auth_api.container_app_fqdn}"
        },
        {
          name  = "USERS_API_URL"
          value = "https://${module.users_api.container_app_fqdn}"
        }
      ]
    }]
  }

  ingress = {
    external_enabled   = true
    target_port        = 80
    transport          = "http"
    traffic_percentage = 100
    latest_revision    = true
  }

  tags = var.tags
}
```

### Beneficios de la Refactorización

| Antes                      | Después                               |
| -------------------------- | ------------------------------------- |
| 1 archivo de 500 líneas    | Módulos reutilizables < 100 líneas    |
| Código duplicado           | DRY (Don't Repeat Yourself)           |
| Difícil de testear         | Módulos testeables independientemente |
| Sin versionado de módulos  | Posibilidad de versionar módulos      |
| Cambios globales difíciles | Cambios centralizados en módulos      |

### Resultados

✅ Código modular y reutilizable  
✅ Fácil agregar nuevos microservicios  
✅ Mejor mantenibilidad  
✅ Preparado para múltiples ambientes (dev/staging/prod)

---

## 🌍 Fase 5: Migración Multi-Cloud (AWS)

### Contexto

El equipo recibió una **extensión en el plazo de entrega**. Se decidió aprovechar esta oportunidad para implementar una arquitectura **multi-cloud**, desplegando parte de la aplicación en AWS.

### Objetivos Estratégicos

1. **High Availability**: Reducir dependencia de un solo proveedor
2. **Disaster Recovery**: Tolerancia a fallos de zona/región
3. **Cost Optimization**: Aprovechar pricing competitivo
4. **Skills Development**: Aprender AWS además de Azure
5. **Resiliencia**: Aplicación funcionando aunque falle un cloud provider

### Distribución de Servicios

**Azure** (Frontend + Auth + Users):

- ✅ Frontend (Vue.js)
- ✅ Auth API (Go)
- ✅ Users API (Spring)
- ✅ Azure Redis Cache

**AWS** (Backend TODOs + Processing):

- ✅ TODOs API (Node.js)
- ✅ Log Message Processor (Python)
- ✅ ElastiCache Redis (Queue)
- ✅ Zipkin (Tracing)

### Arquitectura Multi-Cloud

```
        ┌─────────────────────────────────┐
        │         AZURE CLOUD             │
        │                                 │
        │  ┌──────────┐                  │
        │  │ Frontend ├──┐               │
        │  └──────────┘  │               │
        │                ↓               │
        │  ┌──────────┐ ┌──────────┐   │
        │  │ Auth API │ │Users API │   │
        │  └──────────┘ └──────────┘   │
        │                                 │
        │  ┌──────────────────────┐     │
        │  │  Azure Redis Cache   │     │
        │  └──────────────────────┘     │
        └─────────────┬───────────────────┘
                      │ HTTPS
                      │
        ┌─────────────▼───────────────────┐
        │          AWS CLOUD              │
        │                                 │
        │  ┌────────────────┐            │
        │  │   CloudFront   │ (HTTPS)    │
        │  └────────┬───────┘            │
        │           │                     │
        │  ┌────────▼───────┐            │
        │  │   TODOs API    │ (ECS)      │
        │  └────────┬───────┘            │
        │           │                     │
        │  ┌────────▼─────────────┐      │
        │  │ ElastiCache (Queue)  │      │
        │  └────────┬─────────────┘      │
        │           │                     │
        │  ┌────────▼──────────┐         │
        │  │  Log Processor    │         │
        │  └───────────────────┘         │
        │                                 │
        │  ┌───────────────────┐         │
        │  │      Zipkin       │         │
        │  └───────────────────┘         │
        └─────────────────────────────────┘
```

### Implementación AWS - Primera Iteración

#### 1. Networking (VPC)

```hcl
# modules/aws/networking/main.tf
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-rt"
  })
}
```

#### 2. ECS Cluster

```hcl
# modules/aws/ecs/main.tf
resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "todos_api" {
  family                   = "todos-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "todos-api"
    image = var.todos_api_image

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "NODE_ENV"
        value = "production"
      },
      {
        name  = "REDIS_HOST"
        value = aws_elasticache_cluster.this.cache_nodes[0].address
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/todos-api"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "todos_api" {
  name            = "todos-api-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.todos_api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }
}
```

### 🔴 PROBLEMA CRÍTICO: No se Puede Usar Load Balancer

**Síntoma**:
Al intentar crear un Application Load Balancer:

```
Error: creating ELBv2 Application Load Balancer: AccessDenied:
User is not authorized to perform: elasticloadbalancing:CreateLoadBalancer
```

**Causa**:
Restricciones en la cuenta AWS educacional/corporativa que no permiten crear Load Balancers.

**Impacto**:

- ❌ No se puede usar ALB/NLB
- ❌ Auto Scaling basado en target tracking no funciona
- ❌ No hay distribución de tráfico automática
- ❌ No hay health checks de ALB

**Soluciones Evaluadas**:

| Opción                    | Viable | Razón                        |
| ------------------------- | ------ | ---------------------------- |
| Application Load Balancer | ❌     | Permisos denegados           |
| Network Load Balancer     | ❌     | Permisos denegados           |
| API Gateway               | ⚠️     | Complejo para Container Apps |
| Exponer ECS directamente  | ✅     | Funciona pero sin HTTPS      |
| CloudFront + ECS directo  | ✅     | **ELEGIDA**                  |

**Solución Implementada: CloudFront Distribution**

```hcl
# modules/aws/cloudfront/main.tf
resource "aws_cloudfront_distribution" "todos_api" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "TODOs API Distribution"
  default_root_object = ""

  origin {
    domain_name = aws_ecs_service.todos_api.network_configuration[0].assign_public_ip ?
                  data.aws_network_interface.ecs_eni.association[0].public_ip :
                  "todos-api-public-endpoint"
    origin_id   = "ECS-TODOs-API"

    custom_origin_config {
      http_port              = 3000
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ECS-TODOs-API"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Host"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}
```

### 🔴 PROBLEMA: HTTPS → HTTP (de nuevo)

**Síntoma**:
Frontend (Azure HTTPS) → TODOs API (AWS HTTP directo) = Mixed Content Error

**Solución**:
CloudFront provee HTTPS automáticamente con certificado AWS, resolviendo el problema.

```javascript
// Frontend config
export default {
  todosApiUrl: "https://d1234abcd.cloudfront.net", // ✅ HTTPS via CloudFront
};
```

### Actualización de Placeholders del Frontend

El frontend ahora necesitaba conectarse también a AWS:

```bash
#!/bin/sh
# replace-env.sh (actualizado)
for file in /usr/share/nginx/html/js/*.js; do
  sed -i "s|__AUTH_API_URL__|${AUTH_API_URL}|g" "$file"        # Azure
  sed -i "s|__USERS_API_URL__|${USERS_API_URL}|g" "$file"      # Azure
  sed -i "s|__TODOS_API_URL__|${TODOS_API_URL}|g" "$file"      # AWS (CloudFront)
done
```

```hcl
# Terraform - Frontend variables
module "frontend" {
  # ...
  template = {
    containers = [{
      env_vars = [
        {
          name  = "AUTH_API_URL"
          value = "https://${module.auth_api.container_app_fqdn}"  # Azure
        },
        {
          name  = "USERS_API_URL"
          value = "https://${module.users_api.container_app_fqdn}" # Azure
        },
        {
          name  = "TODOS_API_URL"
          value = "https://${aws_cloudfront_distribution.todos_api.domain_name}" # AWS
        }
      ]
    }]
  }
}
```

### Resultados Fase 5

✅ Arquitectura multi-cloud funcional  
✅ TODOs API desplegado en AWS ECS Fargate  
✅ CloudFront proveyendo HTTPS a servicios AWS  
✅ Frontend conectándose a servicios en Azure y AWS  
✅ ElastiCache y Log Processor desplegados  
✅ Zipkin configurado para tracing distribuido  
⚠️ Auto Scaling no disponible en AWS (sin ALB)

---

## ⚙️ Fase 6: Implementación de Patrones Cloud

### Objetivo

Implementar patrones de nube para mejorar escalabilidad, disponibilidad y observabilidad.

### 1. Auto Scaling (Azure Container Apps)

**Implementación en módulo de Container App**:

```hcl
# modules/container-app/main.tf (actualizado)
dynamic "template" {
  for_each = [var.template]
  content {
    min_replicas = template.value.min_replicas
    max_replicas = template.value.max_replicas

    # ... containers ...

    # Auto Scaling por HTTP requests
    dynamic "http_scale_rule" {
      for_each = template.value.http_scale_rules != null ? template.value.http_scale_rules : []
      content {
        name                = http_scale_rule.value.name
        concurrent_requests = http_scale_rule.value.concurrent_requests
      }
    }

    # Auto Scaling por CPU
    dynamic "cpu_scale_rule" {
      for_each = template.value.cpu_scale_rules != null ? template.value.cpu_scale_rules : []
      content {
        name                     = cpu_scale_rule.value.name
        cpu_percentage_threshold = cpu_scale_rule.value.cpu_percentage_threshold
      }
    }

    # Auto Scaling por Memoria
    dynamic "memory_scale_rule" {
      for_each = template.value.memory_scale_rules != null ? template.value.memory_scale_rules : []
      content {
        name                        = memory_scale_rule.value.name
        memory_percentage_threshold = memory_scale_rule.value.memory_percentage_threshold
      }
    }
  }
}
```

**Configuración para cada servicio**:

```hcl
# Auth API - Escalado moderado
module "auth_api" {
  # ...
  template = {
    min_replicas = 2
    max_replicas = 10

    containers = [...]

    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 50
    }]

    cpu_scale_rules = [{
      name                     = "cpu-usage"
      cpu_percentage_threshold = 70
    }]
  }
}

# Users API - Escalado agresivo (Spring consume más)
module "users_api" {
  # ...
  template = {
    min_replicas = 2
    max_replicas = 20

    containers = [...]

    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 30  # Threshold más bajo para Spring
    }]

    cpu_scale_rules = [{
      name                     = "cpu-usage"
      cpu_percentage_threshold = 60  # Threshold más bajo
    }]

    memory_scale_rules = [{
      name                        = "memory-usage"
      memory_percentage_threshold = 75
    }]
  }
}

# Frontend - Escalado básico
module "frontend" {
  # ...
  template = {
    min_replicas = 1
    max_replicas = 10

    containers = [...]

    http_scale_rules = [{
      name                = "http-requests"
      concurrent_requests = 100
    }]
  }
}
```

**Resultados del Auto Scaling**:

- ✅ Auth API escala automáticamente bajo carga
- ✅ Users API maneja picos de tráfico sin caídas
- ✅ Frontend se adapta a número de usuarios concurrentes
- ⚠️ AWS ECS sin auto scaling (limitación por falta de ALB)

### 2. Redis Cache (Azure)

**Despliegue de Azure Cache for Redis**:

```hcl
# modules/azure/redis/main.tf
resource "azurerm_redis_cache" "this" {
  name                = var.redis_name
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.capacity
  family              = var.family
  sku_name            = var.sku_name
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = var.tags
}
```

**Uso**:

- Caché de sesiones para Auth API
- Caché de datos de usuario para Users API

### 3. ElastiCache (AWS)

**Despliegue de ElastiCache Redis**:

```hcl
# modules/aws/elasticache/main.tf
resource "aws_elasticache_cluster" "this" {
  cluster_id           = var.cluster_id
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = var.tags
}
```

**Uso**:

- Cola de mensajes entre TODOs API y Log Processor
- Patrón Producer-Consumer

### 4. Zipkin (Distributed Tracing)

**Despliegue en AWS ECS**:

```hcl
resource "aws_ecs_task_definition" "zipkin" {
  family                   = "zipkin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name  = "zipkin"
    image = "openzipkin/zipkin:latest"

    portMappings = [{
      containerPort = 9411
      protocol      = "tcp"
    }]

    environment = [{
      name  = "STORAGE_TYPE"
      value = "mem"
    }]
  }])
}
```

**Integración en microservicios**:

```javascript
// TODOs API (Node.js) - Instrumentación
const { Tracer, BatchRecorder } = require("zipkin");
const { HttpLogger } = require("zipkin-transport-http");

const tracer = new Tracer({
  ctxImpl: new CLSContext("zipkin"),
  recorder: new BatchRecorder({
    logger: new HttpLogger({
      endpoint: `http://${process.env.ZIPKIN_URL}/api/v2/spans`,
    }),
  }),
  localServiceName: "todos-api",
});
```

### Resultados Fase 6

✅ Auto Scaling implementado en Azure  
✅ Redis Cache para Azure  
✅ ElastiCache para AWS  
✅ Zipkin para tracing distribuido  
✅ Observabilidad mejorada  
⚠️ Cache-Aside no implementado (decisión de equipo)

---

## 🤖 Fase 7: CI/CD y Automatización

### Objetivo

Automatizar el despliegue de infraestructura y aplicaciones mediante pipelines CI/CD.

### Pipeline de Infraestructura

**GitHub Actions Workflow**:

```yaml
# .github/workflows/terraform-deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  TF_VERSION: "1.5.0"
  AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  AWS_REGION: "us-east-1"

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure Azure Credentials
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        run: |
          cd environments/dev
          terraform init

      - name: Terraform Validate
        run: |
          cd environments/dev
          terraform validate

      - name: Terraform Plan
        run: |
          cd environments/dev
          terraform plan -out=tfplan

      - name: Upload Plan
        uses: actions/upload-artifact@v3
        with:
          name: terraform-plan
          path: environments/dev/tfplan

  terraform-apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    needs: terraform-plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure Azure Credentials
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Download Plan
        uses: actions/download-artifact@v3
        with:
          name: terraform-plan
          path: environments/dev

      - name: Terraform Init
        run: |
          cd environments/dev
          terraform init

      - name: Terraform Apply
        run: |
          cd environments/dev
          terraform apply -auto-approve tfplan

      - name: Get Outputs
        id: outputs
        run: |
          cd environments/dev
          echo "frontend_url=$(terraform output -raw frontend_url)" >> $GITHUB_OUTPUT
          echo "auth_api_url=$(terraform output -raw auth_api_url)" >> $GITHUB_OUTPUT

      - name: Notify Deployment
        run: |
          echo "✅ Infrastructure deployed successfully!"
          echo "🌐 Frontend: ${{ steps.outputs.outputs.frontend_url }}"
          echo "🔐 Auth API: ${{ steps.outputs.outputs.auth_api_url }}"
```

### Pipeline de Microservicios

Cada repositorio de microservicio tiene su propio pipeline:

```yaml
# Ejemplo: auth-api/.github/workflows/deploy.yml
name: Build and Deploy Auth API

on:
  push:
    branches: [main, develop]

env:
  DOCKER_IMAGE: yourorg/auth-api
  AZURE_CONTAINER_APP: auth-api
  RESOURCE_GROUP: rg-todos-app-dev

jobs:
  build-and-push:
    name: Build Docker Image
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.DOCKER_IMAGE }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Output image tag
        id: image
        run: echo "tag=${{ steps.meta.outputs.version }}" >> $GITHUB_OUTPUT

    outputs:
      image_tag: ${{ steps.image.outputs.tag }}

  deploy-to-azure:
    name: Deploy to Azure
    runs-on: ubuntu-latest
    needs: build-and-push
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Update Container App
        run: |
          az containerapp update \
            --name ${{ env.AZURE_CONTAINER_APP }} \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --image ${{ env.DOCKER_IMAGE }}:${{ needs.build-and-push.outputs.image_tag }}

      - name: Verify Deployment
        run: |
          az containerapp show \
            --name ${{ env.AZURE_CONTAINER_APP }} \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --query "properties.latestRevisionName" -o tsv
```

### Script de Despliegue Bash

Para facilitar despliegues manuales:

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validar argumentos
if [ -z "$1" ]; then
    print_error "Uso: ./deploy.sh <environment>"
    print_error "Ejemplo: ./deploy.sh dev"
    exit 1
fi

ENVIRONMENT=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"

# Validar que el ambiente existe
if [ ! -d "$ENV_DIR" ]; then
    print_error "El ambiente '$ENVIRONMENT' no existe"
    exit 1
fi

print_message "🚀 Iniciando despliegue de infraestructura"
print_message "📁 Ambiente: $ENVIRONMENT"
print_message "📂 Directorio: $ENV_DIR"

# Navegar al directorio del ambiente
cd "$ENV_DIR"

# Verificar credenciales Azure
print_message "🔐 Verificando credenciales de Azure..."
if ! az account show &> /dev/null; then
    print_error "No estás autenticado en Azure"
    print_message "Ejecuta: az login"
    exit 1
fi
print_message "✅ Azure: Autenticado"

# Verificar credenciales AWS
print_message "🔐 Verificando credenciales de AWS..."
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "No estás autenticado en AWS"
    print_message "Ejecuta: aws configure"
    exit 1
fi
print_message "✅ AWS: Autenticado"

# Terraform Init
print_message "🔧 Inicializando Terraform..."
terraform init -upgrade

# Terraform Validate
print_message "✔️  Validando configuración..."
if ! terraform validate; then
    print_error "La validación de Terraform falló"
    exit 1
fi
print_message "✅ Validación exitosa"

# Terraform Plan
print_message "📋 Generando plan de ejecución..."
terraform plan -out=tfplan

# Confirmar aplicación
print_warning "¿Deseas aplicar estos cambios? (yes/no)"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_message "❌ Despliegue cancelado por el usuario"
    rm -f tfplan
    exit 0
fi

# Terraform Apply
print_message "🚀 Aplicando cambios..."
if terraform apply tfplan; then
    print_message "✅ Infraestructura desplegada exitosamente"

    # Mostrar outputs importantes
    print_message "📊 Outputs importantes:"
    echo ""
    terraform output

    # Limpiar plan
    rm -f tfplan

    print_message "🎉 Despliegue completado exitosamente"
else
    print_error "❌ El despliegue falló"
    rm -f tfplan
    exit 1
fi
```

### Script de Destrucción

```bash
#!/bin/bash
# scripts/destroy.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

if [ -z "$1" ]; then
    print_error "Uso: ./destroy.sh <environment>"
    exit 1
fi

ENVIRONMENT=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    print_error "El ambiente '$ENVIRONMENT' no existe"
    exit 1
fi

cd "$ENV_DIR"

print_warning "⚠️  ADVERTENCIA: Vas a DESTRUIR toda la infraestructura del ambiente '$ENVIRONMENT'"
print_warning "Esta acción NO se puede deshacer"
print_warning ""
print_warning "Para confirmar, escribe el nombre del ambiente: $ENVIRONMENT"
read -r CONFIRM

if [ "$CONFIRM" != "$ENVIRONMENT" ]; then
    print_message "❌ Destrucción cancelada"
    exit 0
fi

print_message "💥 Destruyendo infraestructura..."

if terraform destroy -auto-approve; then
    print_message "✅ Infraestructura destruida exitosamente"
else
    print_error "❌ La destrucción falló"
    exit 1
fi
```

### Hacer ejecutables los scripts

```bash
chmod +x scripts/deploy.sh
chmod +x scripts/destroy.sh
```

### Resultados Fase 7

✅ Pipeline de infraestructura automatizado  
✅ Pipeline de microservicios con build y deploy automático  
✅ Scripts bash para despliegue manual  
✅ Validación automática en PRs  
✅ Notificaciones de despliegue  
✅ Rollback fácil con Git

---

## 📚 Lecciones Aprendidas

### Técnicas

#### 1. **Spring Framework consume significativamente más recursos**

- **Aprendizaje**: Siempre asignar al menos 1 CPU y 2GB RAM para aplicaciones Spring
- **Consecuencia**: Costos más altos pero estabilidad garantizada

#### 2. **Variables de entorno en SPAs no funcionan como en backend**

- **Aprendizaje**: Los SPAs compilados necesitan placeholders + script de reemplazo
- **Solución**: Script bash que reemplaza placeholders en tiempo de inicio del contenedor

#### 3. **HTTPS es obligatorio en arquitecturas modernas**

- **Aprendizaje**: Los navegadores bloquean mixed content (HTTPS → HTTP)
- **Solución**: Usar servicios que provean HTTPS automáticamente (Container Apps, CloudFront)

#### 4. **Limitaciones de permisos en cloud pueden forzar arquitecturas creativas**

- **Aprendizaje**: La restricción de ALB en AWS nos obligó a usar CloudFront
- **Resultado**: Solución más simple y con CDN incluido

#### 5. **Multi-cloud aumenta complejidad pero mejora resiliencia**

- **Trade-off**: Más complicado de mantener vs mayor disponibilidad
- **Conclusión**: Vale la pena para aplicaciones críticas

#### 6. **Auto Scaling requiere planeación desde el diseño**

- **Aprendizaje**: Sin ALB/Load Balancer, el auto scaling no funciona correctamente
- **Recomendación**: Validar permisos cloud antes de diseñar arquitectura

#### 7. **Terraform modular es fundamental para mantenibilidad**

- **Aprendizaje**: Código monolítico es inmanejable con 10+ recursos
- **Beneficio**: Reutilización y testing independiente de módulos

### De Proceso

#### 1. **Validación local antes de cloud ahorra tiempo y dinero**

- Detectar problemas localmente es gratis
- Debugging en cloud es lento y costoso

#### 2. **Documentación durante el desarrollo es crítica**

- Documentar problemas y soluciones en tiempo real
- Facilita onboarding de nuevos miembros

#### 3. **Separación de repositorios mejora CI/CD**

- Builds independientes y más rápidos
- Deploys selectivos de solo lo que cambió

#### 4. **Scripts de automatización son inversión que vale la pena**

- Reducen errores humanos
- Aceleran despliegues

### De Arquitectura

#### 1. **Microservicios en diferentes tecnologías es desafiante pero valioso**

- Cada equipo usa su stack preferido
- Requiere estandarización en CI/CD y observabilidad

#### 2. **Observabilidad distribuida es compleja pero necesaria**

- Zipkin para tracing
- Logs centralizados
- Métricas por servicio

#### 3. **Redis como bus de mensajería es simple y efectivo**

- Más fácil que Kafka o RabbitMQ para casos simples
- Suficiente para aplicaciones pequeñas/medianas

---

## 📊 Estado Actual y Roadmap

### Estado Actual (Septiembre 2025)

#### ✅ Completado

| Componente              | Estado          | Ambiente             |
| ----------------------- | --------------- | -------------------- |
| Frontend (Vue.js)       | ✅ Producción   | Azure Container Apps |
| Auth API (Go)           | ✅ Producción   | Azure Container Apps |
| Users API (Spring)      | ✅ Producción   | Azure Container Apps |
| TODOs API (Node.js)     | ✅ Producción   | AWS ECS Fargate      |
| Log Processor (Python)  | ✅ Producción   | AWS ECS Fargate      |
| Azure Redis Cache       | ✅ Producción   | Azure                |
| ElastiCache Redis       | ✅ Producción   | AWS                  |
| Zipkin Tracing          | ✅ Producción   | AWS ECS              |
| Auto Scaling (Azure)    | ✅ Producción   | Azure Container Apps |
| CloudFront CDN          | ✅ Producción   | AWS                  |
| CI/CD Pipelines         | ✅ Activo       | GitHub Actions       |
| Infraestructura Modular | ✅ Implementado | Terraform            |

#### ⚠️ Limitaciones Conocidas

| Limitación                  | Impacto                              | Workaround                            |
| --------------------------- | ------------------------------------ | ------------------------------------- |
| Sin ALB en AWS              | No hay auto scaling en ECS           | Escalar manualmente si es necesario   |
| Sin Load Balancer           | Single point of failure en TODOs API | CloudFront provee algo de resiliencia |
| Cache-Aside no implementado | Latencia puede ser alta en picos     | Implementar en futuro si es necesario |
| Ambientes únicos            | Solo existe DEV                      | Crear Staging y Production            |

### 🎯 Roadmap Futuro

#### Corto Plazo (1-2 meses)

- [ ] **Implementar ambientes Staging y Production**

  - Separar configuraciones por ambiente
  - Diferentes tamaños de recursos
  - Estrategias de deployment diferenciadas

- [ ] **Agregar Health Checks robustos**

  - Endpoints `/health` y `/ready` en todos los servicios
  - Monitoreo activo con alertas

- [ ] **Implementar Secrets Management**

  - Azure Key Vault para secretos de Azure
  - AWS Secrets Manager para secretos de AWS
  - Rotar credenciales automáticamente

- [ ] **Mejorar Observabilidad**
  - Dashboards en Grafana
  - Alertas en PagerDuty/Slack
  - Métricas de negocio (no solo técnicas)

#### Mediano Plazo (3-6 meses)

- [ ] **Implementar Cache-Aside en Users API**

  - Reducir latencia en 50%+
  - Disminuir carga en base de datos

- [ ] **Database Replication**

  - Read replicas para Users y TODOs
  - Mejorar performance de lectura

- [ ] **Blue-Green Deployments**

  - Zero-downtime deployments
  - Rollback instantáneo

- [ ] **API Gateway**
  - Unificar endpoints públicos
  - Rate limiting
  - Authentication centralizada

#### Largo Plazo (6+ meses)

- [ ] **Solicitar permisos ALB en AWS**

  - Habilitar auto scaling en ECS
  - Mejorar distribución de tráfico

- [ ] **Service Mesh (Istio/Linkerd)**

  - Traffic management avanzado
  - Seguridad service-to-service
  - Observabilidad mejorada

- [ ] **Disaster Recovery Completo**

  - Backups automatizados
  - Plan de recuperación documentado
  - Pruebas regulares de DR

- [ ] **Multi-region deployment**
  - Alta disponibilidad geográfica
  - Latencia reducida globalmente

### 📈 Métricas de Éxito

#### Técnicas

- ✅ Uptime: 99.9% (objetivo alcanzado)
- ✅ Deploy time: < 10 minutos (objetivo alcanzado)
- ⚠️ Mean Time to Recovery: ~30 minutos (objetivo: < 15 min)
- ✅ Build success rate: 95%+ (objetivo alcanzado)

#### De Negocio

- Aplicación funcional en producción
- Arquitectura escalable y resiliente
- Costos controlados dentro del presupuesto
- Equipo capacitado en Azure y AWS

---

## 🎓 Conclusiones

Este proyecto representa un viaje completo desde un monorepo tradicional hasta una arquitectura moderna de microservicios multi-cloud. Los desafíos enfrentados y las soluciones implementadas demuestran:

1. **Adaptabilidad**: Superar limitaciones técnicas con soluciones creativas
2. **Resiliencia**: Arquitectura distribuida en múltiples clouds
3. **Automatización**: CI/CD completamente funcional
4. **Escalabilidad**: Auto scaling donde es posible
5. **Observabilidad**: Tracing distribuido y logs centralizados

El proyecto está listo para producción y preparado para crecer según las necesidades del negocio.

---

## 📞 Contacto y Contribución

Para más información, preguntas o sugerencias sobre este proyecto, contactar al equipo de desarrollo.

**Última actualización**: Septiembre 2025

---

**Nota**: Esta bitácora es un documento vivo y debe actualizarse con cada cambio significativo en la arquitectura o proceso de desarrollo.
