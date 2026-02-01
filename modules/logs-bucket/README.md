# Centralized Logs Bucket Module

Creates S3 bucket for centralized storage of all infrastructure logs with lifecycle policies and encryption.

## Purpose

Consolidates logs from multiple AWS services in a single, secure, cost-optimized location for compliance and troubleshooting.

## Resources Created

- S3 bucket for log storage
- Bucket policy for service write access
- Lifecycle rules for log retention and cost optimization
- Server-side encryption with KMS
- Versioning enabled for data protection

## Usage

```hcl
module "logs_bucket" {
  source = "./modules/logs-bucket"

  prefix     = "ecommerce"
  env        = "qa"
  kms_key_id = module.kms.kms_key_id
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Resource prefix | string | - |
| env | Environment | string | - |
| kms_key_id | KMS key for encryption | string | - |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | S3 bucket name |
| bucket_arn | S3 bucket ARN |

## Log Types Stored

### 1. CloudTrail Logs

**Path**: `s3://ecommerce-qa-logs/cloudtrail/`

API audit logs for all AWS actions.

```
cloudtrail/
  AWSLogs/
    123456789012/
      CloudTrail/
        us-east-1/
          2026/01/15/
            123456789012_CloudTrail_us-east-1_20260115T0000Z_abc123.json.gz
```

**Retention**: 365 days → Glacier → Delete after 7 years

### 2. ALB Access Logs

**Path**: `s3://ecommerce-qa-logs/alb/`

Application Load Balancer HTTP request logs.

```
alb/
  AWSLogs/
    123456789012/
      elasticloadbalancing/
        us-east-1/
          2026/01/15/
            123456789012_elasticloadbalancing_us-east-1_app.ecommerce-qa-alb.abc123_20260115T0000Z_1.2.3.4_abc.log.gz
```

**Fields**: timestamp, client IP, target IP, request processing time, response code, sent/received bytes, request URL, user agent

**Retention**: 90 days → Delete

### 3. CloudFront Access Logs

**Path**: `s3://ecommerce-qa-logs/cloudfront/`

CDN request logs for frontend distribution.

```
cloudfront/
  E1234ABCD5678.2026-01-15-10.abc123.gz
```

**Fields**: date, time, edge location, bytes, client IP, method, host, URI, status, referer, user-agent

**Retention**: 90 days → Delete

### 4. VPC Flow Logs

**Path**: `s3://ecommerce-qa-logs/vpc-flow-logs/`

Network traffic metadata for VPC.

```
vpc-flow-logs/
  AWSLogs/
    123456789012/
      vpcflowlogs/
        us-east-1/
          2026/01/15/
            123456789012_vpcflowlogs_us-east-1_fl-abc123_20260115T0000Z_abc.log.gz
```

**Fields**: account-id, interface-id, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action (ACCEPT/REJECT)

**Retention**: 30 days → Delete

### 5. WAF Logs

**Path**: `s3://ecommerce-qa-logs/waf/`

Web Application Firewall blocked/allowed requests.

```
waf/
  cloudfront/
    2026/01/15/10/
      waf-logs-ecommerce-qa-1-2026-01-15-10-30-00-abc123.gz
  alb/
    2026/01/15/10/
      waf-logs-ecommerce-qa-1-2026-01-15-10-30-00-def456.gz
```

**Retention**: 90 days → Delete

## Bucket Structure

```
ecommerce-qa-logs/
├── cloudtrail/          # API audit logs
├── alb/                 # Load balancer access logs  
├── cloudfront/          # CDN access logs
├── vpc-flow-logs/       # Network traffic logs
└── waf/                 # Web firewall logs
    ├── cloudfront/
    └── alb/
```

## Lifecycle Policies

Optimizes storage costs by transitioning logs through storage classes:

