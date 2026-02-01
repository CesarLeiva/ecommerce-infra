# Route53 Module

Creates and manages DNS hosted zone and records for domain routing to ALB and CloudFront.

## Purpose

Provides DNS resolution for custom domains, routing traffic to load balancers and CDN distributions.

## Resources Created

- Route53 hosted zone (if creating new zone)
- A record (alias) pointing to ALB
- A record (alias) pointing to CloudFront distribution
- NS record for subdomain delegation (optional)

## Usage

### New Hosted Zone

```hcl
module "route53" {
  source = "./modules/route53"

  domain_name     = "ecommerce.com"
  create_zone     = true
  alb_dns_name    = module.alb.alb_dns_name
  alb_zone_id     = module.alb.alb_zone_id
  
  # Frontend subdomain
  create_cloudfront_record = true
  cloudfront_subdomain     = "www"
  cloudfront_dns_name      = module.frontend.cloudfront_domain_name
  cloudfront_zone_id       = module.frontend.cloudfront_zone_id
}
```

### Existing Hosted Zone

```hcl
module "route53" {
  source = "./modules/route53"

  domain_name     = "ecommerce.com"
  create_zone     = false
  zone_id         = "Z1234567890ABC"  # Existing zone
  alb_dns_name    = module.alb.alb_dns_name
  alb_zone_id     = module.alb.alb_zone_id
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| domain_name | Primary domain | string | - |
| create_zone | Create new hosted zone | bool | true |
| zone_id | Existing zone ID (if create_zone=false) | string | null |
| alb_dns_name | ALB DNS name | string | - |
| alb_zone_id | ALB hosted zone ID | string | - |
| create_cloudfront_record | Create CloudFront record | bool | false |
| cloudfront_subdomain | Subdomain for CloudFront | string | www |
| cloudfront_dns_name | CloudFront distribution domain | string | null |
| cloudfront_zone_id | CloudFront hosted zone ID | string | null |

## Outputs

| Name | Description |
|------|-------------|
| zone_id | Route53 hosted zone ID |
| name_servers | Zone name servers |
| alb_record_name | ALB DNS record |
| cloudfront_record_name | CloudFront DNS record |

## DNS Records Created

### ALB Record (API/Backend)

Points root domain or subdomain to Application Load Balancer:

```
api.ecommerce.com → ecommerce-qa-alb-123456789.us-east-1.elb.amazonaws.com
```

**Type**: A record (alias)
**Target**: ALB DNS name
**Routing**: Simple routing

### CloudFront Record (Frontend)

Points subdomain to CloudFront distribution:

```
www.ecommerce.com → d1234abcd5678.cloudfront.net
```

**Type**: A record (alias)
**Target**: CloudFront distribution
**Routing**: Simple routing

### Example Configuration

```
ecommerce.com
├── NS → ns-123.awsdns-12.com (AWS name servers)
├── SOA → ns-123.awsdns-12.com. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400
├── A (api.ecommerce.com) → ALB alias
└── A (www.ecommerce.com) → CloudFront alias
```

## Name Server Setup

After creating hosted zone, update domain registrar with AWS name servers.

### Get Name Servers

```bash
aws route53 get-hosted-zone --id Z1234567890ABC --query 'DelegationSet.NameServers'
```

Output:
```json
[
  "ns-123.awsdns-12.com",
  "ns-456.awsdns-34.net",
  "ns-789.awsdns-56.org",
  "ns-012.awsdns-78.co.uk"
]
```

### Update Registrar

1. Log into domain registrar (GoDaddy, Namecheap, Google Domains, etc.)
2. Find DNS/Name Server settings
3. Replace existing name servers with AWS name servers
4. Save changes
5. Wait 24-48 hours for propagation (usually faster, 1-2 hours)

### Verify Propagation

```bash
# Check name servers
dig NS ecommerce.com

# Check A record
dig api.ecommerce.com
dig www.ecommerce.com

# Trace DNS resolution
dig +trace www.ecommerce.com
```

## Alias Records vs CNAME

Route53 alias records used instead of CNAME for:

- **No cost**: Alias queries free, CNAME queries charged
- **Root domain support**: Alias works for root (ecommerce.com), CNAME doesn't
- **AWS integration**: Health checks, automatic updates
- **Faster resolution**: One DNS query instead of two

Example comparison:

```
# Alias (recommended)
api.ecommerce.com → ALB (direct)

