# VPC Module

Creates a Virtual Private Cloud with three-tier subnet architecture across multiple availability zones.

## Purpose

Provides network isolation and segmentation for application components with public, application, and data tiers.

## Resources Created

- VPC with custom CIDR block
- Internet Gateway
- NAT Gateway (optional, per AZ)
- Public subnets (2 AZs)
- Application subnets (2 AZs, private)
- Data subnets (2 AZs, private)
- Route tables and associations
- VPC Flow Logs to S3 (optional)
- Security group for VPC endpoints

## Network Architecture

```
VPC (192.168.0.0/16)
├── Public Subnets (192.168.0.0/24, 192.168.1.0/24)
│   └── Internet Gateway
├── Application Subnets (192.168.2.0/24, 192.168.3.0/24)
│   └── NAT Gateway (routes to Internet)
└── Data Subnets (192.168.4.0/24, 192.168.5.0/24)
    └── No internet access
```

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  prefix             = "ecommerce"
  env                = "qa"
  vpc_cidr           = "192.168.0.0/16"
  public_subnet_cidrs = ["192.168.0.0/24", "192.168.1.0/24"]
  app_subnet_cidrs    = ["192.168.2.0/24", "192.168.3.0/24"]
  data_subnet_cidrs   = ["192.168.4.0/24", "192.168.5.0/24"]
  availability_zones  = ["us-east-1a", "us-east-1b"]
  enable_nat_gateway  = true

  # VPC Flow Logs
  enable_vpc_flow_logs            = true
  vpc_flow_logs_bucket_arn        = module.logs_bucket.bucket_arn
  vpc_flow_logs_lifecycle_enabled = true
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| prefix | Resource name prefix | string | - | yes |
| env | Environment name | string | - | yes |
| vpc_cidr | VPC CIDR block | string | - | yes |
| public_subnet_cidrs | Public subnet CIDR blocks | list(string) | - | yes |
| app_subnet_cidrs | Application subnet CIDR blocks | list(string) | - | yes |
| data_subnet_cidrs | Data subnet CIDR blocks | list(string) | - | yes |
| availability_zones | Availability zones for subnets | list(string) | - | yes |
| enable_nat_gateway | Create NAT Gateway | bool | true | no |
| enable_vpc_flow_logs | Enable VPC Flow Logs | bool | false | no |
| vpc_flow_logs_bucket_arn | S3 bucket ARN for Flow Logs | string | "" | no |
| vpc_flow_logs_traffic_type | Traffic type to log | string | "ALL" | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC identifier |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | Public subnet identifiers |
| app_subnet_ids | Application subnet identifiers |
| data_subnet_ids | Data subnet identifiers |
| nat_gateway_ips | NAT Gateway public IPs |
| internet_gateway_id | Internet Gateway identifier |

## VPC Flow Logs

Flow logs capture network traffic metadata for security analysis and troubleshooting.

### Log Format

Custom format includes:
- Source/destination IPs and ports
- Protocol
- Packet and byte counts
- Action (ACCEPT/REJECT)
- Log status

### Storage

Logs are stored in S3 with the following structure:
```
s3://bucket/vpc-flow-logs/AWSLogs/account-id/vpcflowlogs/region/year/month/day/
```

Lifecycle policy:
- 30 days: Standard
- 90 days: Move to Infrequent Access
- Retention configurable

### Analysis

Query logs using Amazon Athena or download for local analysis:

```bash
aws s3 sync s3://ecommerce-qa-logs/vpc-flow-logs/ ./flow-logs/
```

## Subnet Tier Usage

### Public Subnets
- ALB (Application Load Balancer)
- NAT Gateway
- Bastion Host

### Application Subnets
- ECS Fargate tasks
- Lambda functions
- Application servers

### Data Subnets
- RDS PostgreSQL instance
- ElastiCache Redis
- No direct internet access

## NAT Gateway

Provides outbound internet access for private subnets.

Cost: ~$0.045/hour + $0.045/GB processed

To disable (not recommended for production):
```hcl
enable_nat_gateway = false
```

Resources in private subnets will lose internet access for:
- Software updates
- External API calls
- Container image pulls

## Maintenance

### Adding Subnets

To add subnets in new AZs:

1. Update subnet CIDR lists in `qa.tfvars`:
```hcl
availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs = ["192.168.0.0/24", "192.168.1.0/24", "192.168.5.0/24"]
app_subnet_cidrs    = ["192.168.2.0/24", "192.168.3.0/24", "192.168.6.0/24"]
data_subnet_cidrs   = ["192.168.4.0/24", "192.168.7.0/24", "192.168.8.0/24"]
```

2. Apply changes:
```bash
terraform apply -var-file="environments/qa.tfvars"
```

### Modifying CIDR Blocks

VPC and subnet CIDR blocks cannot be modified after creation. To change:

1. Create new VPC with desired CIDR
2. Migrate resources to new VPC
3. Destroy old VPC

### Monitoring

Key CloudWatch metrics:
- NAT Gateway BytesOutToDestination
- NAT Gateway BytesInFromDestination
- VPC Flow Logs delivery errors

## Security Considerations

- Public subnets have route to Internet Gateway
- Application subnets route through NAT Gateway
- Data subnets have no internet route
- Network ACLs allow all traffic by default (use security groups)
- VPC Flow Logs capture all accepted/rejected traffic
- Enable Flow Logs in production for security auditing

## Dependencies

- None (foundational module)

## Used By

- ALB module (public subnets)
- Compute module (application subnets)
- RDS module (data subnets)
- ElastiCache module (data subnets)
- Bastion module (public subnets)
