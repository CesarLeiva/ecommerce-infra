# E-Commerce Infrastructure

Production-grade AWS infrastructure for e-commerce platform using Terraform. Includes networking, compute, database, caching, security, monitoring, and CI/CD.

## Architecture Overview

This infrastructure deploys a complete microservices-based e-commerce platform on AWS with the following components:

- **Networking**: VPC with public, application, and data subnets across multiple AZs
- **Compute**: ECS Fargate with auto-scaling, ECR for container images
- **Load Balancing**: Application Load Balancer with WAF protection
- **Database**: RDS PostgreSQL with optional read replica
- **Caching**: ElastiCache Redis for session management and caching
- **Frontend**: S3 + CloudFront CDN for static website hosting
- **Storage**: S3 buckets for application logs and backups
- **Security**: KMS encryption, Secrets Manager, WAF, CloudTrail
- **Monitoring**: CloudWatch alarms for services, database, and security events
- **Cost Management**: AWS Budgets with configurable alert thresholds
- **CI/CD**: GitHub Actions OIDC integration for automated deployments

## Project Structure

```
ecommerce-infra/
├── main.tf                 # Root module orchestration
├── variables.tf            # Root variable definitions
├── outputs.tf              # Root outputs
├── config.tf               # Provider and backend configuration
├── environments/
│   ├── qa.tfvars         # Production environment variables
│   └── qa.tfbackend      # Remote state backend configuration
├── modules/
│   ├── alb/               # Application Load Balancer
│   ├── bastion/           # Bastion host for secure access
│   ├── budgets/           # AWS Budgets cost alerts
│   ├── cicd/              # GitHub Actions OIDC
│   ├── cloudtrail/        # AWS CloudTrail audit logging
│   ├── cloudwatch-alarms/ # Monitoring and alerting
│   ├── compute/           # ECS cluster, services, ECR
│   ├── elasticache/       # Redis cluster
│   ├── frontend/          # S3 + CloudFront for static site
│   ├── kms/               # KMS encryption keys
│   ├── logs-bucket/       # Centralized S3 logging
│   ├── rds/               # RDS PostgreSQL database
│   ├── route53/           # DNS records
│   ├── secrets/           # Secrets Manager
│   ├── vpc/               # Virtual Private Cloud
│   └── waf/               # Web Application Firewall
└── .github/workflows/     # CI/CD workflow templates
```

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with sufficient permissions
- Domain name (optional, for HTTPS)
- GitHub repository (for CI/CD)

## Quick Start

### 1. Configure Backend

Edit `environments/qa.tfbackend` with your S3 bucket for remote state:

```hcl
bucket       = "your-terraform-state-bucket"
key          = "qa/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

### 2. Configure Environment

Edit `environments/qa.tfvars` with your specific values:

```hcl
# Update these critical values
domain_name          = "yourdomain.com"
subject_alternative_names = ["*.yourdomain.com"]
route53_zone_id      = "Z1234567890ABC"  # Your Route53 hosted zone
budget_alert_emails  = ["your-email@example.com"]
alarm_emails         = ["your-email@example.com"]
github_repositories  = ["yourorg/backend", "yourorg/frontend"]
```

### 3. Initialize Terraform or Reconfigure Backend

```bash
terraform init -backend-config="environments/qa.tfbackend" # First time only
# Or
terraform init -reconfigure -backend-config="environments/qa.tfbackend" # On environment changes
```

### 4. Validate Configuration

```bash
terraform validate
terraform fmt -recursive
```

### 5. Plan Deployment

```bash
terraform plan -var-file="environments/qa.tfvars"
```

### 6. Deploy Infrastructure

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### 7. Retrieve Outputs

```bash
terraform output
```

Critical outputs:
- `alb_dns_name`: Load balancer endpoint
- `frontend_url`: CloudFront distribution URL
- `github_actions_role_arn`: IAM role ARN for CI/CD
- `bastion_public_ip`: SSH access point

## Cost Estimation

Estimated monthly cost: **~$556 USD**

Breakdown:
- Database (RDS): $282 (51%) - on-demand single instance
- Networking (NAT Gateway): $82 (15%)
- Compute (ECS Fargate): $76 (14%)
- Security (WAF, Secrets): $53 (10%)
- Monitoring (CloudWatch): $37 (7%)
- Storage (S3, CloudFront): $36 (6%)
- Load Balancing: $28 (5%)

See [COST_ESTIMATION.md](docs/COST_ESTIMATION.md) for detailed breakdown.

## Module Documentation

Each module contains its own README.md with detailed documentation:

- [ALB](modules/alb/README.md) - Application Load Balancer configuration
- [Bastion](modules/bastion/README.md) - Secure SSH access host
- [Budgets](modules/budgets/README.md) - Cost monitoring and alerts
- [CI/CD](modules/cicd/README.md) - GitHub Actions integration
- [CloudTrail](modules/cloudtrail/README.md) - Audit logging
- [CloudWatch Alarms](modules/cloudwatch-alarms/README.md) - Monitoring
- [Compute](modules/compute/README.md) - ECS services and container registry
- [ElastiCache](modules/elasticache/README.md) - Redis cluster
- [Frontend](modules/frontend/README.md) - S3 + CloudFront static site
- [KMS](modules/kms/README.md) - Encryption key management
- [Logs Bucket](modules/logs-bucket/README.md) - Centralized logging
- [RDS](modules/rds/README.md) - RDS PostgreSQL database
- [Route53](modules/route53/README.md) - DNS management
- [Secrets Manager](modules/secrets/README.md) - Credentials storage
- [VPC](modules/vpc/README.md) - Network infrastructure
- [WAF](modules/waf/README.md) - Web application firewall

## CI/CD Setup

See `CICD_SETUP.md` for complete GitHub Actions configuration guide.

Summary:
1. Deploy infrastructure with `enable_cicd = true`
2. Retrieve `github_actions_role_arn` from outputs
3. Configure `AWS_ROLE_ARN` secret in GitHub repositories
4. Copy workflow files from `.github/workflows/` to your repositories
5. Push to main branch triggers automatic deployment

## Security Features

- **Encryption at Rest**: KMS encryption for RDS, ElastiCache, S3, EBS volumes
- **Encryption in Transit**: TLS 1.3 for ALB, optional for ElastiCache
- **Secrets Management**: Database and Redis credentials in Secrets Manager
- **Network Security**: Private subnets for application and data tiers
- **WAF Protection**: OWASP Top 10 rules, rate limiting, geo-blocking
- **Audit Logging**: CloudTrail for API activity (optional)
- **VPC Flow Logs**: Network traffic analysis
- **IMDSv2**: Required for EC2 metadata access

## Monitoring and Alerts

### CloudWatch Alarms

- **ECS Services**: CPU, memory, running task count
- **ALB**: Unhealthy targets, response time
- **RDS**: CPU, connections, memory, replica lag
- **WAF**: Blocked requests, attack detection

### Budget Alerts

Configurable thresholds (default: 50%, 80%, 100%, 150%, 200%) for:
- Overall spending
- Database costs
- Compute costs
- Storage costs

## Maintenance

### Update Task Definitions

After deploying new container images:

```bash
# Via CI/CD (automatic)
git push origin main

