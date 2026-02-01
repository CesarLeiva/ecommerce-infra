# CloudTrail Module

Creates audit logging for all AWS API calls across the account with centralized S3 storage and CloudWatch integration.

## Purpose

Records all API activity for security analysis, compliance, troubleshooting, and forensics.

## Resources Created

- CloudTrail trail (multi-region)
- S3 bucket for trail logs
- S3 bucket policy for CloudTrail write access
- CloudWatch Log Group for real-time analysis
- IAM role for CloudWatch Logs delivery
- KMS encryption for logs

## Usage

```hcl
module "cloudtrail" {
  source = "./modules/cloudtrail"

  prefix = "ecommerce"
  env    = "qa"
  
  kms_key_id           = module.kms.kms_key_id
  logs_bucket_id       = module.logs_bucket.bucket_id
  enable_log_validation = true
  enable_cloudwatch     = true
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Resource prefix | string | - |
| env | Environment | string | - |
| kms_key_id | KMS key for encryption | string | - |
| logs_bucket_id | S3 bucket for CloudTrail logs | string | - |
| enable_log_validation | Enable log file integrity validation | bool | true |
| enable_cloudwatch | Send logs to CloudWatch | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| trail_arn | CloudTrail ARN |
| trail_id | Trail ID |
| cloudwatch_log_group | CloudWatch Log Group name |

## What Gets Logged

### API Calls Tracked

- **IAM**: User/role creation, permission changes, login attempts
- **EC2**: Instance launch/termination, security group changes, VPC modifications
- **RDS**: Database creation, snapshot restore, parameter changes
- **S3**: Bucket creation, policy changes, object deletion (with data events)
- **ECS**: Task launch, service updates, cluster changes
- **Lambda**: Function invocation, configuration updates
- **CloudFormation/Terraform**: Stack operations, resource changes
- **All other AWS services**

### Event Types

- **Management Events**: Control plane operations (create, delete, modify)
- **Data Events**: Data plane operations (S3 object access, Lambda executions) - optional, higher cost

## Log Structure

### S3 Storage Path

```
s3://ecommerce-qa-logs/cloudtrail/
  AWSLogs/
    123456789012/           # Account ID
      CloudTrail/
        us-east-1/          # Region
          2026/
            01/
              15/
                123456789012_CloudTrail_us-east-1_20260115T0000Z_abc123.json.gz
```

### Log File Format

Each event includes:

```json
{
  "eventVersion": "1.08",
  "userIdentity": {
    "type": "IAMUser",
    "principalId": "AIDAI...",
    "arn": "arn:aws:iam::123456789012:user/admin",
    "accountId": "123456789012",
    "accessKeyId": "AKIAI...",
    "userName": "admin"
  },
  "eventTime": "2026-01-15T10:30:00Z",
  "eventSource": "rds.amazonaws.com",
  "eventName": "CreateDBCluster",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "203.0.113.50",
  "userAgent": "aws-cli/2.9.0",
  "requestParameters": {
    "dBClusterIdentifier": "ecommerce-qa-cluster",
    "engine": "aurora-postgresql"
  },
  "responseElements": {
    "dBClusterArn": "arn:aws:rds:us-east-1:123456789012:cluster:ecommerce-qa-cluster"
  },
  "requestID": "abc-123-def-456",
  "eventID": "unique-event-id",
  "eventType": "AwsApiCall",
  "recipientAccountId": "123456789012"
}
```

## Querying Logs

### CloudWatch Logs Insights

Real-time queries (last 7 days):

```sql
-- Recent RDS changes
fields @timestamp, userIdentity.userName, eventName, requestParameters
| filter eventSource = "rds.amazonaws.com"
| sort @timestamp desc
| limit 20

-- Security group modifications
fields @timestamp, userIdentity.userName, requestParameters.groupId, requestParameters.ipPermissions
| filter eventName like /AuthorizeSecurityGroup/
| sort @timestamp desc

-- Failed API calls
fields @timestamp, userIdentity.userName, eventName, errorCode, errorMessage
| filter errorCode exists
| sort @timestamp desc
| limit 50

