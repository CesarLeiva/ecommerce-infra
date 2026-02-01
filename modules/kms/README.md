# KMS Module

Creates AWS KMS encryption keys for encrypting data at rest across all infrastructure services.

## Purpose

Provides centralized encryption key management with automatic rotation, auditing, and access control.

## Resources Created

- KMS Customer Managed Key (CMK)
- Key alias for easy reference
- Key policy with service permissions

## Usage

```hcl
module "kms" {
  source = "./modules/kms"

  prefix                 = "ecommerce"
  env                    = "qa"
  enable_key_rotation    = true
  deletion_window_in_days = 30
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Resource prefix | string | - |
| env | Environment | string | - |
| enable_key_rotation | Enable automatic key rotation | bool | true |
| deletion_window_in_days | Key deletion waiting period | number | 30 |

## Outputs

| Name | Description |
|------|-------------|
| kms_key_id | KMS key ID |
| kms_key_arn | KMS key ARN |
| key_alias | Key alias name |

## Encrypted Services

Single KMS key encrypts:

### Storage
- **RDS PostgreSQL instance**: Database storage and automated backups
- **RDS snapshots**: Manual and automated snapshots
- **ElastiCache**: Redis data at rest
- **S3 buckets**: Frontend assets, logs, CloudTrail logs
- **EBS volumes**: Bastion host root volume

### Logging
- **CloudWatch Log Groups**: ECS logs, VPC Flow Logs, CloudTrail logs
- **SNS Topics**: Budget and alarm notifications

### Secrets
- **Secrets Manager**: RDS and Redis passwords

## Key Rotation

Automatic rotation enabled by default:

```hcl
enable_key_rotation = true
```

- Rotates annually (365 days)
- AWS manages rotation automatically
- Previous key versions retained for decryption
- No application changes required
- Audit via CloudTrail

Verify rotation status:

```bash
aws kms get-key-rotation-status --key-id <key-id>
```

## Key Policy

Grants encryption/decryption permissions to AWS services:

- **Account root**: Full key administration
- **RDS**: encrypt, decrypt, create-grant for database encryption
- **CloudWatch Logs**: encrypt, decrypt, describe for log encryption
- **SNS**: encrypt, decrypt for topic encryption
- **S3**: encrypt, decrypt, generate-data-key for bucket encryption
- **EBS**: create-grant for volume encryption
- **Secrets Manager**: encrypt, decrypt for secret encryption

View key policy:

```bash
aws kms get-key-policy --key-id <key-id> --policy-name default
```

## Key Alias

Created for easy reference:

```
alias/ecommerce-qa-key
```

Use alias instead of key ID:

```bash
# Encrypt with alias
aws kms encrypt \
  --key-id alias/ecommerce-qa-key \
  --plaintext "sensitive-data" \
  --output text \
  --query CiphertextBlob

# Decrypt
aws kms decrypt \
  --ciphertext-blob fileb://encrypted.dat \
  --output text \
  --query Plaintext | base64 -d
```

## Encryption at Rest

### RDS PostgreSQL

```hcl
resource "aws_db_instance" "main" {
  storage_encrypted = true
  kms_key_id        = module.kms.kms_key_arn
}
```

- Encrypts instance storage
- Encrypts automated backups
- Encrypts manual snapshots
- Encrypts read replicas

### ElastiCache Redis

```hcl
resource "aws_elasticache_replication_group" "redis" {
  at_rest_encryption_enabled = true
  kms_key_id                 = module.kms.kms_key_arn
}
```

Encrypts Redis data files on disk.

### S3 Buckets

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = module.kms.kms_key_arn
    }
  }
}
```

All objects encrypted automatically on upload.

### CloudWatch Log Groups

```hcl
resource "aws_cloudwatch_log_group" "ecs" {
  kms_key_id = module.kms.kms_key_id
}
```

Encrypts log data at rest.

### SNS Topics

```hcl
resource "aws_sns_topic" "alarms" {
  kms_master_key_id = module.kms.kms_key_id
}
```

Encrypts messages in transit and at rest.

## Key Deletion

Protected by deletion window (default 30 days):

