# Compute Module

Manages ECS Fargate services, container registry, and ECS cluster for microservices deployment.

## Purpose

Provides containerized application hosting with auto-scaling, service discovery, and ALB integration.

## Structure

```
compute/
├── main.tf              # Service orchestration
├── variables.tf         # Module variables
├── outputs.tf          # Module outputs
├── ecr/                # Container registry submodule
├── ecs-cluster/        # ECS cluster submodule
└── ecs-service/        # ECS service submodule
```

## Resources Created Per Service

- ECR repository for container images
- ECS task definition
- ECS service
- Target group for ALB
- Security group for tasks
- Auto-scaling target and policies
- IAM roles (task and execution)
- CloudWatch log group

## Usage

```hcl
module "compute" {
  for_each = var.services
  source   = "./modules/compute"

  prefix             = var.prefix
  env                = var.env
  service_name       = each.key
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.app_subnet_ids
  cluster_id         = module.ecs_cluster.cluster_id
  cluster_name       = module.ecs_cluster.cluster_name
  alb_listener_arn   = module.alb.http_listener_arn
  alb_security_group_id = module.alb.alb_security_group_id
  
  # Service configuration
  container_port         = each.value.container_port
  health_check_path      = each.value.health_check_path
  listener_rule_priority = each.value.listener_rule_priority
  path_pattern           = each.value.path_pattern
  
  # Task configuration
  task_cpu               = var.task_cpu
  task_memory            = var.task_memory
  ephemeral_storage_size = var.ephemeral_storage_size
  cpu_architecture       = var.cpu_architecture
  
  # Auto-scaling
  desired_count       = var.desired_count
  min_capacity        = var.min_capacity
  max_capacity        = var.max_capacity
  cpu_target_value    = var.cpu_target_value
  memory_target_value = var.memory_target_value
}
```

## Service Definition

Services are defined in `qa.tfvars`:

```hcl
services = {
  api = {
    listener_rule_priority = 100
    path_pattern           = "/api/*"
    container_port         = 3000
    health_check_path      = "/api/health"
    health_check_matcher   = "200"
    environment_variables = [
      { name = "NODE_ENV", value = "production" },
      { name = "PORT", value = "3000" }
    ]
  }
  admin = {
    listener_rule_priority = 200
    path_pattern           = "/admin/*"
    container_port         = 8080
    health_check_path      = "/admin/health"
    health_check_matcher   = "200"
    environment_variables = [
      { name = "ADMIN_MODE", value = "true" }
    ]
  }
}
```

## Task Configuration

### CPU and Memory

Fargate requires specific CPU/memory combinations:

| CPU (vCPU) | Memory (GB) Options |
|------------|---------------------|
| 256 (0.25) | 0.5, 1, 2 |
| 512 (0.5) | 1, 2, 3, 4 |
| 1024 (1) | 2, 3, 4, 5, 6, 7, 8 |
| 2048 (2) | 4-16 (1 GB increments) |
| 4096 (4) | 8-30 (1 GB increments) |

### Architecture

- **ARM64**: Use Graviton2 processors (20% cost savings)
- **X86_64**: Standard x86 processors

Ensure Docker images are built for correct architecture.

### Ephemeral Storage

- **Minimum**: 21 GB
- **Maximum**: 200 GB
- **Default**: 21 GB (included in task cost)
- **Additional cost**: $0.000111/GB/hour beyond 20 GB

## Auto-Scaling

Two scaling policies per service:

### CPU-Based Scaling

```hcl
cpu_target_value = 75.0  # Scale when CPU > 75%
```

### Memory-Based Scaling

```hcl
memory_target_value = 75.0  # Scale when memory > 75%
```

Scaling behavior:
- **Scale-out**: 30-second cooldown
- **Scale-in**: 300-second cooldown (prevents thrashing)
- Adds/removes tasks to maintain target utilization

## ECR Repository

### Image Lifecycle

Configured to retain last 10 images:
- Older images automatically deleted
- Tagged images preserved
- Reduces storage costs

### Image Scanning

Enabled by default on push:
- Scans for CVE vulnerabilities
- Results visible in ECR console
- Blocks deployment if critical issues (manual process)

