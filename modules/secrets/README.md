# Secrets Manager Module

Stores and manages sensitive credentials (RDS and Redis passwords) with automatic rotation support and encryption.

## Purpose

Centralizes secret management with encryption, access control, automatic rotation, and audit logging.

## Resources Created

- Secrets Manager secrets for:
  - RDS database master password
  - Redis authentication token
- KMS encryption for secrets
- Version tracking
- Resource policies

## Usage

```hcl
module "secrets" {
  source = "./modules/secrets"

  prefix     = "ecommerce"
  env        = "qa"
  kms_key_id = module.kms.kms_key_id

  rds_master_password  = "ChangeMe123!Secure"
  redis_auth_token     = "AnotherSecurePassword456!"
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Resource prefix | string | - |
| env | Environment | string | - |
| kms_key_id | KMS key for encryption | string | - |
| rds_master_password | Initial RDS password | string | - |
| redis_auth_token | Initial Redis password | string | - |

## Outputs

| Name | Description |
|------|-------------|
| rds_secret_arn | RDS secret ARN |
| rds_secret_name | RDS secret name |
| redis_secret_arn | Redis secret ARN |
| redis_secret_name | Redis secret name |

## Secrets Stored

### 1. RDS Master Password

**Secret Name**: `ecommerce-qa-rds-password`

**Format**:
```json
{
  "username": "dbadmin",
  "password": "SecureRandomPassword123!",
  "engine": "postgres",
  "host": "ecommerce-qa-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "ecommerce"
}
```

**Used By**:
- RDS Aurora cluster for master user authentication
- ECS tasks connecting to database
- Bastion host for administrative access

### 2. Redis Auth Token

**Secret Name**: `ecommerce-qa-redis-password`

**Format**:
```json
{
  "password": "AnotherSecurePassword456!",
  "host": "ecommerce-qa-redis.xxxxx.cache.amazonaws.com",
  "port": 6379,
  "tls": true
}
```

**Used By**:
- ElastiCache Redis cluster for authentication
- ECS tasks connecting to Redis
- Bastion host for Redis CLI access

## Retrieving Secrets

### AWS CLI

```bash
# Get RDS password
aws secretsmanager get-secret-value \
  --secret-id ecommerce-qa-rds-password \
  --query SecretString \
  --output text

# Parse JSON
aws secretsmanager get-secret-value \
  --secret-id ecommerce-qa-rds-password \
  --query SecretString \
  --output text | jq -r '.password'

# Get Redis password
aws secretsmanager get-secret-value \
  --secret-id ecommerce-qa-redis-password \
  --query SecretString \
  --output text | jq -r '.password'
```

### From ECS Task

#### Environment Variable Method

Not recommended (secrets visible in task definition):

```hcl
environment {
  name  = "DB_PASSWORD"
  value = data.aws_secretsmanager_secret_version.rds.secret_string
}
```

#### Secrets Method (Recommended)

Injected at runtime, not visible in definition:

```hcl
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "${aws_secretsmanager_secret.rds.arn}:password::"
  },
  {
    name      = "REDIS_PASSWORD"
    valueFrom = "${aws_secretsmanager_secret.redis.arn}:password::"
  }
]
```

**IAM Permission Required**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:ecommerce-qa-*",
        "arn:aws:kms:us-east-1:123456789012:key/abc-123-def-456"
      ]
    }
  ]
}
```

### From Application Code

#### Node.js

```javascript
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager({ region: 'us-east-1' });

async function getDatabasePassword() {
  const data = await secretsManager.getSecretValue({
    SecretId: 'ecommerce-qa-rds-password'
  }).promise();
  
  const secret = JSON.parse(data.SecretString);
  return secret.password;
}

// Use in database connection
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: await getDatabasePassword(),
  database: process.env.DB_NAME,
  port: 5432,
  ssl: { rejectUnauthorized: false }
});
```

#### Python

```python
import boto3
import json

def get_database_password():
    client = boto3.client('secretsmanager', region_name='us-east-1')
    response = client.get_secret_value(SecretId='ecommerce-qa-rds-password')
    secret = json.loads(response['SecretString'])
    return secret['password']

# Use in database connection
import psycopg2

conn = psycopg2.connect(
    host=os.environ['DB_HOST'],
    user=os.environ['DB_USER'],
    password=get_database_password(),
    database=os.environ['DB_NAME'],
    port=5432,
    sslmode='require'
)
```

## Secret Rotation

### Automatic Rotation (RDS)

Enable automatic password rotation for RDS:

```hcl
resource "aws_secretsmanager_secret_rotation" "rds" {
  secret_id           = aws_secretsmanager_secret.rds.id
  rotation_lambda_arn = aws_lambda_function.rotate_rds.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

**Rotation Lambda** (AWS-provided):

1. Creates new password
2. Updates secret with pending label
3. Changes RDS master user password
4. Updates secret with current label
5. Verifies connectivity

### Manual Rotation

Update password manually:

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update RDS
aws rds modify-db-cluster \
  --db-cluster-identifier ecommerce-qa-cluster \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately

# Update secret
aws secretsmanager update-secret \
  --secret-id ecommerce-qa-rds-password \
  --secret-string "{\"username\":\"dbadmin\",\"password\":\"$NEW_PASSWORD\",\"engine\":\"postgres\",\"host\":\"ecommerce-qa-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com\",\"port\":5432,\"dbname\":\"ecommerce\"}"

# Restart ECS tasks to pick up new password
aws ecs update-service \
  --cluster ecommerce-qa-cluster \
  --service ecommerce-qa-api \
  --force-new-deployment
```

