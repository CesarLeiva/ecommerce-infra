# Guía Completa: Cómo Estructurar un Proyecto de Terraform desde Cero

## 📋 Índice

1. [Introducción](#introducción)
2. [Estructura Base del Proyecto](#estructura-base-del-proyecto)
3. [Archivos Raíz: Responsabilidades](#archivos-raíz-responsabilidades)
4. [Módulos: Filosofía y Organización](#módulos-filosofía-y-organización)
5. [Gestión de Ambientes](#gestión-de-ambientes)
6. [Paso a Paso: Iniciando un Proyecto](#paso-a-paso-iniciando-un-proyecto)
7. [Patrones y Mejores Prácticas](#patrones-y-mejores-prácticas)
8. [Ejemplos Prácticos de Módulos](#ejemplos-prácticos-de-módulos)

---

## Introducción

Esta guía te llevará paso a paso por el proceso de estructurar un proyecto de Terraform profesional, desde la concepción inicial hasta la implementación de módulos complejos. La metodología presentada se basa en principios de **modularidad**, **reutilización** y **separación de responsabilidades**.

### Principios Fundamentales

- **Módulos autocontenidos**: Cada módulo debe incluir no solo el recurso principal, sino también sus dependencias lógicas (permisos, políticas, recursos complementarios)
- **Separación por ambientes**: Usa archivos `.tfvars` para configuración específica de cada entorno
- **Remote State**: Mantén el estado en un backend remoto (S3) para trabajo colaborativo
- **Documentación integrada**: Cada módulo debe tener su propio README
- **Versionamiento de providers**: Fija versiones específicas para evitar comportamientos inesperados

---

## Estructura Base del Proyecto

```
proyecto-infra/
├── config.tf                    # Configuración de providers y backend
├── main.tf                      # Orquestación de módulos
├── variables.tf                 # Definiciones de variables del root
├── outputs.tf                   # Outputs del root
├── README.md                    # Documentación principal
│
├── environments/                # Configuración por ambiente
│   ├── dev.tfvars
│   ├── dev.tfbackend
│   ├── qa.tfvars
│   ├── qa.tfbackend
│   ├── prod.tfvars
│   └── prod.tfbackend
│
├── modules/                     # Módulos reutilizables
│   ├── networking/
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   ├── outputs.tf
│   │   │   └── README.md
│   │   └── alb/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   │
│   ├── compute/
│   │   ├── main.tf              # Orquesta submódulos (ECR + ECS Service)
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── ecr/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── ecs-service/
│   │       ├── main.tf          # Incluye: Service, TG, ASG, SG, IAM
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   │
│   ├── database/
│   │   └── rds/
│   │       ├── main.tf          # Incluye: RDS, SG, Subnet Group, IAM
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── README.md
│   │
│   ├── security/
│   │   ├── kms/
│   │   ├── secrets/
│   │   └── waf/
│   │
│   └── observability/
│       ├── cloudwatch-alarms/
│       └── cloudtrail/
│
└── docs/                        # Documentación adicional
    ├── ARCHITECTURE.md
    ├── DEPLOYMENT.md
    └── TROUBLESHOOTING.md
```

---

## Archivos Raíz: Responsabilidades

### 1. `config.tf` - Configuración de Terraform y Providers

**Responsabilidad**: Define la versión de Terraform, backend remoto y providers necesarios.

```terraform
terraform {
  required_version = ">= 1.13.0"

  # Backend remoto en S3
  backend "s3" {}  # Configuración se pasa por .tfbackend

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19.0"  # Versión específica
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Provider principal
provider "aws" {
  region = var.aws_region
}

# Provider para recursos globales (ej: CloudFront WAF)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

**Recomendaciones**:
- ✅ Fija versiones específicas de providers (evita `>=`, usa `~>`)
- ✅ Crea aliases para providers en diferentes regiones si es necesario
- ✅ Deja la configuración del backend vacía (se pasa por CLI con `-backend-config`)

---

### 2. `variables.tf` - Definiciones de Variables

**Responsabilidad**: Declara todas las variables que usará el módulo raíz, con tipos y descripciones claras.

```terraform
# ========================================
# GENERAL
# ========================================
variable "aws_region" {
  description = "AWS region para deployment"
  type        = string
}

variable "prefix" {
  description = "Prefijo para nombres de recursos"
  type        = string
  
  validation {
    condition     = length(var.prefix) <= 10
    error_message = "El prefijo debe tener máximo 10 caracteres"
  }
}

variable "env" {
  description = "Ambiente de deployment (dev, qa, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "El ambiente debe ser dev, qa o prod"
  }
}

# ========================================
# NETWORKING
# ========================================
variable "vpc_cidr" {
  description = "CIDR block para VPC"
  type        = string
}

variable "availability_zones" {
  description = "AZs donde crear subnets"
  type        = list(string)
}

# ========================================
# COMPUTE - ECS SERVICES
# ========================================
variable "services" {
  description = "Mapa de servicios ECS a desplegar"
  type = map(object({
    listener_rule_priority = number
    path_pattern           = string
    container_port         = number
    health_check_path      = string
    health_check_matcher   = string
    environment_variables = list(object({
      name  = string
      value = string
    }))
  }))
}

# ========================================
# FEATURE FLAGS
# ========================================
variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway para subnets privadas"
  type        = bool
  default     = true
}

variable "enable_bastion" {
  description = "Habilitar Bastion Host"
  type        = bool
  default     = false
}
```

**Recomendaciones**:
- ✅ Agrupa variables por categoría (general, networking, compute, etc.)
- ✅ Usa `validation` blocks para validar valores
- ✅ Proporciona descripciones claras y concisas
- ✅ Define `default` solo para valores opcionales o flags
- ✅ Usa tipos complejos (`object`, `map`) para configuraciones estructuradas

---

### 3. `main.tf` - Orquestación de Módulos

**Responsabilidad**: Instancia y conecta todos los módulos, pasándoles las variables necesarias.

```terraform
# ========================================
# NETWORKING
# ========================================
module "vpc" {
  source = "./modules/vpc"

  prefix                  = var.prefix
  env                     = var.env
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  app_subnet_cidrs        = var.app_subnet_cidrs
  data_subnet_cidrs       = var.data_subnet_cidrs
  availability_zones      = var.availability_zones
  enable_nat_gateway      = var.enable_nat_gateway
  enable_flow_logs        = var.enable_vpc_flow_logs
  flow_logs_s3_bucket_arn = module.logs_bucket.bucket_arn

  depends_on = [module.logs_bucket]
}

module "alb" {
  source = "./modules/alb"

  prefix                     = var.prefix
  env                        = var.env
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.public_subnet_ids
  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_https               = var.enable_https
  certificate_arn            = module.acm.certificate_arn

  depends_on = [module.acm]
}

# ========================================
# COMPUTE
# ========================================
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  prefix                    = var.prefix
  env                       = var.env
  enable_container_insights = var.enable_container_insights
  log_retention_days        = var.log_retention_days
}

# Despliega múltiples servicios usando for_each
module "compute" {
  source   = "./modules/compute"
  for_each = var.services

  prefix                = var.prefix
  env                   = var.env
  service_name          = each.key
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.app_subnet_ids
  cluster_id            = module.ecs_cluster.cluster_id
  cluster_name          = module.ecs_cluster.cluster_name
  listener_arn          = module.alb.https_listener_arn
  listener_rule_priority = each.value.listener_rule_priority
  path_pattern          = each.value.path_pattern
  container_port        = each.value.container_port
  health_check_path     = each.value.health_check_path
  environment_variables = each.value.environment_variables

  depends_on = [module.ecs_cluster, module.alb]
}

# ========================================
# DATABASE
# ========================================
module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "./modules/rds"

  prefix                    = var.prefix
  env                       = var.env
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.data_subnet_ids
  allowed_security_groups   = [for svc in module.compute : svc.security_group_id]
  kms_key_arn               = module.kms.kms_key_arn
  instance_class            = var.rds_instance_class
  allocated_storage         = var.rds_allocated_storage

  depends_on = [module.kms, module.compute]
}

# ========================================
# SECURITY
# ========================================
module "kms" {
  source = "./modules/kms"

  prefix                  = var.prefix
  env                     = var.env
  deletion_window_in_days = var.kms_deletion_window_in_days
}

module "secrets" {
  source = "./modules/secrets"

  prefix              = var.prefix
  env                 = var.env
  kms_key_id          = module.kms.kms_key_id
  db_username         = var.db_username
  db_password         = module.rds[0].db_password
  db_host             = module.rds[0].db_address
  db_endpoint         = module.rds[0].db_endpoint
  redis_primary_endpoint = module.elasticache[0].primary_endpoint

  depends_on = [module.kms, module.rds, module.elasticache]
}
```

**Recomendaciones**:
- ✅ Agrupa módulos por categoría con comentarios
- ✅ Usa `for_each` para desplegar múltiples instancias de un módulo
- ✅ Usa `count` para recursos opcionales (ej: `count = var.enable_rds ? 1 : 0`)
- ✅ Define explícitamente `depends_on` cuando hay dependencias implícitas
- ✅ Referencia outputs de otros módulos para conectarlos

---

### 4. `outputs.tf` - Outputs del Proyecto

**Responsabilidad**: Expone información importante del deployment.

```terraform
# ========================================
# NETWORKING
# ========================================
output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS del Application Load Balancer"
  value       = module.alb.alb_dns_name
}

# ========================================
# COMPUTE
# ========================================
output "ecs_cluster_name" {
  description = "Nombre del ECS Cluster"
  value       = module.ecs_cluster.cluster_name
}

output "ecr_repositories" {
  description = "URLs de los repositorios ECR por servicio"
  value       = { for k, v in module.compute : k => v.ecr_repository_url }
}

# ========================================
# DATABASE
# ========================================
output "rds_endpoint" {
  description = "Endpoint de conexión RDS"
  value       = var.enable_rds ? module.rds[0].db_endpoint : null
  sensitive   = true
}

# ========================================
# SECURITY
# ========================================
output "kms_key_arn" {
  description = "ARN de la KMS key principal"
  value       = module.kms.kms_key_arn
}

output "secrets_arns" {
  description = "ARNs de los secrets en Secrets Manager"
  value = {
    rds   = module.secrets.rds_secret_arn
    redis = module.secrets.redis_secret_arn
  }
  sensitive = true
}

# ========================================
# CI/CD
# ========================================
output "github_actions_role_arn" {
  description = "ARN del rol IAM para GitHub Actions OIDC"
  value       = var.enable_cicd ? module.cicd[0].github_actions_role_arn : null
}
```

**Recomendaciones**:
- ✅ Agrupa outputs por categoría
- ✅ Marca como `sensitive = true` información sensible
- ✅ Usa descripciones claras
- ✅ Usa objetos/mapas para outputs relacionados

---

## Módulos: Filosofía y Organización

### Principio Fundamental: Módulos Autocontenidos

**❌ INCORRECTO**: Crear módulos que solo crean el recurso principal

```terraform
# ❌ Módulo RDS simple (INCOMPLETO)
resource "aws_db_instance" "main" {
  identifier     = var.identifier
  engine         = "postgres"
  instance_class = var.instance_class
  # ...
}
```

**✅ CORRECTO**: Módulos que incluyen TODO lo necesario

```terraform
# ✅ Módulo RDS completo (AUTOCONTENIDO)

# Security Group para RDS
resource "aws_security_group" "rds" {
  name        = "${var.prefix}-${var.env}-rds-sg"
  vpc_id      = var.vpc_id
  # reglas de ingress/egress
}

# Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.prefix}-${var.env}-db-subnet-group"
  subnet_ids = var.subnet_ids
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "${var.prefix}-${var.env}-db-pg"
  family = var.parameter_group_family
  # parámetros personalizados
}

# RDS Instance (recurso principal)
resource "aws_db_instance" "main" {
  identifier              = "${var.prefix}-${var.env}-postgres"
  engine                  = "postgres"
  instance_class          = var.instance_class
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  parameter_group_name    = aws_db_parameter_group.main.name
  # ...
}

# IAM Role (si requiere permisos especiales)
resource "aws_iam_role" "enhanced_monitoring" {
  # Rol para Enhanced Monitoring
}
```

### Casos Específicos de Módulos

#### 1. Módulo ECS Service (Compute)

Un servicio de ECS NO es solo la tarea y el servicio. Incluye:

```
modules/compute/ecs-service/
├── main.tf
│   ├── Security Group del servicio
│   ├── Target Group (TG) para el ALB
│   ├── Listener Rule del ALB
│   ├── IAM Role para Task Execution (ECR, Secrets Manager, CloudWatch)
│   ├── IAM Role para Task (permisos de la aplicación)
│   ├── IAM Policies (para Secrets Manager, KMS, SSM)
│   ├── ECS Task Definition
│   ├── ECS Service
│   └── Application Auto Scaling (ASG)
│       ├── Target (asocia servicio con ASG)
│       ├── Policy de CPU
│       └── Policy de Memoria
```

**¿Por qué?**
- El **Security Group** controla el tráfico de red al servicio
- El **Target Group** permite que el ALB envíe tráfico
- El **Listener Rule** define el routing (path pattern)
- Los **IAM Roles** dan permisos para pull de imágenes, logs, secrets
- El **Auto Scaling** hace que el servicio sea resiliente

#### 2. Módulo RDS

Incluye:

```
modules/rds/
├── main.tf
│   ├── Security Group (quién puede conectarse)
│   ├── DB Subnet Group (dónde se despliega)
│   ├── DB Parameter Group (configuración de PostgreSQL)
│   ├── RDS Instance (recurso principal)
│   ├── Random Password (contraseña segura)
│   └── Read Replica (opcional)
```

#### 3. Módulo ALB

Incluye:

```
modules/alb/
├── main.tf
│   ├── Security Group (puertos 80, 443)
│   ├── Application Load Balancer
│   ├── HTTP Listener (redirect a HTTPS)
│   ├── HTTPS Listener (si está habilitado)
│   └── Asociación con WAF (opcional)
```

#### 4. Módulo de Compute (Orquestador)

Este módulo NO crea recursos directamente, sino que orquesta submódulos:

```terraform
# modules/compute/main.tf

module "ecr" {
  source = "./ecr"
  # crea repositorio ECR
}

module "ecs_service" {
  source = "./ecs-service"
  # crea servicio ECS + TG + ASG + SG + IAM
  container_image = module.ecr.repository_url
}
```

**¿Por qué separar ECR y ECS Service?**
- ECR se crea una vez y se reutiliza
- ECS Service se actualiza frecuentemente
- Permite mejor control de ciclo de vida

---

## Gestión de Ambientes

### Archivos por Ambiente

Cada ambiente tiene dos archivos:

1. **`.tfvars`** - Valores de variables específicas del ambiente
2. **`.tfbackend`** - Configuración del backend remoto

#### Ejemplo: `environments/qa.tfvars`

```terraform
# ========================================
# GENERAL
# ========================================
aws_region = "us-east-1"
prefix     = "myapp"  # Nombre corto de tu proyecto
env        = "qa"

# ========================================
# NETWORKING
# ========================================
vpc_cidr            = "192.168.0.0/16"
public_subnet_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
app_subnet_cidrs    = ["192.168.2.0/24", "192.168.3.0/24"]
data_subnet_cidrs   = ["192.168.4.0/24", "192.168.5.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]
enable_nat_gateway  = true

# ========================================
# COMPUTE
# ========================================
task_cpu    = 1024  # 1 vCPU
task_memory = 2048  # 2 GB
desired_count = 2
min_capacity  = 2
max_capacity  = 4

# ========================================
# SERVICIOS (ECS)
# ========================================
# Ejemplo para aplicación de microservicios
services = {
  backend = {
    listener_rule_priority = 100
    path_pattern           = "/api/*"
    container_port         = 3000
    health_check_path      = "/api/health"
    health_check_matcher   = "200"
    environment_variables = [
      { name = "NODE_ENV", value = "qa" },
      { name = "LOG_LEVEL", value = "info" }
    ]
  }
  
  # Añadir más servicios según necesites
  # worker = { ... }
  # websocket = { ... }
}

# ========================================
# DATABASE
# ========================================
enable_rds            = true
rds_instance_class    = "db.t4g.micro"
rds_allocated_storage = 20
enable_read_replica   = false

# ========================================
# FEATURE FLAGS
# ========================================
enable_bastion       = true
enable_cloudtrail    = false
enable_waf_alb       = false
enable_frontend      = true
```

#### Ejemplo: `environments/qa.tfbackend`

```hcl
bucket  = "terraform-state-mycompany-123456"  # Nombre único global
key     = "myapp/qa/terraform.tfstate"        # Ruta: proyecto/ambiente/state
region  = "us-east-1"
encrypt = true
```

### Uso de Ambientes

```bash
# Inicializar con backend específico
terraform init -backend-config=environments/qa.tfbackend

# Plan con variables del ambiente
terraform plan -var-file=environments/qa.tfvars

# Apply
terraform apply -var-file=environments/qa.tfvars

# Para cambiar de ambiente, re-inicializar
terraform init -reconfigure -backend-config=environments/prod.tfbackendterraform plan -var-file=environments/prod.tfvars
```

---

## Paso a Paso: Iniciando un Proyecto

### Fase 1: Preparación (Día 1)

#### 1.1. Crear Estructura de Directorios

```bash
mkdir mi-proyecto-infra
cd mi-proyecto-infra

# Crear directorios principales
mkdir -p environments modules docs

# Crear archivos raíz
touch config.tf main.tf variables.tf outputs.tf README.md
```

#### 1.2. Configurar Backend S3

Crear bucket de Terraform state (hacer esto manualmente o con un script):

```bash
# Crear bucket S3 (usar nombre único global)
aws s3 mb s3://terraform-state-mycompany-$(date +%s) --region us-east-1

# Guardar el nombre del bucket
BUCKET_NAME="terraform-state-mycompany-123456"  # Reemplazar con el bucket creado

# Habilitar versionamiento
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Habilitar encriptación
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Bloquear acceso público
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**Nota**: Este proyecto usa **lockfile en S3** en lugar de DynamoDB para el state locking, aprovechando la funcionalidad nativa de S3.

#### 1.3. Configurar `config.tf`

```terraform
terraform {
  required_version = ">= 1.13.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.19.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

#### 1.4. Crear Primer Ambiente

```bash
# environments/dev.tfvars
cat > environments/dev.tfvars << 'EOF'
aws_region = "us-east-1"
prefix     = "miapp"
env        = "dev"
EOF

# environments/dev.tfbackend
cat > environments/dev.tfbackend << 'EOF'
bucket  = "terraform-state-mycompany-123456"  # Usar el bucket creado
key     = "myapp/dev/terraform.tfstate"       # proyecto/ambiente/state
region  = "us-east-1"
encrypt = true
EOF
```

---

### Fase 2: Módulo de Networking (Días 2-3)

#### 2.1. Crear Módulo VPC

```bash
mkdir -p modules/vpc
touch modules/vpc/{main.tf,variables.tf,outputs.tf,README.md}
```

#### 2.2. `modules/vpc/variables.tf`

```terraform
variable "prefix" {
  description = "Prefijo para nombres de recursos"
  type        = string
}

variable "env" {
  description = "Ambiente (dev, qa, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block para VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDRs para subnets públicas"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "CIDRs para subnets de aplicación"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "CIDRs para subnets de datos"
  type        = list(string)
}

variable "availability_zones" {
  description = "AZs para las subnets"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Habilitar NAT Gateway"
  type        = bool
  default     = true
}
```

#### 2.3. `modules/vpc/main.tf`

```terraform
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.prefix}-${var.env}-vpc"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-${var.env}-igw"
    Environment = var.env
  }
}