### Image Tagging

Recommended strategy:
```bash
docker tag app:latest <account>.dkr.ecr.us-east-1.amazonaws.com/ecommerce-qa-api:${GIT_SHA}
docker tag app:latest <account>.dkr.ecr.us-east-1.amazonaws.com/ecommerce-qa-api:latest
```

Latest tag for easy rollback, SHA for version tracking.

## Networking

### Security Group Rules

**Ingress**:
- Container port from ALB security group only

**Egress**:
- Port 5432 to RDS security group
- Port 6379 to ElastiCache security group
- Port 443 for HTTPS (AWS APIs, external services)
- Port 80 for HTTP (package downloads)

### Service Discovery

Not implemented. Services communicate via:
- ALB for HTTP/HTTPS
- Direct endpoints for RDS/ElastiCache

## Secrets and Configuration

### Environment Variables

Passed directly in task definition:

```hcl
environment_variables = [
  { name = "NODE_ENV", value = "production" }
]
```

### Secrets from Secrets Manager

Referenced in task definition:

```json
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:region:account:secret:rds-password"
    }
  ]
}
```

Task execution role has permission to read secrets.

## Logging

CloudWatch Logs configuration:
- **Log group**: `/ecs/<prefix>-<env>-<service>`
- **Retention**: Configurable (default 7 days)
- **Stream prefix**: `ecs`

View logs:

```bash
aws logs tail /ecs/ecommerce-qa-api --follow
```

## Deployment

### Via CI/CD (Recommended)

GitHub Actions workflow automatically:
1. Builds Docker image
2. Pushes to ECR
3. Updates task definition
4. Triggers ECS deployment

### Manual Deployment

```bash
# Build and push image
docker build -t ecommerce-api:latest .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
docker tag ecommerce-api:latest <account>.dkr.ecr.us-east-1.amazonaws.com/ecommerce-qa-api:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/ecommerce-qa-api:latest

# Force new deployment
aws ecs update-service --cluster ecommerce-qa-cluster --service ecommerce-qa-api --force-new-deployment
```

## Monitoring

### Service Metrics

- **CPUUtilization**: Task CPU usage
- **MemoryUtilization**: Task memory usage
- **RunningTaskCount**: Active tasks
- **DesiredTaskCount**: Target task count

### ALB Target Metrics

- **HealthyHostCount**: Healthy targets
- **UnHealthyHostCount**: Unhealthy targets
- **TargetResponseTime**: Average response time

## Troubleshooting

### Tasks Not Starting

Check CloudWatch Logs for:
- Image pull errors (ECR permissions)
- Application startup errors
- Health check failures

### Health Check Failures

Verify:
1. Container exposes correct port
2. Health check endpoint returns 200
3. Health check path is correct
4. Application starts within timeout

### Tasks Stop Unexpectedly

Check:
- Out of memory (OOM)
- Application crashes in logs
- Failed health checks

## Maintenance

### Update Task Resources

Modify in `qa.tfvars`:

```hcl
task_cpu    = 2048
task_memory = 4096
```

Apply changes:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### Add New Service

Add to `services` map in `qa.tfvars`:

```hcl
services = {
  api = { ... }
  newservice = {
    listener_rule_priority = 300
    path_pattern           = "/newservice/*"
    container_port         = 8080
    health_check_path      = "/health"
    health_check_matcher   = "200"
    environment_variables  = []
  }
}
```

### Scale Services

Modify auto-scaling parameters:

```hcl
min_capacity = 4
max_capacity = 10
```

Or manually set desired count:

```bash
aws ecs update-service --cluster ecommerce-qa-cluster --service ecommerce-qa-api --desired-count 5
```

## Cost

Per service (1 vCPU, 2 GB RAM, ARM64):
- **Fargate**: $0.03238/hour per task
- **2 tasks**: $47/month
- **Storage**: 21 GB included, $0.011/month per additional GB

## Dependencies

- VPC module (application subnets)
- ECS Cluster module
- ALB module (listener and security group)
- KMS module (log encryption)
- Secrets Manager module (credentials)

## Used By

- CloudWatch Alarms module (service monitoring)
- CI/CD module (deployment permissions)
