# WAF (Web Application Firewall) Module

Creates AWS WAF Web ACLs for CloudFront and Application Load Balancer with OWASP Top 10 protection.

## Purpose

Protects web applications from common exploits, DDoS attacks, and malicious traffic.

## Resources Created

- CloudFront Web ACL (us-east-1)
- ALB Web ACL (regional)
- IAM role for Kinesis Firehose logging
- 2 Kinesis Firehose delivery streams (optional)
- S3 logging configuration

## Usage

```hcl
module "waf" {
  source = "./modules/waf"

  prefix = "ecommerce"
  env    = "qa"

  enable_cloudfront_waf = true
  enable_alb_waf        = true

  # Logging
  logs_bucket_arn               = module.logs_bucket.bucket_arn
  enable_cloudfront_waf_logging = true
  enable_alb_waf_logging        = true
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_cloudfront_waf | Create CloudFront Web ACL | bool | false |
| enable_alb_waf | Create ALB Web ACL | bool | false |
| logs_bucket_arn | S3 bucket ARN for logs | string | "" |
| enable_cloudfront_waf_logging | Enable CloudFront logging | bool | false |
| enable_alb_waf_logging | Enable ALB logging | bool | false |

## Outputs

| Name | Description |
|------|-------------|
| cloudfront_waf_acl_arn | CloudFront Web ACL ARN |
| alb_waf_acl_arn | ALB Web ACL ARN |
| cloudfront_waf_acl_name | CloudFront Web ACL name |
| alb_waf_acl_name | ALB Web ACL name |

## Protection Rules

### 1. Rate Limiting

- **Limit**: 2,000 requests per 5 minutes per IP
- **Action**: Block excess requests
- **Use**: Prevent brute force and DDoS

### 2. AWS Managed Rules

#### Core Rule Set
- SQL injection protection
- Cross-site scripting (XSS) protection
- Local file inclusion
- Remote file inclusion
- PHP/Linux/Windows command injection

#### Known Bad Inputs
- Known malicious patterns
- CVE-specific exploits
- Bot signatures

#### IP Reputation List
- Amazon threat intelligence
- Known malicious IPs
- Botnet sources

### 3. Geographic Restrictions

Block traffic from high-risk countries:
- North Korea
- Iran
- Syria
- Cuba

Modify list in `modules/waf/main.tf`.

### 4. Size Constraints

- Maximum request body: 8 KB
- Prevents large payload attacks

## Rule Priority

1. Rate limiting (priority 1)
2. AWS Core Rule Set (priority 2)
3. AWS Known Bad Inputs (priority 3)
4. AWS IP Reputation (priority 4)
5. Geographic blocking (priority 5)
6. Body size limit (priority 6)

Lower number = higher priority.

## Logging

### Kinesis Firehose

When logging enabled:
- Logs sent to Kinesis Firehose
- Buffered and compressed (GZIP)
- Delivered to S3 every 300 seconds or 5 MB

### Log Format

JSON format includes:
- Timestamp
- Request details (IP, URI, headers)
- Rule matched
- Action taken (ALLOW/BLOCK)
- Country/region

### S3 Structure

```
s3://bucket/waf/cloudfront/year/month/day/hour/
s3://bucket/waf/alb/year/month/day/hour/
```

### Analysis

Query with Amazon Athena:

```sql
CREATE EXTERNAL TABLE waf_logs (
  timestamp bigint,
  action string,
  httprequest struct<
    clientip:string,
    country:string,
    uri:string,
    method:string
  >
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://bucket/waf/alb/';

-- Find blocked IPs
SELECT httprequest.clientip, COUNT(*) as blocks
FROM waf_logs
WHERE action = 'BLOCK'
GROUP BY httprequest.clientip
ORDER BY blocks DESC
LIMIT 10;
```

## Monitoring

### CloudWatch Metrics

- **AllowedRequests**: Requests allowed
- **BlockedRequests**: Requests blocked
- **CountedRequests**: Requests counted (not blocked)

Per rule metrics available.

### Alarms

CloudWatch alarms configured for:
- High blocked request rate (>1000 in 5 min)
- High block percentage (>50%)

Indicates potential attack.

## Testing WAF Rules

### Rate Limiting

```bash
for i in {1..2500}; do
  curl https://yourdomain.com/ &
done
```

After 2,000 requests in 5 minutes, expect 403 responses.

### SQL Injection

```bash
curl "https://yourdomain.com/?id=1' OR '1'='1"
```

Should return 403 Forbidden.

### XSS

```bash
curl "https://yourdomain.com/?q=<script>alert('xss')</script>"
```

Should return 403 Forbidden.

### Geographic Block

Test from blocked country using VPN. Expect 403 response.

## Customization

### Adjust Rate Limit

Edit `modules/waf/main.tf`:

```hcl
rate_limit = 5000  # Requests per 5 minutes
```

### Allow Specific IPs

Add IP set rule:

```hcl
resource "aws_wafv2_ip_set" "allowed_ips" {
  name  = "${var.prefix}-${var.env}-allowed-ips"
  scope = "REGIONAL"  # or "CLOUDFRONT"
  ip_address_version = "IPV4"
  
  addresses = [
    "203.0.113.0/24",
    "198.51.100.0/24"
  ]
}

# Add rule with priority 0 (highest)
{
  name     = "AllowWhitelistedIPs"
  priority = 0
  action {
    allow {}
  }
  statement {
    ip_set_reference_statement {
      arn = aws_wafv2_ip_set.allowed_ips.arn
    }
  }
}
```

### Block Specific Paths

Add regex pattern set:

```hcl
resource "aws_wafv2_regex_pattern_set" "blocked_paths" {
  name  = "${var.prefix}-${var.env}-blocked-paths"
  scope = "REGIONAL"
  
  regular_expression {
    regex_string = "^/admin"
  }
  
  regular_expression {
    regex_string = "^/phpmyadmin"
  }
}
```

## Cost

### Web ACL

- $5/month per Web ACL
- $1/month per rule (6 rules = $6)
- **Total per ACL**: ~$11/month

### Requests

- First 1 million requests/month: $0.60
- Next 9 million: $0.50/million
- Next 90 million: $0.30/million

### Logging

- Kinesis Firehose: $0.029/GB ingested
- S3 storage: $0.023/GB
- Typical: ~$15/month for logging

**Total WAF cost**: ~$45-55/month for both ACLs with logging.

## Maintenance

### Update Managed Rules

AWS updates managed rule sets automatically. No action needed.

### Review Blocked Traffic

Regularly review logs for:
- False positives (legitimate traffic blocked)
- Attack patterns
- Geographic trends

### Tune Rules

If false positives occur:

1. Identify rule causing block in logs
2. Add exception for specific pattern
3. Test thoroughly

Example exception:

```hcl
rule {
  name     = "AWSManagedRulesCommonRuleSet"
  priority = 2
  
  override_action {
    none {}
  }
  
  statement {
    managed_rule_group_statement {
      name        = "AWSManagedRulesCommonRuleSet"
      vendor_name = "AWS"
      
      # Exclude specific rule
      excluded_rule {
        name = "GenericRFI_BODY"
      }
    }
  }
}
```

## Troubleshooting

### Legitimate Traffic Blocked

Check logs for rule name. Add exception or adjust rule sensitivity.

### No Logs in S3

Verify:
- Logging enabled
- Kinesis Firehose delivering
- S3 bucket permissions

### High Costs

Review request volume and logging. Consider:
- Reduce log retention
- Sample logs (not all requests)
- Optimize rule count

## Security Best Practices

- Enable logging for audit trail
- Monitor blocked request metrics
- Regularly review WAF logs
- Test rules before production deployment
- Use managed rules (auto-updated)
- Combine with AWS Shield for DDoS protection

## Dependencies

- Logs Bucket module (S3 destination for logs)

## Used By

- ALB module (Web ACL association)
- Frontend module (CloudFront distribution)
- CloudWatch Alarms module (attack monitoring)