# Subnets Públicas
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.prefix}-${var.env}-public-subnet-${count.index + 1}"
    Environment = var.env
    Tier        = "Public"
  }
}

# Subnets de Aplicación (privadas)
resource "aws_subnet" "app" {
  count             = length(var.app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.prefix}-${var.env}-app-subnet-${count.index + 1}"
    Environment = var.env
    Tier        = "Application"
  }
}

# Subnets de Datos (privadas)
resource "aws_subnet" "data" {
  count             = length(var.data_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.prefix}-${var.env}-data-subnet-${count.index + 1}"
    Environment = var.env
    Tier        = "Data"
  }
}

# NAT Gateway (opcional)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.prefix}-${var.env}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.prefix}-${var.env}-nat"
  }
}

# Route Table - Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.prefix}-${var.env}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table - Private (App & Data)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = {
    Name = "${var.prefix}-${var.env}-private-rt"
  }
}

resource "aws_route_table_association" "app" {
  count          = length(var.app_subnet_cidrs)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data" {
  count          = length(var.data_subnet_cidrs)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.private.id
}
```

#### 2.4. `modules/vpc/outputs.tf`

```terraform
output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR de la VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de subnets públicas"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "IDs de subnets de aplicación"
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "IDs de subnets de datos"
  value       = aws_subnet.data[*].id
}

