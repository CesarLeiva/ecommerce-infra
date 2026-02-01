# Application Load Balancer Module

Creates an Application Load Balancer with HTTP/HTTPS listeners and WAF integration.

## Purpose

Distributes incoming traffic across ECS tasks with SSL termination and Web Application Firewall protection.

## Resources Created

- Application Load Balancer
- Security group for ALB
- HTTP listener (port 80)
- HTTPS listener (port 443, optional)
- WAF Web ACL association (optional)

## Usage

```hcl
module "alb" {
  source = "./modules/alb"

  prefix                     = "ecommerce"
  env                        = "qa"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.public_subnet_ids
  enable_deletion_protection = false
  enable_https               = true
  ssl_policy                 = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn            = module.acm.certificate_arn
  enable_waf                 = true
  waf_web_acl_arn           = module.waf.alb_waf_acl_arn
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| prefix | Resource name prefix | string | - | yes |
| env | Environment name | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| subnet_ids | Public subnet IDs for ALB | list(string) | - | yes |
| enable_deletion_protection | Enable deletion protection | bool | false | no |
| enable_https | Enable HTTPS listener | bool | false | no |
| ssl_policy | SSL policy for HTTPS | string | - | conditional |
| certificate_arn | ACM certificate ARN | string | "" | conditional |
| enable_waf | Enable WAF association | bool | false | no |
| waf_web_acl_arn | WAF Web ACL ARN | string | "" | conditional |

## Outputs

| Name | Description |
|------|-------------|
| alb_arn | Load balancer ARN |
| alb_arn_suffix | Load balancer ARN suffix for CloudWatch |
| alb_dns_name | Load balancer DNS name |
| alb_zone_id | Route53 hosted zone ID |
| alb_security_group_id | Security group ID |
| http_listener_arn | HTTP listener ARN |
| https_listener_arn | HTTPS listener ARN |

## SSL/TLS Configuration

### Supported Policies

- **ELBSecurityPolicy-TLS13-1-2-2021-06**: TLS 1.3 and 1.2 only (recommended)
- **ELBSecurityPolicy-TLS-1-2-2017-01**: TLS 1.2 minimum
- **ELBSecurityPolicy-2016-08**: TLS 1.0+ (legacy)

### Certificate Requirements

ACM certificate must be validated and in ISSUED state before enabling HTTPS.

### HTTPS Listener Behavior

When `enable_https = true`:
- Port 443 listens with TLS termination
- HTTP listener (port 80) redirects to HTTPS
- Certificate from ACM is attached
- SSL policy enforces minimum TLS version

When `enable_https = false`:
- Only HTTP listener on port 80
- No SSL termination
- No certificate required

## Security Groups

### ALB Security Group Rules

**Ingress**:
- Port 80 (HTTP) from 0.0.0.0/0
- Port 443 (HTTPS) from 0.0.0.0/0 (if HTTPS enabled)

**Egress**:
- All traffic to VPC CIDR (to reach ECS tasks)

### Required for ECS Tasks

ECS task security groups must allow inbound traffic from ALB security group on container port.

## WAF Integration

When `enable_waf = true`:
- Associates WAF Web ACL with ALB
- All requests pass through WAF rules
- Blocked requests return 403 Forbidden
- WAF logs can be sent to S3 via Kinesis Firehose

## Health Checks

ALB performs health checks on target groups created by ECS services:
- Interval: 30 seconds
- Timeout: 5 seconds
- Healthy threshold: 2 consecutive successes
- Unhealthy threshold: 3 consecutive failures

Health check configuration is managed by the Compute module.

## Monitoring

### CloudWatch Metrics

- **TargetResponseTime**: Average response time
- **RequestCount**: Total requests
- **HTTPCode_Target_2XX_Count**: Successful responses
- **HTTPCode_Target_4XX_Count**: Client errors
- **HTTPCode_Target_5XX_Count**: Server errors
- **UnHealthyHostCount**: Unhealthy targets
- **ActiveConnectionCount**: Active TCP connections

### Access Logs

Not enabled by default. To enable:

1. Create S3 bucket for ALB logs
2. Add bucket policy allowing ALB to write
3. Enable access logs on ALB:

```hcl
access_logs {
  bucket  = "ecommerce-qa-alb-logs"
  enabled = true
}
```

## Maintenance

### Update SSL Certificate

When certificate is renewed:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

Terraform will detect the new certificate ARN and update listener.

### Modify SSL Policy

Update in `qa.tfvars`:

```hcl
alb_ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
```

Apply changes:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### Enable Deletion Protection

For production environments:

```hcl
alb_enable_deletion_protection = true
```

This prevents accidental deletion via console or API.

## Routing

Listener rules route traffic to target groups based on path patterns:

- `/api/*` → API service
- `/admin/*` → Admin service
- Default action: 404

Rules are configured in the Compute module per service.

## Cost

- **ALB hours**: $0.0225/hour (~$16/month)
- **LCU (Load Balancer Capacity Units)**: $0.008/hour per LCU
- Estimated total: ~$28/month for moderate traffic

LCU factors:
- New connections per second
- Active connections per minute
- Bytes processed
- Rule evaluations

## Troubleshooting

### 502 Bad Gateway

**Cause**: Target group has no healthy targets

**Solution**:
```bash
aws elbv2 describe-target-health --target-group-arn <arn>
```

Check ECS task logs and health check endpoint.

### 503 Service Unavailable

**Cause**: No registered targets

**Solution**: Verify ECS service has running tasks.

### SSL Certificate Errors

**Cause**: Certificate not validated or expired

**Solution**: Check ACM console for certificate status.

## Dependencies

- VPC module (public subnets)
- ACM module (for HTTPS)
- WAF module (optional, for Web ACL)

## Used By

- Compute module (target group registration)
- Route53 module (A record creation)
- CloudWatch Alarms module (monitoring)