### Rotation Best Practices

- Rotate every 30-90 days
- Test rotation in non-production first
- Monitor application logs during rotation
- Ensure application reconnects on auth failure
- Use connection pooling with retry logic

## Versioning

Secrets Manager tracks all versions:

```bash
# List versions
aws secretsmanager list-secret-version-ids \
  --secret-id ecommerce-qa-rds-password

# Get previous version
aws secretsmanager get-secret-value \
  --secret-id ecommerce-qa-rds-password \
  --version-stage AWSPREVIOUS
```

Version stages:
- **AWSCURRENT**: Active version
- **AWSPENDING**: New version during rotation
- **AWSPREVIOUS**: Previous version (rollback)

## Security

### Encryption

All secrets encrypted with KMS:

```hcl
resource "aws_secretsmanager_secret" "rds" {
  name       = "${var.prefix}-${var.env}-rds-password"
  kms_key_id = var.kms_key_id
}
```

### Access Control

Resource policy restricts access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/ecommerce-qa-ecs-task-role"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "*"
    }
  ]
}
```

### Audit Logging

All secret access logged to CloudTrail:

```sql
-- CloudWatch Logs Insights query
fields @timestamp, userIdentity.principalId, eventName, requestParameters.secretId
| filter eventSource = "secretsmanager.amazonaws.com"
| filter eventName = "GetSecretValue"
| sort @timestamp desc
```

Monitor for:
- Unauthorized access attempts
- Excessive GetSecretValue calls
- Unexpected IP addresses

## Cost

- **Secret storage**: $0.40/secret/month
- **API calls**: $0.05/10,000 calls
- **Typical cost**: ~$1/month for 2 secrets with moderate API usage

Example:
- 2 secrets: 2 × $0.40 = $0.80
- 10,000 API calls: 10,000 / 10,000 × $0.05 = $0.05
- **Total**: $0.85/month

## Optimization

### Caching Secrets

Reduce API calls with caching:

```javascript
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager({ region: 'us-east-1' });

let cachedSecrets = {};
const CACHE_TTL = 300000; // 5 minutes

async function getSecret(secretId) {
  const now = Date.now();
  
  if (cachedSecrets[secretId] && now - cachedSecrets[secretId].timestamp < CACHE_TTL) {
    return cachedSecrets[secretId].value;
  }
  
  const data = await secretsManager.getSecretValue({ SecretId: secretId }).promise();
  const secret = JSON.parse(data.SecretString);
  
  cachedSecrets[secretId] = {
    value: secret,
    timestamp: now
  };
  
  return secret;
}
```

Reduces API calls by 90%+.

## Maintenance

### Update Secret Value

```bash
# Update RDS password
aws secretsmanager put-secret-value \
  --secret-id ecommerce-qa-rds-password \
  --secret-string '{"username":"dbadmin","password":"NewPassword789!","engine":"postgres","host":"...","port":5432,"dbname":"ecommerce"}'

# Force ECS task refresh
aws ecs update-service \
  --cluster ecommerce-qa-cluster \
  --service ecommerce-qa-api \
  --force-new-deployment
```

### Delete Secret

30-day recovery window:

```bash
# Schedule deletion
aws secretsmanager delete-secret \
  --secret-id ecommerce-qa-rds-password \
  --recovery-window-in-days 30

# Cancel deletion
aws secretsmanager restore-secret \
  --secret-id ecommerce-qa-rds-password

# Force immediate deletion (dangerous)
aws secretsmanager delete-secret \
  --secret-id ecommerce-qa-rds-password \
  --force-delete-without-recovery
```

### Replicate Secret to Another Region

For disaster recovery:

```bash
aws secretsmanager replicate-secret-to-regions \
  --secret-id ecommerce-qa-rds-password \
  --add-replica-regions Region=us-west-2
```

## Troubleshooting

### Access Denied

1. Verify IAM role has `secretsmanager:GetSecretValue` permission
2. Check KMS key policy allows `kms:Decrypt`
3. Confirm secret ARN correct
4. Review resource policy on secret

### Secret Not Found

1. Verify secret name/ARN
2. Check correct AWS region
3. Confirm secret not deleted
4. List secrets:
   ```bash
   aws secretsmanager list-secrets
   ```

### Application Connection Failed After Rotation

1. Check new password in secret matches database
2. Verify application refreshes secret value
3. Review application connection retry logic
4. Rollback to previous version:
   ```bash
   # Promote AWSPREVIOUS to AWSCURRENT
   aws secretsmanager update-secret-version-stage \
     --secret-id ecommerce-qa-rds-password \
     --version-stage AWSCURRENT \
     --remove-from-version-id <new-version-id> \
     --move-to-version-id <previous-version-id>
   ```

## Best Practices

- Never hardcode credentials in code or environment variables
- Use secrets injection in ECS tasks
- Enable automatic rotation for databases
- Cache secrets in application (5-10 minutes TTL)
- Monitor CloudTrail for unauthorized access
- Use resource policies for fine-grained access
- Replicate critical secrets to DR region
- Tag secrets for cost allocation
- Document rotation procedures
- Test secret rotation in staging first
- Set up CloudWatch alarms for failed GetSecretValue calls

## Dependencies

- KMS module (encryption)

## Used By

- RDS module (database authentication)
- ElastiCache module (Redis authentication)
- Compute module (ECS tasks retrieve credentials)
- Bastion module (administrative database access)

All services requiring authenticated access to RDS or Redis.