# CNAME (not used)
api.ecommerce.com → CNAME ecommerce-qa-alb-123.us-east-1.elb.amazonaws.com → ALB IP
```

## SSL/TLS Certificate Validation

If using ACM certificates, Route53 can auto-validate:

```hcl
resource "aws_acm_certificate" "cert" {
  domain_name       = "ecommerce.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.ecommerce.com",
    "www.ecommerce.com"
  ]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}
```

Terraform automatically creates validation CNAME records.

## Health Checks

Add health checks for automatic failover:

```hcl
resource "aws_route53_health_check" "alb" {
  fqdn              = "api.ecommerce.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "ecommerce-alb-health-check"
  }
}

resource "aws_route53_record" "alb" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.ecommerce.com"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true  # Use health check
  }

  set_identifier = "primary"
  
  health_check_id = aws_route53_health_check.alb.id
}
```

## Multi-Region Failover

For disaster recovery, route to secondary region:

```hcl
# Primary region (us-east-1)
resource "aws_route53_record" "alb_primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.ecommerce.com"
  type    = "A"

  alias {
    name                   = module.alb_primary.alb_dns_name
    zone_id                = module.alb_primary.alb_zone_id
    evaluate_target_health = true
  }

  set_identifier = "us-east-1"
  
  failover_routing_policy {
    type = "PRIMARY"
  }
  
  health_check_id = aws_route53_health_check.alb_primary.id
}

# Secondary region (us-west-2)
resource "aws_route53_record" "alb_secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.ecommerce.com"
  type    = "A"

  alias {
    name                   = module.alb_secondary.alb_dns_name
    zone_id                = module.alb_secondary.alb_zone_id
    evaluate_target_health = true
  }

  set_identifier = "us-west-2"
  
  failover_routing_policy {
    type = "SECONDARY"
  }
}
```

Traffic routes to us-west-2 automatically if us-east-1 health check fails.

## Cost

- **Hosted zone**: $0.50/month per zone
- **Standard queries**: $0.40/million queries (first 1 billion/month)
- **Alias queries**: Free (to AWS resources)
- **Health checks**: $0.50/month per endpoint

**Typical monthly cost**: ~$0.50-1.00/month (single zone, alias records)

## Maintenance

### Add New Record

```hcl
resource "aws_route53_record" "new_subdomain" {
  zone_id = module.route53.zone_id
  name    = "blog.ecommerce.com"
  type    = "CNAME"
  ttl     = 300
  records = ["external-blog-platform.com"]
}
```

### Change Record TTL

Lower TTL before changes (faster propagation):

```hcl
resource "aws_route53_record" "alb" {
  # ... other config
  ttl = 60  # Was 300, reduced for faster updates
}
```

After change stabilizes, increase TTL to reduce query volume.

### Migrate Domain

1. Create new hosted zone in Route53
2. Export records from old DNS provider
3. Import records to Route53
4. Lower TTL on all records (24 hours before migration)
5. Update name servers at registrar
6. Monitor traffic
7. Increase TTL after 48 hours

## Troubleshooting

### Domain Not Resolving

1. **Check name servers**:
   ```bash
   dig NS ecommerce.com
   ```
   Should return AWS name servers.

2. **Verify record exists**:
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC
   ```

3. **Test DNS resolution**:
   ```bash
   nslookup api.ecommerce.com
   dig api.ecommerce.com
   ```

4. **Check propagation**: Use https://dnschecker.org

### SSL Certificate Not Validating

1. Verify validation CNAME records created
2. Check records in correct hosted zone
3. Wait up to 30 minutes for validation
4. Review ACM certificate status:
   ```bash
   aws acm describe-certificate --certificate-arn <arn>
   ```

### Subdomain Not Working

1. Verify A/CNAME record created
2. Check record type (A for ALB/CloudFront, CNAME for external)
3. Confirm TTL and wait for propagation
4. Clear local DNS cache:
   ```bash
   # Windows
   ipconfig /flushdns
   
   # macOS
   sudo dscacheutil -flushcache
   
   # Linux
   sudo systemd-resolve --flush-caches
   ```

## Best Practices

- Use alias records for AWS resources (free, faster)
- Set appropriate TTL (300s for frequently changing, 3600s for static)
- Enable query logging for troubleshooting
- Use health checks for critical endpoints
- Document name server changes
- Lower TTL before planned changes
- Monitor query metrics in CloudWatch
- Set up budget alerts for unexpected query volume
- Use Route 53 Application Recovery Controller for high availability
- Implement DNSSEC for enhanced security

## Dependencies

- ALB module (backend DNS target)
- Frontend module (CloudFront DNS target)

## Used By

End users accessing the application via custom domain names.

All traffic flows through Route53 DNS resolution before reaching infrastructure.