| Log Type | Retention | Transition | Final Action |
|----------|-----------|------------|--------------|
| CloudTrail | 7 years | 365d → Glacier | Delete 2555d |
| ALB | 90 days | - | Delete 90d |
| CloudFront | 90 days | - | Delete 90d |
| VPC Flow Logs | 30 days | - | Delete 30d |
| WAF | 90 days | - | Delete 90d |

### Storage Classes

- **S3 Standard**: First 30-365 days (frequent access)
- **S3 Glacier**: 365+ days (CloudTrail only, compliance)
- **Delete**: After retention period

### Cost Savings

Example for CloudTrail (10 GB/month):

| Period | Storage Class | Size | Cost/Month |
|--------|---------------|------|------------|
| 0-365d | S3 Standard | 120 GB | $2.76 |
| 365-2555d | S3 Glacier | 600 GB | $2.40 |
| **Total** | | **720 GB** | **$5.16** |

Without lifecycle policy (all S3 Standard): 720 GB × $0.023 = $16.56/month

**Savings**: $11.40/month (69% reduction)

## Querying Logs

### Athena Setup

Query logs with SQL:

1. **Create database**:

```sql
CREATE DATABASE logs_db;
```

2. **Create table for ALB logs**:

```sql
CREATE EXTERNAL TABLE alb_logs (
  type string,
  time string,
  elb string,
  client_ip string,
  client_port int,
  target_ip string,
  target_port int,
  request_processing_time double,
  target_processing_time double,
  response_processing_time double,
  elb_status_code string,
  target_status_code string,
  received_bytes bigint,
  sent_bytes bigint,
  request_verb string,
  request_url string,
  request_proto string,
  user_agent string,
  ssl_cipher string,
  ssl_protocol string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  'serialization.format' = '1',
  'input.regex' = '([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*):([0-9]*) ([^ ]*)[:-]([0-9]*) ([-.0-9]*) ([-.0-9]*) ([-.0-9]*) (|[-0-9]*) (-|[-0-9]*) ([-0-9]*) ([-0-9]*) \"([^ ]*) ([^ ]*) (- |[^ ]*)\" \"([^\"]*)\" ([A-Z0-9-]+) ([A-Za-z0-9.-]*)'
)
LOCATION 's3://ecommerce-qa-logs/alb/AWSLogs/123456789012/elasticloadbalancing/us-east-1/';
```

3. **Query examples**:

```sql
-- Top 10 client IPs
SELECT client_ip, COUNT(*) as requests
FROM alb_logs
WHERE from_iso8601_timestamp(time) > current_timestamp - interval '1' day
GROUP BY client_ip
ORDER BY requests DESC
LIMIT 10;

-- 5xx errors
SELECT time, client_ip, request_url, elb_status_code
FROM alb_logs
WHERE elb_status_code LIKE '5%'
  AND from_iso8601_timestamp(time) > current_timestamp - interval '1' day
ORDER BY time DESC;

-- Slow requests (>2 seconds)
SELECT time, client_ip, request_url, target_processing_time
FROM alb_logs
WHERE target_processing_time > 2.0
  AND from_iso8601_timestamp(time) > current_timestamp - interval '1' day
ORDER BY target_processing_time DESC;
```

### CloudWatch Logs Insights

For recent logs (last 7 days), use CloudWatch Logs Insights (faster, cheaper than Athena for short time ranges).

## Security

### Bucket Policy

Grants write access to AWS services:

- **CloudTrail**: PutObject for audit logs
- **ALB**: PutObject for access logs
- **CloudFront**: PutObject for distribution logs
- **VPC Flow Logs**: PutObject for network logs
- **Kinesis Firehose** (WAF): PutObject for firewall logs

### Encryption

All logs encrypted at rest with KMS:

```hcl
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
  }
}
```

### Versioning

Enabled to protect against accidental deletion:

```hcl
versioning {
  enabled = true
}
```

Restore deleted log file:

