# Infrastructure Repository

## 📋 Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Arquitectura Multi-Cloud](#arquitectura-multi-cloud)
- [Tecnologías Utilizadas](#tecnologías-utilizadas)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Requisitos Previos](#requisitos-previos)
- [Configuración](#configuración)
- [Despliegue](#despliegue)
- [Recursos Desplegados](#recursos-desplegados)
- [Variables de Entorno](#variables-de-entorno)
- [Pipelines CI/CD](#pipelines-cicd)
- [Troubleshooting](#troubleshooting)
- [Contribución](#contribución)

## 📖 Descripción General

Este repositorio contiene toda la infraestructura como código (IaC) para el despliegue de una aplicación de gestión de TODOs basada en microservicios. La arquitectura implementa un enfoque **multi-cloud** utilizando Azure y AWS para maximizar la disponibilidad, resiliencia y tolerancia a fallos.

## Arquitectura Multi-Cloud

La aplicación está distribuida estratégicamente entre dos proveedores cloud:

### Azure Resources

- **Frontend** (Vue.js) - Azure Container Apps
- **Auth API** (Go) - Azure Container Apps
- **Users API** (Spring Framework) - Azure Container Apps
- **Container Apps Environment** - Entorno compartido con Log Analytics
- **Azure Cache for Redis** - Sistema de caché

### AWS Resources

- **TODOs API** (Node.js) - Amazon ECS Fargate
- **Log Message Processor** (Python) - Amazon ECS Fargate
- **ElastiCache Redis** - Sistema de colas/mensajería
- **CloudFront Distribution** - CDN para TODOs API (HTTPS)
- **ECR** - Registry de imágenes Docker
- **VPC, Subnets, Security Groups** - Networking
- **Zipkin** - Distributed tracing

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                         AZURE CLOUD                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Frontend │───→│ Auth API │───→│Users API │              │
│  │  (Vue)   │    │   (Go)   │    │ (Spring) │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│       │                                                       │
│       │          ┌─────────────────────┐                    │
│       │          │  Container Apps Env │                    │
│       │          │   + Log Analytics   │                    │
│       │          └─────────────────────┘                    │
│       │                                                       │
│       │          ┌─────────────────────┐                    │
│       └─────────→│  Azure Redis Cache  │                    │
│                  └─────────────────────┘                    │
│                                                               │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            │ HTTPS
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                          AWS CLOUD                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────┐         ┌──────────────────┐           │
│  │   CloudFront   │────────→│   TODOs API      │           │
│  │  Distribution  │         │   (Node.js)      │           │
│  │    (HTTPS)     │         │  ECS Fargate     │           │
│  └────────────────┘         └────────┬─────────┘           │
│                                       │                      │
│                                       ↓                      │
│                             ┌──────────────────┐            │
│                             │ ElastiCache Redis│            │
│                             │      Queue       │            │
│                             └────────┬─────────┘            │
│                                      │                       │
│                                      ↓                       │
│                             ┌──────────────────┐            │
│                             │ Log Message      │            │
│                             │   Processor      │            │
│                             │   (Python)       │            │
│                             └──────────────────┘            │
│                                                               │
│                             ┌──────────────────┐            │
│                             │     Zipkin       │            │
│                             │ Distributed      │            │
│                             │    Tracing       │            │
│                             └──────────────────┘            │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 🛠 Tecnologías Utilizadas

### Infrastructure as Code

- **Terraform** v1.5+ - Gestión de infraestructura
- **Bash Scripts** - Automatización de despliegue

### Cloud Providers

- **Microsoft Azure**
  - Azure Container Apps
  - Azure Cache for Redis
  - Azure Log Analytics
- **Amazon Web Services**
  - Amazon ECS Fargate
  - Amazon ElastiCache
  - Amazon CloudFront
  - Amazon ECR
  - Amazon VPC

### CI/CD

- Pipelines automatizados para infraestructura
- Docker Hub para imágenes de microservicios

### Monitoring & Observability

- Azure Log Analytics
- Zipkin (Distributed Tracing)

## Requisitos Previos

### Herramientas Necesarias

- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- AWS CLI >= 2.13.0
- Bash >= 4.0
- Docker (para testing local)

### Credenciales y Accesos

#### Azure

```bash
# Login a Azure
az login

# Configurar subscripción
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

#### AWS

```bash
# Configurar credenciales AWS
aws configure

# Verificar acceso
aws sts get-caller-identity
```

### Service Principals y Permisos

Asegúrate de tener los siguientes permisos:

- **Azure**: Contributor en el Resource Group
- **AWS**: Permisos para ECS, ElastiCache, CloudFront, ECR, VPC

## Configuración

### 1. Clonar el Repositorio

```bash
git clone https://github.com/tu-org/infrastructure.git
cd infrastructure
```

### 2. Configurar Variables de Entorno

Crea un archivo `terraform.tfvars` en el ambiente correspondiente:

```hcl
# environments/dev/terraform.tfvars

# Azure Configuration
azure_resource_group_name = "rg-todos-app-dev"
azure_location            = "eastus"
azure_subscription_id     = "your-subscription-id"

# AWS Configuration
aws_region     = "us-east-1"
aws_account_id = "your-account-id"

# Container Images (Docker Hub)
frontend_image          = "yourorg/frontend:latest"
auth_api_image          = "yourorg/auth-api:latest"
users_api_image         = "yourorg/users-api:latest"
todos_api_image         = "yourorg/todos-api:latest"
log_processor_image     = "yourorg/log-processor:latest"

# Application Configuration
environment = "dev"
```

### 3. Inicializar Terraform

```bash
cd environments/dev
terraform init
```

## Despliegue

### Despliegue Manual

```bash
# Planificar cambios
terraform plan -out=tfplan

# Aplicar cambios
terraform apply tfplan
```

### Despliegue con Script

```bash
# Desde la raíz del proyecto
./scripts/deploy.sh dev

# Para ambiente específico
./scripts/deploy.sh production
```

### Destruir Infraestructura

```bash
# Con script
./scripts/destroy.sh dev

# Manual
cd environments/dev
terraform destroy
```

## Recursos Desplegados

### Azure Resources

| Recurso               | Nombre         | Descripción            | Auto Scaling      |
| --------------------- | -------------- | ---------------------- | ----------------- |
| Container App         | `frontend-app` | Vue.js Frontend        | Min: 1, Max: 10   |
| Container App         | `auth-api`     | Auth Service (Go)      | Min: 2, Max: 20   |
| Container App         | `users-api`    | Users Service (Spring) | Min: 2, Max: 20   |
| Container Environment | `todos-env`    | Shared environment     | N/A               |
| Redis Cache           | `todos-redis`  | Caching layer          | Standard C1       |
| Log Analytics         | `todos-logs`   | Centralized logging    | 30 days retention |

### AWS Resources

| Recurso     | Nombre           | Descripción                | Auto Scaling |
| ----------- | ---------------- | -------------------------- | ------------ |
| ECS Service | `todos-api`      | TODOs Service (Node.js)    | No (sin ALB) |
| ECS Service | `log-processor`  | Message Processor (Python) | No (sin ALB) |
| ElastiCache | `todos-queue`    | Redis Queue                | t3.micro     |
| CloudFront  | `todos-cdn`      | HTTPS distribution         | N/A          |
| ECR         | `todos-registry` | Container registry         | N/A          |
| VPC         | `todos-vpc`      | Virtual network            | N/A          |

## Variables de Entorno

### Frontend (Vue.js)

El frontend utiliza un sistema de **placeholders** que son reemplazados en tiempo de compilación:

```javascript
// Archivo: .env.production
VUE_APP_AUTH_API_URL = __AUTH_API_URL__;
VUE_APP_USERS_API_URL = __USERS_API_URL__;
VUE_APP_TODOS_API_URL = __TODOS_API_URL__;
```

Script de reemplazo (`replace-env.sh`):

```bash
#!/bin/bash
sed -i "s|__AUTH_API_URL__|${AUTH_API_URL}|g" /app/dist/index.html
sed -i "s|__USERS_API_URL__|${USERS_API_URL}|g" /app/dist/index.html
sed -i "s|__TODOS_API_URL__|${TODOS_API_URL}|g" /app/dist/index.html
```

### Microservicios

Cada microservicio recibe sus variables a través de Container Apps / ECS:

```hcl
env_vars = [
  {
    name  = "DATABASE_URL"
    value = "postgresql://..."
  },
  {
    name  = "REDIS_HOST"
    value = azurerm_redis_cache.this.hostname
  },
  {
    name  = "AUTH_API_URL"
    value = "https://auth-api.azurecontainerapps.io"
  }
]
```

## Pipelines CI/CD

### Pipeline de Infraestructura

```yaml
# .github/workflows/terraform-deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve tfplan
```

### Pipeline de Microservicios

Cada repositorio de microservicio tiene su propio pipeline que:

1. Construye la imagen Docker
2. Pushea a Docker Hub
3. Notifica al contenedor para actualización

## Troubleshooting

### Problema: Users API se cae en Azure

**Síntoma**: El servicio Users API (Spring) se reinicia constantemente.

**Causa**: Spring Framework requiere más recursos de CPU y memoria.

**Solución**: Aumentar recursos en el módulo:

```hcl
cpu    = 1.0   # En lugar de 0.5
memory = "2Gi" # En lugar de 1Gi
```

### Problema: Frontend no carga variables de entorno

**Síntoma**: El frontend no puede conectarse a los APIs.

**Causa**: Vue.js no carga variables de entorno después de la compilación.

**Solución**: Usar placeholders y script de reemplazo (ver sección Variables de Entorno).

### Problema: Error HTTPS → HTTP

**Síntoma**: "Mixed Content: The page was loaded over HTTPS, but requested an insecure resource."

**Causa**: Frontend (HTTPS) intenta llamar a APIs expuestos en HTTP.

**Solución**:

- **Azure**: Container Apps tienen HTTPS por defecto
- **AWS**: Usar CloudFront para exponer con HTTPS

### Problema: No se puede usar ALB en AWS

**Síntoma**: Error de permisos al crear Application Load Balancer.

**Causa**: Restricciones en la cuenta de AWS.

**Solución**: Exponer TODOs API directamente y usar CloudFront para HTTPS.

### Problema: Auto Scaling no funciona en AWS

**Síntoma**: No hay escalado automático en servicios ECS.

**Causa**: Sin ALB no se pueden configurar target tracking policies.

**Solución**: Actualmente no implementado. Considerar:

- Pedir permisos de ALB
- Usar Step Scaling basado en métricas CloudWatch

## Notas Importantes

### HTTPS Obligatorio

Todos los servicios expuestos públicamente **deben** usar HTTPS:

- Azure Container Apps incluye HTTPS por defecto
- AWS requiere CloudFront para HTTPS

### Recursos de Spring Framework

Users API (Spring) necesita **más recursos** que otros microservicios:

- CPU mínimo: 1.0
- Memoria mínima: 2Gi

### Limitaciones AWS

Debido a restricciones en la cuenta AWS:

- ❌ No se puede usar Application Load Balancer
- ❌ Auto Scaling no está disponible para servicios ECS
- ✅ Usar CloudFront para exposición HTTPS

## 📚 Recursos Adicionales

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [AWS ECS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)

**Última actualización**: Septiembre 2025