1. Key marked for deletion
2. 30-day waiting period
3. Key unusable during waiting period
4. Can cancel deletion within 30 days
5. After 30 days, permanently deleted

Schedule deletion:

```bash
aws kms schedule-key-deletion \
  --key-id <key-id> \
  --pending-window-in-days 30
```

Cancel deletion:

```bash
aws kms cancel-key-deletion --key-id <key-id>
```

## Auditing

All KMS operations logged to CloudTrail:

- Key creation and deletion
- Encryption and decryption calls
- Key policy changes
- Key rotation events
- Grant creation

Query KMS usage:

```bash
# CloudWatch Logs Insights
fields @timestamp, userIdentity.userName, eventName, requestParameters.keyId
| filter eventSource = "kms.amazonaws.com"
| sort @timestamp desc
| limit 100
```

## Performance

KMS operations have quota limits:

- **Encrypt/Decrypt/GenerateDataKey**: 10,000 requests/second (shared quota)
- **DescribeKey**: 30,000 requests/second

For high-throughput applications, use data key caching:

```python
import boto3
from aws_encryption_sdk import KMSMasterKeyProvider
from aws_encryption_sdk.caching import LocalCryptoMaterialsCache, CachingCryptoMaterialsManager

# Cache data keys for 10 minutes
cache = LocalCryptoMaterialsCache(capacity=100)
kms_key_provider = KMSMasterKeyProvider(key_ids=['alias/ecommerce-qa-key'])
crypto_materials_manager = CachingCryptoMaterialsManager(
    master_key_provider=kms_key_provider,
    cache=cache,
    max_age=600
)
```

## Cost

- **KMS key**: $1/month per CMK
- **Requests**: 
  - First 20,000 requests/month: Free
  - Additional requests: $0.03/10,000 requests
- **Typical monthly cost**: ~$1-2/month

Example:
- 1 CMK: $1.00
- 100,000 requests: (100,000 - 20,000) / 10,000 × $0.03 = $0.24
- **Total**: $1.24/month

## Best Practices

1. **Enable rotation**: Rotate keys annually for security
2. **Use grants**: For service-to-service access (better than key policy for temporary access)
3. **Monitor usage**: Review CloudTrail logs for unusual encryption patterns
4. **Least privilege**: Grant only required permissions in key policy
5. **Backup key ID**: Store key ID/ARN in secure location
6. **Use alias**: Reference key by alias, not ID (easier to rotate keys)
7. **Test deletion**: Verify no services depend on key before scheduling deletion

## Maintenance

### Add Service Permission

Update key policy to grant new service access:

```hcl
statement {
  sid    = "AllowLambdaEncryption"
  effect = "Allow"
  principals {
    type        = "Service"
    identifiers = ["lambda.amazonaws.com"]
  }
  actions = [
    "kms:Decrypt",
    "kms:DescribeKey"
  ]
  resources = ["*"]
}
```

### View Key Metadata

```bash
aws kms describe-key --key-id alias/ecommerce-qa-key
```

Output includes:
- Key state (Enabled/Disabled/PendingDeletion)
- Creation date
- Rotation status
- Key usage (ENCRYPT_DECRYPT)

### Disable Key (Emergency)

Temporarily disable key (reversible):

```bash
aws kms disable-key --key-id <key-id>
```

Re-enable:

```bash
aws kms enable-key --key-id <key-id>
```

## Troubleshooting

### Access Denied on Encryption

1. Verify service principal in key policy
2. Check IAM role has kms:Encrypt permission
3. Ensure key state is Enabled
4. Review CloudTrail logs for detailed error

### Key Not Found

1. Verify key ID/alias correct
2. Check key not scheduled for deletion
3. Confirm correct AWS region

### High KMS Costs

1. Review CloudTrail for excessive kms:Decrypt calls
2. Implement data key caching for high-volume apps
3. Consider using S3 default encryption (SSE-S3) for non-sensitive data

## Dependencies

None (foundational module, used by other modules).

## Used By

All infrastructure modules requiring encryption:
- RDS
- ElastiCache
- S3 (Frontend, Logs)
- CloudWatch Logs
- SNS (Budgets, Alarms)
- Secrets Manager
- EBS (Bastion)