```bash
# List versions
aws s3api list-object-versions \
  --bucket ecommerce-qa-logs \
  --prefix cloudtrail/AWSLogs/123456789012/CloudTrail/us-east-1/2026/01/15/

# Restore specific version
aws s3api copy-object \
  --bucket ecommerce-qa-logs \
  --key cloudtrail/AWSLogs/.../log.json.gz \
  --copy-source ecommerce-qa-logs/cloudtrail/AWSLogs/.../log.json.gz?versionId=abc123
```

### Public Access Block

All public access disabled:

```hcl
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

Logs accessible only via IAM permissions.

## Cost

### Storage Costs

Estimated for medium deployment:

| Log Type | Monthly Volume | Storage Cost | Lifecycle Savings | Total |
|----------|----------------|--------------|-------------------|-------|
| CloudTrail | 5 GB | $0.12 (current) + $1.00 (Glacier) | -$0.80 | $0.32 |
| ALB | 20 GB | $0.46 | - | $0.46 |
| CloudFront | 10 GB | $0.23 | - | $0.23 |
| VPC Flow Logs | 15 GB | $0.35 | - | $0.35 |
| WAF | 8 GB | $0.18 | - | $0.18 |
| **Total** | **58 GB** | | | **$1.54/month** |

### Other Costs

- **Athena queries**: $5/TB scanned (first 1 TB/month free)
- **S3 requests**: Minimal (included in free tier)

## Maintenance

### Monitor Bucket Size

```bash
# Get bucket size
aws s3 ls s3://ecommerce-qa-logs --recursive --summarize

# Size by prefix
aws s3 ls s3://ecommerce-qa-logs/cloudtrail/ --recursive --summarize
```

### Adjust Lifecycle Policies

Extend CloudTrail retention to 10 years:

```hcl
lifecycle_rule {
  id      = "cloudtrail-retention"
  enabled = true
  prefix  = "cloudtrail/"

  transition {
    days          = 365
    storage_class = "GLACIER"
  }

  expiration {
    days = 3650  # 10 years (was 2555/7 years)
  }
}
```

### Empty Bucket Before Deletion

If removing infrastructure:

```bash
# Delete all objects and versions
aws s3api delete-objects \
  --bucket ecommerce-qa-logs \
  --delete "$(aws s3api list-object-versions \
    --bucket ecommerce-qa-logs \
    --output json \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

# Delete bucket
aws s3 rb s3://ecommerce-qa-logs
```

## Troubleshooting

### Logs Not Appearing

1. **Check service configuration**: Verify logging enabled in service (ALB, CloudFront, etc.)
2. **Verify bucket policy**: Ensure service principal has PutObject permission
3. **Check S3 path**: Confirm correct prefix/folder
4. **Review service logs**: Check CloudTrail for S3 PutObject denials

### High Storage Costs

1. **Review lifecycle policies**: Ensure transitioning/deleting old logs
2. **Check log volume**: Identify source of excessive logs
3. **Reduce log verbosity**: Disable detailed logging for non-critical resources
4. **Compress logs**: Ensure services using GZIP compression

### Cannot Query with Athena

1. **Verify table schema**: Check LOCATION path matches bucket structure
2. **Check IAM permissions**: Athena needs s3:GetObject on logs bucket
3. **Validate SerDe**: Ensure SerDe matches log format
4. **Partition tables**: For large datasets, use partitions by date

## Best Practices

- Enable versioning for data protection
- Use lifecycle policies to reduce costs
- Encrypt all logs with KMS
- Block public access completely
- Monitor bucket size monthly
- Set up Athena for historical analysis
- Use CloudWatch Logs Insights for recent logs
- Document log retention requirements for compliance
- Review bucket policy quarterly
- Test log restoration procedures

## Dependencies

- KMS module (encryption)

## Used By

- CloudTrail module (API audit logs)
- ALB module (load balancer access logs)
- Frontend module (CloudFront access logs)
- VPC module (VPC Flow Logs)
- WAF module (firewall logs via Kinesis Firehose)

Security, operations, and compliance teams for log analysis and auditing.