-- IAM changes
fields @timestamp, userIdentity.userName, eventName, requestParameters
| filter eventSource = "iam.amazonaws.com"
| sort @timestamp desc
```

### Athena Queries

For historical analysis (all logs in S3):

1. Create Athena table:

```sql
CREATE EXTERNAL TABLE cloudtrail_logs (
  eventversion STRING,
  useridentity STRUCT<
    type:STRING,
    principalid:STRING,
    arn:STRING,
    accountid:STRING,
    username:STRING
  >,
  eventtime STRING,
  eventsource STRING,
  eventname STRING,
  awsregion STRING,
  sourceipaddress STRING,
  useragent STRING,
  requestparameters STRING,
  responseelements STRING
)
ROW FORMAT SERDE 'com.amazon.emr.hive.serde.CloudTrailSerde'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://ecommerce-qa-logs/cloudtrail/AWSLogs/123456789012/CloudTrail/';
```

2. Query events:

```sql
-- API calls from specific user
SELECT eventtime, eventsource, eventname, sourceipaddress
FROM cloudtrail_logs
WHERE useridentity.username = 'admin'
  AND eventtime > '2026-01-01'
ORDER BY eventtime DESC
LIMIT 100;

-- Failed login attempts
SELECT eventtime, useridentity.username, sourceipaddress, errorcode
FROM cloudtrail_logs
WHERE eventname = 'ConsoleLogin'
  AND errorcode IS NOT NULL
ORDER BY eventtime DESC;

-- Resource deletions
SELECT eventtime, useridentity.username, eventname, requestparameters
FROM cloudtrail_logs
WHERE eventname LIKE '%Delete%'
  AND eventtime > '2026-01-01'
ORDER BY eventtime DESC;
```

## Security Analysis

### Detect Suspicious Activity

Monitor for:

1. **Unusual API calls**: Actions not normally performed
2. **Failed authorizations**: Potential unauthorized access attempts
3. **Resource deletions**: Especially from unfamiliar IPs
4. **IAM changes**: New users, roles, or permission escalation
5. **Security group changes**: Opening ports to 0.0.0.0/0

CloudWatch Logs metric filter example:

```hcl
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "RootAccountUsage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name
  pattern        = '{ $.userIdentity.type = "Root" }'

  metric_transformation {
    name      = "RootAccountUsageCount"
    namespace = "CloudTrail"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_usage" {
  alarm_name          = "RootAccountUsed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsageCount"
  namespace           = "CloudTrail"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Root account was used"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

## Compliance

CloudTrail helps meet compliance requirements:

- **PCI DSS**: Logging requirement 10.x
- **HIPAA**: Audit controls
- **SOC 2**: Activity monitoring
- **GDPR**: Access logging

Enable log file validation for tamper detection:

```hcl
enable_log_file_validation = true
```

Validates with digital signature that log files haven't been modified.

## Cost Optimization

### Costs

- **CloudTrail**: First trail free, additional trails $2/month
- **S3 storage**: $0.023/GB/month (compressed logs)
- **CloudWatch Logs**: $0.50/GB ingested, $0.03/GB stored
- **Typical monthly cost**: ~$5-15 depending on API volume

### Reduce Costs

1. **Disable CloudWatch for low-value events**:
   ```hcl
   enable_cloudwatch = false  # Query S3 with Athena instead
   ```

2. **Lifecycle policy on S3 logs**:
   ```hcl
   # Delete logs older than 1 year
   lifecycle_rule {
     enabled = true
     expiration {
       days = 365
     }
   }
   ```

3. **Filter CloudWatch to critical events only**:
   Update CloudWatch Logs filter to exclude read-only events.

## Maintenance

### Verify Trail Active

```bash
aws cloudtrail get-trail-status --name ecommerce-qa-trail
```

Output should show:
```json
{
  "IsLogging": true,
  "LatestDeliveryTime": 1642247100.0,
  "LatestCloudWatchLogsDeliveryTime": 1642247100.0
}
```

### Check Recent Events

```bash
aws cloudtrail lookup-events --max-results 10
```

### Review Log Delivery Errors

```bash
aws cloudtrail get-trail-status --name ecommerce-qa-trail \
  | jq '.LatestDeliveryError'
```

## Troubleshooting

### Logs Not Appearing in S3

1. Check trail status (IsLogging: true)
2. Verify S3 bucket policy allows CloudTrail write
3. Check KMS key policy allows CloudTrail encryption

### CloudWatch Logs Not Receiving Events

1. Verify IAM role has logs:CreateLogStream and logs:PutLogEvents permissions
2. Check CloudWatch log group exists
3. Review CloudTrail configuration for CloudWatch ARN

### High Costs

1. Review CloudWatch Logs ingestion volume
2. Consider disabling CloudWatch (use Athena for queries)
3. Implement S3 lifecycle policy
4. Filter out high-volume low-value events

## Dependencies

- KMS module (log encryption)
- Logs Bucket module (S3 storage)

## Used By

Security teams, compliance auditors, incident response for forensic analysis.
