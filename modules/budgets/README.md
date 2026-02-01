# AWS Budgets Module

Creates cost monitoring budgets with configurable alert thresholds for overall and category-specific spending.

## Purpose

Tracks AWS spending and sends alerts at configurable percentage thresholds to prevent cost overruns.

## Resources Created

- SNS topic for budget alerts
- Email subscriptions
- 4 budgets: Overall, Database, Compute, Storage
- Dynamic notifications based on threshold list

## Usage

```hcl
module "budgets" {
  source = "./modules/budgets"

  prefix    = "ecommerce"
  env       = "qa"
  kms_key_id = module.kms.kms_key_id
  alert_emails = ["finance@example.com"]

  overall_monthly_limit  = 850
  database_monthly_limit = 510
  compute_monthly_limit  = 80
  storage_monthly_limit  = 40
  alert_thresholds       = [50, 80, 100, 150, 200]
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| alert_emails | Email addresses for alerts | list(string) | [] |
| overall_monthly_limit | Overall spending limit | number | - |
| database_monthly_limit | Database category limit | number | - |
| compute_monthly_limit | Compute category limit | number | - |
| storage_monthly_limit | Storage category limit | number | - |
| alert_thresholds | Alert percentages | list(number) | [50, 80, 100, 150, 200] |

## Budgets Created

### 1. Overall Budget

Tracks total AWS spending across all services.

### 2. Database Budget

Tracks:
- Amazon RDS (PostgreSQL)
- Amazon ElastiCache (Redis)

### 3. Compute Budget

Tracks:
- Amazon ECS (Fargate tasks)
- Amazon ECR (Container Registry)
- Amazon EC2 (Bastion, NAT Gateway)

### 4. Storage Budget

Tracks:
- Amazon S3 (Frontend, Logs)
- Amazon CloudFront (CDN)

## Alert Thresholds

Default thresholds trigger notifications at:
- **50%**: Early warning
- **80%**: Attention required
- **100%**: Budget exceeded
- **150%**: Significant overspend
- **200%**: Critical overspend

Customize in `qa.tfvars`:

```hcl
budget_alert_thresholds = [25, 50, 75, 100, 125]  # More frequent alerts
budget_alert_thresholds = [100, 200]               # Minimal alerts
```

## Notification Email Format

```
Subject: AWS Budget Notification - ecommerce-qa-database-monthly-budget

Your budget ecommerce-qa-database-monthly-budget for AWS account 123456789012 
has exceeded 80% of your budgeted amount.

Budget Name: ecommerce-qa-database-monthly-budget
Threshold: 80%
Budget Amount: $510.00
Actual Spend: $425.30
Forecasted Spend: $520.00

Time Period: February 1, 2026 - February 28, 2026
```

## Cost Optimization Actions

### When 50% Alert Received

- Review current spending in Cost Explorer
- Identify unexpected increases
- Verify resource usage is expected

### When 80% Alert Received

- Analyze top spending services
- Review Reserved Instance opportunities
- Check for unused resources
- Verify auto-scaling limits

### When 100% Alert Exceeded

**Immediate Actions**:

1. **Stop Non-Essential Resources**:
   ```bash
   # Stop bastion if not needed
   aws ec2 stop-instances --instance-ids <bastion-id>
   
   # Scale down ECS to minimum
   aws ecs update-service --cluster ecommerce-qa-cluster --service ecommerce-qa-api --desired-count 2
   ```

2. **Review Database**:
   - Disable reader replica temporarily
   - Reduce instance size
   - Check for slow queries causing high CPU

3. **Check WAF Logs**:
   - Excessive logging can increase costs
   - Verify not under attack (high traffic = high costs)

4. **Investigate Unexpected Services**:
   ```bash
   aws ce get-cost-and-usage \
     --time-period Start=2026-02-01,End=2026-02-28 \
     --granularity DAILY \
     --metrics UnblendedCost \
     --group-by Type=SERVICE
   ```

## Budget Timeframe

Budgets run on monthly cycle:
- Start: 1st day of month 00:00 UTC
- End: Last day of month 23:59 UTC
- Resets automatically each month

## Email Subscription

After deployment, confirm subscription:

1. Check inbox for "AWS Budget Notification - Subscription Confirmation"
2. Click "Confirm subscription"
3. Starts receiving budget alerts

Add additional subscribers:

```hcl
budget_alert_emails = [
  "finance@example.com",
  "cto@example.com",
  "ops@example.com"
]
```

## Cost Analysis

### View Current Spending

```bash
# Overall costs this month
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost

# By service
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=SERVICE
```

### Forecast Spending

AWS Budget automatically forecasts month-end spending based on current trends.

## Adjusting Budgets

Update limits in `qa.tfvars`:

```hcl
overall_monthly_budget  = 1000  # Increased from 850
database_monthly_budget = 600   # Increased from 510
```

Apply changes:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

## Reserved Instances Impact

Purchasing Reserved Instances reduces effective costs:

**Example**: RDS Reserved Instance (writer + reader)
- On-demand: $505/month (with read replica enabled)
- 1-year RI: $300/month (40% savings)
- Adjust database budget to $300

## Budget Costs

- AWS Budgets: First 2 budgets free, then $0.02/day per budget
- 4 budgets: ~$1.20/month (2 free + 2 × $0.60)
- SNS notifications: Included in free tier

## Troubleshooting

### Not Receiving Alerts

1. Verify email subscription confirmed
2. Check SNS topic subscriptions:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn <topic-arn>
   ```
3. Check spam folder

### False Alerts

If alerts trigger incorrectly:

1. Verify budget amounts match expected costs
2. Check if temporary spike (e.g., migration, testing)
3. Review Cost Explorer for accuracy

### Multiple Alerts

Receiving many alerts in short time:
- Indicates rapid cost increase
- Immediate investigation required
- May indicate runaway resources or attack

## Best Practices

- Set budgets 10-15% above estimated costs for buffer
- Review and adjust budgets quarterly
- Monitor Cost Explorer weekly
- Use tags for cost allocation
- Enable Cost Anomaly Detection in AWS Console
- Purchase Reserved Instances for predictable workloads
- Review and terminate unused resources monthly

## Integration with Cost Explorer

Budget alerts should trigger Cost Explorer review:

1. AWS Console → Cost Management → Cost Explorer
2. Filter by service or tag
3. Compare to previous months
4. Identify anomalies

## Dependencies

- KMS module (SNS topic encryption)

## Used By

Finance, operations, and management teams for cost control.