output "nat_gateway_ip" {
  description = "IP pública del NAT Gateway"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}
```

#### 2.5. Actualizar Root Module

**`variables.tf`** (añadir):

```terraform
variable "aws_region" {
  description = "Región de AWS"
  type        = string
}

variable "prefix" {
  description = "Prefijo para recursos"
  type        = string
}

variable "env" {
  description = "Ambiente"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "app_subnet_cidrs" {
  type = list(string)
}

variable "data_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}
```

**`main.tf`** (añadir):

```terraform
module "vpc" {
  source = "./modules/vpc"

  prefix                = var.prefix
  env                   = var.env
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  app_subnet_cidrs      = var.app_subnet_cidrs
  data_subnet_cidrs     = var.data_subnet_cidrs
  availability_zones    = var.availability_zones
  enable_nat_gateway    = var.enable_nat_gateway
}
```

**`outputs.tf`** (añadir):

```terraform
output "vpc_id" {
  value = module.vpc.vpc_id
}
```

#### 2.6. Actualizar tfvars

**`environments/dev.tfvars`** (añadir):

```terraform
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24"]
app_subnet_cidrs    = ["10.0.2.0/24", "10.0.3.0/24"]
data_subnet_cidrs   = ["10.0.4.0/24", "10.0.5.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]
enable_nat_gateway  = true
```

#### 2.7. Primer Deployment

```bash
# Inicializar
terraform init -backend-config=environments/dev.tfbackend

# Validar
terraform validate

# Plan
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars
```

---

### Fase 3: Módulo de Compute ECS (Días 4-6)

#### 3.1. Crear Estructura

```bash
mkdir -p modules/ecs-cluster
mkdir -p modules/compute/ecr
mkdir -p modules/compute/ecs-service
touch modules/ecs-cluster/{main.tf,variables.tf,outputs.tf}
touch modules/compute/{main.tf,variables.tf,outputs.tf}
touch modules/compute/ecr/{main.tf,variables.tf,outputs.tf}
touch modules/compute/ecs-service/{main.tf,variables.tf,outputs.tf,README.md}
```

#### 3.2. Módulo ECS Cluster

**`modules/ecs-cluster/main.tf`**:

```terraform
resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-${var.env}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-cluster"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.prefix}-${var.env}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}
```

**`modules/ecs-cluster/variables.tf`**:

```terraform
variable "prefix" {
  type = string
}

variable "env" {
  type = string
}

variable "enable_container_insights" {
  type    = bool
  default = true
}

variable "log_retention_days" {
  type    = number
  default = 7
}
```

**`modules/ecs-cluster/outputs.tf`**:

```terraform
output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs.name
}
```

#### 3.3. Módulo ECR

**`modules/compute/ecr/main.tf`**:

```terraform
resource "aws_ecr_repository" "main" {
  name                 = "${var.prefix}-${var.env}-${var.service_name}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${var.service_name}"
    Service     = var.service_name
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.max_image_count} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.max_image_count
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

**`modules/compute/ecr/variables.tf`**:

```terraform
variable "prefix" {
  type = string
}

variable "env" {
  type = string
}

variable "service_name" {
  type = string
}

variable "image_tag_mutability" {
  type    = string
  default = "MUTABLE"
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "max_image_count" {
  type    = number
  default = 10
}
```

**`modules/compute/ecr/outputs.tf`**:

```terraform
output "repository_url" {
  value = aws_ecr_repository.main.repository_url
}

output "repository_arn" {
  value = aws_ecr_repository.main.arn
}

output "repository_name" {
  value = aws_ecr_repository.main.name
}
```

#### 3.4. Módulo ECS Service (Completo con TG, ASG, IAM)

Este es el módulo más complejo. Ver archivo completo en la sección de **Ejemplos Prácticos** más abajo.

#### 3.5. Módulo Compute (Orquestador)

**`modules/compute/main.tf`**:

```terraform
module "ecr" {
  source = "./ecr"

  prefix               = var.prefix
  env                  = var.env
  service_name         = var.service_name
  image_tag_mutability = var.image_tag_mutability
  scan_on_push         = var.scan_on_push
  max_image_count      = var.max_image_count
}

module "ecs_service" {
  source = "./ecs-service"

  prefix                = var.prefix
  env                   = var.env
  service_name          = var.service_name
  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  cluster_id            = var.cluster_id
  cluster_name          = var.cluster_name
  listener_arn          = var.listener_arn
  listener_rule_priority = var.listener_rule_priority
  path_pattern          = var.path_pattern
  container_port        = var.container_port
  container_image       = module.ecr.repository_url
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  desired_count         = var.desired_count
  min_capacity          = var.min_capacity
  max_capacity          = var.max_capacity
  health_check_path     = var.health_check_path
  environment_variables = var.environment_variables
  log_group_name        = var.log_group_name

  depends_on = [module.ecr]
}
```

---

## Patrones y Mejores Prácticas

### 1. Naming Conventions

```terraform
# Patrón: {prefix}-{env}-{resource}-{descriptor}

# Ejemplos:
# VPC: myapp-qa-vpc
# Subnet: myapp-qa-app-subnet-1
# Security Group: myapp-qa-backend-sg
# ECS Service: myapp-qa-backend-service
# Target Group: myapp-qa-backend-tg
# IAM Role: myapp-qa-backend-task-execution
# RDS Instance: myapp-prod-postgres
# ElastiCache: myapp-prod-redis-cluster
# S3 Bucket: myapp-prod-uploads-bucket
# Lambda Function: myapp-dev-processor-lambda
```

### 2. Tagging Strategy

```terraform
tags = {
  Name        = "${var.prefix}-${var.env}-${var.resource_type}"
  Environment = var.env
  Service     = var.service_name  # Para recursos específicos de servicio
  ManagedBy   = "Terraform"
  CostCenter  = var.cost_center   # Opcional
  Owner       = var.owner         # Opcional
}
```

### 3. Variables Validation

```terraform
variable "env" {
  description = "Environment"
  type        = string
  
  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "Environment must be dev, qa, or prod"
  }
}

variable "task_cpu" {
  description = "CPU units for Fargate task"
  type        = number
  
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "CPU must be a valid Fargate value"
  }
}
```

### 4. Security Defaults

```terraform
# Siempre habilitar encriptación
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn
  # ...
}

# Siempre habilitar HTTPS donde sea posible
resource "aws_lb_listener" "http" {
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Principles of Least Privilege en IAM
resource "aws_iam_role_policy" "specific" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]  # Solo lo necesario
      Resource = "arn:aws:s3:::specific-bucket/*"  # Scope limitado
    }]
  })
}
```

### 5. Feature Flags

```terraform
# Usa count para recursos opcionales
module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "./modules/bastion"
  # ...
}

# Accede con [0] y valida existencia
output "bastion_ip" {
  value = var.enable_bastion ? module.bastion[0].public_ip : null
}

# Dynamic blocks para configuración condicional
dynamic "ingress" {
  for_each = var.enable_bastion ? [1] : []
  content {
    description     = "From Bastion"
    security_groups = [var.bastion_sg_id]
    # ...
  }
}
```

### 6. Depends_on Explícito

```terraform
# Usa depends_on cuando Terraform no puede inferir dependencias
module "vpc" {
  source              = "./modules/vpc"
  flow_logs_bucket_arn = module.logs_bucket.bucket_arn
  
  depends_on = [module.logs_bucket]  # Asegura que bucket existe primero
}
```

### 7. Outputs Sensibles

```terraform
output "db_password" {
  description = "Database password"
  value       = aws_db_instance.main.password
  sensitive   = true  # No se muestra en logs
}
```

### 8. Lifecycle Rules

```terraform
resource "random_password" "db" {
  length  = 32
  
  lifecycle {
    ignore_changes = [length, special]  # No recrear en cambios menores
  }
}

resource "aws_instance" "main" {
  # ...
  
  lifecycle {
    create_before_destroy = true  # Para zero-downtime updates
  }
}
```

---

## Ejemplos Prácticos de Módulos

### Ejemplo Completo: Módulo ECS Service

**`modules/compute/ecs-service/main.tf`** (versión completa):

```terraform
# ========================================
# SECURITY GROUP
# ========================================
resource "aws_security_group" "ecs_service" {
  name        = "${var.prefix}-${var.env}-${var.service_name}-sg"
  description = "Security group for ECS service ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${var.service_name}-sg"
    Service     = var.service_name
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ========================================
# TARGET GROUP
# ========================================
resource "aws_lb_target_group" "main" {
  name                 = "${var.prefix}-${var.env}-${var.service_name}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = var.health_check_matcher
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${var.service_name}-tg"
    Service     = var.service_name
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ========================================
# ALB LISTENER RULE
# ========================================
resource "aws_lb_listener_rule" "main" {
  listener_arn = var.listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern {
      values = [var.path_pattern]
    }
  }
}

# ========================================
# IAM ROLE - TASK EXECUTION
# ========================================
resource "aws_iam_role" "task_execution" {
  name = "${var.prefix}-${var.env}-${var.service_name}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name    = "${var.prefix}-${var.env}-${var.service_name}-task-execution"
    Service = var.service_name
  }
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Policy para Secrets Manager
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.prefix}-${var.env}-${var.service_name}-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}

# ========================================
# IAM ROLE - TASK
# ========================================
resource "aws_iam_role" "task" {
  name = "${var.prefix}-${var.env}-${var.service_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name    = "${var.prefix}-${var.env}-${var.service_name}-task"
    Service = var.service_name
  }
}

# Policy para SSM (Session Manager)
resource "aws_iam_role_policy" "ssm_access" {
  name = "${var.prefix}-${var.env}-${var.service_name}-ssm"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel"
      ]
      Resource = "*"
    }]
  })
}

# ========================================
# ECS TASK DEFINITION
# ========================================
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.prefix}-${var.env}-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = var.service_name
    image     = "${var.container_image}:latest"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = var.environment_variables

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = var.service_name
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  runtime_platform {
    cpu_architecture        = var.cpu_architecture
    operating_system_family = "LINUX"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-${var.service_name}-task"
    Service     = var.service_name
    Environment = var.env
  }
}

# ========================================
# ECS SERVICE
# ========================================
resource "aws_ecs_service" "main" {
  name            = "${var.prefix}-${var.env}-${var.service_name}-service"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  enable_execute_command = true

  tags = {
    Name        = "${var.prefix}-${var.env}-${var.service_name}-service"
    Service     = var.service_name
    Environment = var.env
  }

  depends_on = [aws_lb_listener_rule.main]
}

# ========================================
# AUTO SCALING
# ========================================
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.prefix}-${var.env}-${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.prefix}-${var.env}-${var.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

**`modules/compute/ecs-service/variables.tf`**:

```terraform
variable "prefix" { type = string }
variable "env" { type = string }
variable "service_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "cluster_id" { type = string }
variable "cluster_name" { type = string }
variable "alb_security_group_id" { type = string }
variable "listener_arn" { type = string }
variable "listener_rule_priority" { type = number }
variable "path_pattern" { type = string }
variable "container_port" { type = number }
variable "container_image" { type = string }
variable "task_cpu" { type = number }
variable "task_memory" { type = number }
variable "desired_count" { type = number }
variable "min_capacity" { type = number }
variable "max_capacity" { type = number }
variable "cpu_target_value" { type = number }
variable "memory_target_value" { type = number }
variable "health_check_path" { type = string }
variable "health_check_matcher" { type = string }
variable "log_group_name" { type = string }
variable "aws_region" { type = string }
variable "cpu_architecture" { type = string }

variable "environment_variables" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
```

**`modules/compute/ecs-service/outputs.tf`**:

```terraform
output "service_name" {
  value = aws_ecs_service.main.name
}

output "service_arn" {
  value = aws_ecs_service.main.id
}

output "security_group_id" {
  value = aws_security_group.ecs_service.id
}

output "target_group_arn" {
  value = aws_lb_target_group.main.arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.main.arn
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
```

**`modules/compute/ecs-service/README.md`**:

```markdown
# ECS Service Module

## Descripción

Módulo completo para desplegar un servicio ECS Fargate con todos sus componentes:

- **Security Group**: Controla acceso de red al servicio
- **Target Group**: Permite registro en ALB
- **Listener Rule**: Define routing basado en path
- **IAM Roles**: Task Execution (pull images, logs) y Task (app permissions)
- **Task Definition**: Define contenedor, recursos, variables de entorno
- **ECS Service**: Orquesta las tareas
- **Auto Scaling**: Escala basado en CPU y memoria

## Uso

```terraform
module "api_service" {
  source = "./modules/compute/ecs-service"

  prefix         = "myapp"
  env            = "qa"
  service_name   = "api"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.app_subnet_ids
  cluster_id     = module.ecs_cluster.cluster_id
  cluster_name   = module.ecs_cluster.cluster_name
  listener_arn   = module.alb.https_listener_arn
  
  listener_rule_priority = 100
  path_pattern          = "/api/*"
  container_port        = 3000
  health_check_path     = "/api/health"
  
  task_cpu      = 1024
  task_memory   = 2048
  desired_count = 2
  min_capacity  = 2
  max_capacity  = 10
}
```

## Inputs

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `service_name` | string | Nombre del servicio |
| `container_port` | number | Puerto expuesto por el contenedor |
| `path_pattern` | string | Patrón de path para routing (ej: `/api/*`) |
| `task_cpu` | number | CPU units (256, 512, 1024, 2048, 4096) |
| `task_memory` | number | Memoria en MB |
| `min_capacity` | number | Mínimo de tareas para auto-scaling |
| `max_capacity` | number | Máximo de tareas para auto-scaling |

## Outputs

| Output | Descripción |
|--------|-------------|
| `service_arn` | ARN del servicio ECS |
| `security_group_id` | ID del security group |
| `target_group_arn` | ARN del target group |
| `task_execution_role_arn` | ARN del rol de ejecución |

## Notas

- El módulo crea automáticamente políticas IAM para acceder a Secrets Manager y KMS
- El auto-scaling se basa en CPU (70%) y Memoria (80%) por defecto
- Habilita ECS Exec para debugging con Session Manager
```

---

## Recomendaciones Finales

### ✅ DO's

1. **Modulariza desde el inicio**: No esperes a tener código duplicado
2. **Documenta cada módulo**: README.md con ejemplos de uso
3. **Usa remote state desde día 1**: Evita problemas de sincronización
4. **Versiona los providers**: Fija versiones específicas
5. **Implementa naming conventions consistentes**: Facilita búsqueda y troubleshooting
6. **Usa feature flags**: Permite habilitar/deshabilitar componentes fácilmente
7. **Valida variables**: Usa validation blocks para detectar errores temprano
8. **Separa por ambientes**: tfvars y tfbackend específicos
9. **Marca outputs sensibles**: No expongas credenciales en logs
10. **Usa depends_on cuando sea necesario**: Asegura orden correcto de creación

### ❌ DON'Ts

1. **No hardcodees valores**: Usa variables
2. **No mezcles ambientes**: Nunca uses dev.tfvars con prod.tfbackend
3. **No ignores el state**: Nunca edites el .tfstate manualmente
4. **No uses inline policies si puedes usar managed**: Reutiliza políticas AWS
5. **No crees módulos parciales**: Incluye todos los componentes relacionados
6. **No uses `latest` en imágenes**: Fija tags específicos en producción
7. **No omitas tags**: Son cruciales para cost tracking y governance
8. **No despliegues a producción sin plan**: Siempre revisa cambios primero
9. **No olvides lifecycle rules**: Previene recreación innecesaria de recursos
10. **No uses default VPC**: Crea VPCs dedicadas con subnetting apropiado

---

## Recursos Adicionales

### Templates de Archivos

#### `.gitignore` para Terraform

```gitignore
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files (uncomment if you want to version them)
# *.tfvars
# *.tfvars.json

# Ignore override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore Mac .DS_Store files
.DS_Store

# Ignore IDE specific files
.idea/
.vscode/
*.swp
*.swo
*~

# Ignore any private key files
*.pem
*.key
```

#### Estructura de README.md Principal

```markdown
# Proyecto Infrastructure

## Descripción
Breve descripción del proyecto y su propósito.

## Arquitectura
Diagrama o descripción de componentes principales.

## Prerequisites
- Terraform >= 1.13
- AWS CLI configurado
- Credenciales AWS con permisos adecuados
- Acceso a cuenta AWS

## Quick Start

### 1. Setup Backend
\`\`\`bash
# Crear S3 bucket para Terraform State
./scripts/setup-backend.sh
\`\`\`

### 2. Deploy
\`\`\`bash
# Inicializar
terraform init -backend-config=environments/dev.tfbackend

# Plan
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars
\`\`\`

## Modules
- **vpc**: Networking infrastructure
- **compute**: ECS cluster and services
- **database**: RDS PostgreSQL
- **security**: KMS, Secrets, WAF

## Environments
- **dev**: Development environment
- **qa**: QA/Staging environment
- **prod**: Production environment

## Documentation
- [Architecture](docs/ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## License
MIT
```

---

## Conclusión

Esta guía te ha llevado paso a paso por la creación de una infraestructura de Terraform profesional y escalable. Los principios fundamentales son:

1. **Modularidad**: Divide tu código en módulos reutilizables
2. **Autocontención**: Cada módulo incluye todos sus componentes (recursos, permisos, políticas)
3. **Separación de ambientes**: Configuración específica por tfvars
4. **Documentación**: README en cada módulo
5. **Best practices**: Security, naming, tagging, validation

Recuerda que un módulo bien diseñado no solo crea el recurso principal, sino también:
- **Security Groups**: Control de acceso de red
- **IAM Roles y Policies**: Permisos necesarios para operar
- **Recursos complementarios**: Target Groups, Auto Scaling Groups, Parameter Groups, Subnet Groups, etc.
- **Configuraciones de logging**: CloudWatch Logs, S3 logging
- **Monitoring y alertas**: CloudWatch Alarms, métricas personalizadas
- **Mecanismos de scaling**: Auto Scaling, Read Replicas
- **Backup y recuperación**: Snapshots, Point-in-time recovery

### Aplicabilidad Universal

Esta metodología funciona para diversos tipos de proyectos:
- **Aplicaciones web**: Frontend (S3+CloudFront), Backend (ECS/EKS), Bases de datos
- **APIs**: API Gateway, Lambda, DynamoDB
- **Data pipelines**: Glue, EMR, Kinesis, Redshift
- **Machine Learning**: SageMaker, S3 Data Lakes
- **Aplicaciones serverless**: Lambda, Step Functions, EventBridge
- **Aplicaciones tradicionales**: EC2, RDS, ElastiCache

Con esta estructura, tu infraestructura será:
- **Mantenible**: Fácil de entender y modificar
- **Reutilizable**: Módulos que funcionan en múltiples proyectos
- **Escalable**: Añade nuevos servicios sin refactorizar
- **Segura**: Principios de seguridad desde el diseño
- **Profesional**: Estándares de la industria
- **Adaptable**: Se ajusta a diferentes tipos de arquitecturas

¡Feliz infraestructura como código! 🚀
