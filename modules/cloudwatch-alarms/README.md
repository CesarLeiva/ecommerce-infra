# CloudWatch Alarms Module

Creates comprehensive monitoring and alerting for services, database, and security events.

## Purpose

Detects and alerts on service health issues, performance degradation, and security incidents.

## Resources Created

- SNS topic for alarm notifications
- Email subscriptions
- ECS service alarms (CPU, memory, task count)
- ALB target health alarms
- RDS cluster alarms (CPU, connections, memory, replica lag)
- WAF attack detection alarms

## Usage

```hcl
module "cloudwatch_alarms" {
  source = "./modules/cloudwatch-alarms"

  prefix      = "ecommerce"
  env         = "qa"
  kms_key_id  = module.kms.kms_key_id
  alarm_emails = ["ops@example.com"]

  # ECS Alarms
  enable_ecs_alarms = true
  ecs_cluster_name  = module.ecs_cluster.cluster_name
  ecs_services      = { for k, v in var.services : k => {
    name               = module.compute[k].service_name
    target_group_arn_suffix = module.compute[k].target_group_arn_suffix
  }}
  ecs_cpu_threshold    = 80
  ecs_memory_threshold = 80
  min_running_tasks    = 1

  # RDS Alarms
  enable_rds_alarms     = true
  rds_cluster_id        = module.rds.db_instance_identifier
  has_rds_reader        = var.rds_enable_reader
  rds_cpu_threshold     = 80
  
  # WAF Alarms
  enable_waf_cloudfront_alarms = var.enable_waf_cloudfront
  waf_cloudfront_web_acl_name  = module.waf.cloudfront_waf_acl_name
}
```

## Alarms Created

### ECS Service Alarms (per service)

1. **High CPU**: CPU > threshold for 2 consecutive periods
2. **High Memory**: Memory > threshold for 2 consecutive periods
3. **Low Task Count**: Running tasks < minimum for 1 period

### ALB Target Alarms (per service)

1. **Unhealthy Targets**: Any unhealthy target for 1 period
2. **High Response Time**: Average response > threshold for 2 periods

### RDS Cluster Alarms

1. **High CPU**: CPU > 80% for 2 consecutive periods
2. **High Connections**: Connections > threshold for 2 periods
3. **Low Memory**: Freeable memory < threshold for 2 periods
4. **Replica Lag**: Lag > 1000ms for 2 periods (if reader enabled)

### WAF Attack Alarms

1. **High Blocked Requests**: >1000 blocked in 5 minutes
2. **High Block Rate**: >50% of requests blocked

## Notification Flow

```
Alarm Triggers → SNS Topic → Email Subscribers
```

Email format:
```
Subject: ALARM: "ecommerce-qa-api-high-cpu" in US East (N. Virginia)

Alarm Details:
- Name: ecommerce-qa-api-high-cpu  
- Description: ECS service CPU utilization is too high
- State: ALARM
- Reason: Threshold Crossed: 1 datapoint [85.0] was greater than the threshold (80.0)
- Timestamp: 2026-01-15 10:30:00 UTC
```

## Email Subscription

After deployment, subscribers receive confirmation email:

1. Check inbox for "AWS Notification - Subscription Confirmation"
2. Click "Confirm subscription" link
3. Confirmations expires in 3 days

Reconfirm if needed:

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:ecommerce-qa-alarms \
  --protocol email \
  --notification-endpoint ops@example.com
```

## Alarm States

- **OK**: Metric within threshold
- **ALARM**: Metric breached threshold
- **INSUFFICIENT_DATA**: Not enough data points

## Thresholds Configuration

Adjust in `qa.tfvars`:

```hcl
# ECS thresholds
ecs_cpu_threshold              = 80
ecs_memory_threshold           = 80
min_running_tasks              = 2
target_response_time_threshold = 2

# RDS thresholds
rds_cpu_threshold              = 80
rds_connections_threshold      = 80
rds_freeable_memory_threshold  = 1
rds_replica_lag_threshold      = 1000

# WAF thresholds
waf_blocked_requests_threshold = 1000
waf_block_rate_threshold       = 50
```

## Monitoring Best Practices

### Alarm Fatigue Prevention

- Set realistic thresholds based on baseline metrics
- Use consecutive period checks (prevents brief spikes)
- Adjust thresholds after initial deployment based on actual usage

### Escalation

For critical alarms, integrate with PagerDuty, OpsGenie, or similar:

1. Create webhook endpoint in on-call tool
2. Subscribe to SNS topic:

```bash
aws sns subscribe \
  --topic-arn <topic-arn> \
  --protocol https \
  --notification-endpoint https://events.pagerduty.com/integration/<key>/enqueue
```

### Alarm Actions

Beyond email, configure auto-remediation:

```hcl
# Example: Auto-scale on high CPU
alarm_actions = [
  aws_sns_topic.alarms.arn,
  aws_autoscaling_policy.scale_up.arn
]
```

## Viewing Alarms

### AWS Console

CloudWatch → Alarms → View all alarms

### CLI

```bash
# List all alarms
aws cloudwatch describe-alarms

# Get alarm history
aws cloudwatch describe-alarm-history --alarm-name ecommerce-qa-api-high-cpu

# Get current state
aws cloudwatch describe-alarms --alarm-names ecommerce-qa-api-high-cpu
```

## Troubleshooting Alarms

### ECS High CPU/Memory

1. Check CloudWatch Logs for application errors
2. Review recent deployments
3. Analyze Performance Insights for database queries
4. Scale up tasks or increase task resources

### ALB Unhealthy Targets

1. Verify ECS tasks are running
2. Check task logs for startup errors
3. Test health check endpoint manually
4. Review security group rules

### RDS High CPU

1. Enable Performance Insights
2. Identify expensive queries
3. Add database indexes
4. Consider read replica for read-heavy workloads

### WAF Attack Detection

1. Review WAF logs for attack patterns
2. Identify source IPs
3. Add additional blocking rules if needed
4. Consider AWS Shield Advanced for large DDoS

## Alarm Costs

- SNS notifications: First 1,000 email notifications/month free, then $2/100,000
- CloudWatch alarms: $0.10/alarm/month
- Total for ~15 alarms: ~$1.50/month

## Maintenance

### Add New Alarm

Edit `modules/cloudwatch-alarms/main.tf`:

```hcl
resource "aws_cloudwatch_metric_alarm" "new_alarm" {
  alarm_name          = "${var.prefix}-${var.env}-new-metric"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MetricName"
  namespace           = "AWS/Service"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Description"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}
```

### Modify Email Subscribers

Update `qa.tfvars`:

```hcl
alarm_emails = ["ops@example.com", "oncall@example.com"]
```

Apply changes:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### Silence Alarms Temporarily

Disable alarm actions during maintenance:

```bash
aws cloudwatch disable-alarm-actions --alarm-names ecommerce-qa-api-high-cpu
```

Re-enable after maintenance:

```bash
aws cloudwatch enable-alarm-actions --alarm-names ecommerce-qa-api-high-cpu
```

## Dependencies

- KMS module (SNS topic encryption)
- ECS Cluster and Compute modules (service metrics)
- ALB module (target health metrics)
- RDS module (database metrics)
- WAF module (blocked request metrics)

## Used By

Operations and on-call teams for incident response.