# Manual update
aws ecs update-service --cluster ecommerce-qa-cluster --service ecommerce-qa-api --force-new-deployment
```

### Scale Services

Modify in `qa.tfvars`:

```hcl
desired_count = 4
min_capacity  = 2
max_capacity  = 10
```

Then apply:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### Database Maintenance

RDS maintenance window: Sunday 04:00-05:00 UTC
Backup window: Daily 03:00-04:00 UTC

To modify:

```hcl
rds_preferred_maintenance_window = "sun:04:00-sun:05:00"
rds_preferred_backup_window      = "03:00-04:00"
```

### Access Bastion Host

```bash
# Via SSH (requires key pair)
ssh -i bastion-key.pem ec2-user@<bastion-public-ip>

# Via AWS Systems Manager Session Manager (recommended)
aws ssm start-session --target <instance-id>
```

### View Logs

```bash
# CloudWatch Logs
aws logs tail /ecs/ecommerce-qa-api --follow

# VPC Flow Logs
aws s3 ls s3://ecommerce-qa-logs/vpc-flow-logs/

# WAF Logs
aws s3 ls s3://ecommerce-qa-logs/waf/
```

## Disaster Recovery

### Backup Strategy

- **RDS**: Automated daily backups, 7-day retention
- **ElastiCache**: Daily snapshots, 5-day retention
- **Terraform State**: Versioned S3 bucket with DynamoDB locking

### Recovery Procedures

**Database Restore**:

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier ecommerce-qa-postgres \
  --target-db-instance-identifier ecommerce-qa-postgres-restored \
  --restore-time 2026-01-01T12:00:00Z
```

**Infrastructure Rebuild**:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

## Cleanup

To destroy all infrastructure:

```bash
terraform destroy -var-file="environments/qa.tfvars"
```

**Warning**: This will delete all resources including databases. Ensure backups exist before proceeding.

## Troubleshooting

### Common Issues

**Issue**: Terraform state locked  
**Solution**: 
```bash
terraform force-unlock <lock-id>
```

**Issue**: Certificate validation pending  
**Solution**: Add DNS validation records to Route53 (automatic if `route53_zone_id` is set)

**Issue**: ECS tasks failing health checks  
**Solution**: Check CloudWatch logs, verify health check endpoint responds with 200

**Issue**: High costs  
**Solution**: Review budget alerts, consider Reserved Instances for RDS

### Debug Commands

```bash
# View ECS service status
aws ecs describe-services --cluster ecommerce-qa-cluster --services ecommerce-qa-api

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# View CloudWatch metrics
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=ecommerce-qa-api --start-time 2026-01-01T00:00:00Z \
  --end-time 2026-01-02T00:00:00Z --period 3600 --statistics Average
```

## Contributing

When adding new modules:

1. Create module directory in `modules/`
2. Include `main.tf`, `variables.tf`, `outputs.tf`, `README.md`
3. Update root `main.tf` to call new module
4. Add variables to root `variables.tf` and `qa.tfvars`
5. Document in this README

## License

Internal use only.

## Support

For issues or questions, contact the infrastructure team.
