# RDS Aurora PostgreSQL Module

Creates an Aurora PostgreSQL cluster with optional read replica for high availability.

## Purpose

Provides a managed relational database with automated backups, encryption, and optional read scaling.

## Resources Created

- Aurora PostgreSQL cluster
- Writer instance (primary)
- Reader instance (optional)
- DB subnet group
- Cluster parameter group
- DB parameter group
- Security group
- CloudWatch log groups for PostgreSQL logs
- Enhanced monitoring IAM role

## Usage

```hcl
module "rds" {
  source = "./modules/rds"

  prefix                     = "ecommerce"
  env                        = "qa"
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.data_subnet_ids
  app_security_group_id      = module.compute.security_group_id
  database_name              = "ecommerce"
  master_username            = "postgres"
  master_password_secret_arn = module.secrets.rds_password_secret_arn
  engine_version             = "15.4"
  instance_class             = "db.r6g.large"
  kms_key_arn               = module.kms.kms_key_arn
  enable_reader             = true
  backup_retention_period   = 7
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| database_name | Database name | string | - |
| master_username | Master username | string | - |
| master_password_secret_arn | Secrets Manager ARN | string | - |
| engine_version | PostgreSQL version | string | "15.4" |
| instance_class | Instance type | string | - |
| parameter_group_family | Parameter group family | string | - |
| enable_reader | Create read replica | bool | false |
| backup_retention_period | Backup retention days | number | 7 |
| preferred_backup_window | Backup window | string | "03:00-04:00" |
| preferred_maintenance_window | Maintenance window | string | "sun:04:00-sun:05:00" |
| skip_final_snapshot | Skip final snapshot | bool | false |
| deletion_protection | Enable deletion protection | bool | true |
| monitoring_interval | Enhanced monitoring interval | number | 60 |
| enable_performance_insights | Enable Performance Insights | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | Cluster identifier |
| cluster_identifier | Cluster identifier (alias) |
| cluster_endpoint | Writer endpoint |
| cluster_reader_endpoint | Reader endpoint |
| cluster_port | Database port |
| cluster_arn | Cluster ARN |
| security_group_id | Security group ID |

## Instance Types

### Graviton2 (ARM64) - Recommended
- **db.r6g.large**: 2 vCPU, 16 GiB RAM (~$0.288/hour)
- **db.r6g.xlarge**: 4 vCPU, 32 GiB RAM (~$0.576/hour)
- **db.r6g.2xlarge**: 8 vCPU, 64 GiB RAM (~$1.152/hour)

### x86-64 Alternative
- **db.r5.large**: 2 vCPU, 16 GiB RAM (~$0.34/hour)
- **db.m5.large**: 2 vCPU, 8 GiB RAM (~$0.17/hour)

Use Graviton2 (r6g) for better price/performance with ARM64 ECS tasks.

## High Availability

### Read Replica

When `enable_reader = true`:
- Second instance in different AZ
- Automatic failover in <30 seconds
- Read-only endpoint for query offloading
- Synchronous replication from writer

### Multi-AZ Deployment

Cluster spans multiple availability zones:
- Writer in one AZ
- Reader in different AZ
- Automatic failover to reader on writer failure

## Backup Strategy

### Automated Backups

- Daily backups during backup window
- Retention: 7-35 days (configurable)
- Point-in-time recovery to any second within retention period
- Stored in S3 (encrypted)

### Manual Snapshots

Create manual snapshot:

```bash
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier ecommerce-qa-aurora-cluster \
  --db-cluster-snapshot-identifier manual-snapshot-$(date +%Y%m%d)
```

### Final Snapshot

On cluster deletion, final snapshot is created (unless `skip_final_snapshot = true`).

## Security

### Encryption

- **At Rest**: AES-256 encryption using KMS
- **In Transit**: SSL/TLS enforced via parameter group
- **Backup Encryption**: Automatic with same KMS key

### Network Isolation

- Deployed in data subnets (no internet access)
- Security group allows traffic only from application tier
- No public endpoint

### Password Management

Master password stored in AWS Secrets Manager:
- Encrypted with KMS
- Automatic rotation (optional)
- Retrieved by applications at runtime

## Monitoring

### CloudWatch Metrics

- **CPUUtilization**: CPU usage percentage
- **DatabaseConnections**: Active connections
- **FreeableMemory**: Available RAM
- **ReadLatency**: Read operation latency
- **WriteLatency**: Write operation latency
- **AuroraReplicaLag**: Replication lag (reader)

### Enhanced Monitoring

Enabled by default (60-second granularity):
- OS-level metrics
- Process activity
- File system usage

### Performance Insights

Enabled by default:
- Query performance analysis
- Wait event analysis
- Database load monitoring
- 7-day data retention (free tier)

### Logs

PostgreSQL logs exported to CloudWatch:
- Error logs
- Slow query logs
- General logs (if enabled)

## Connection

### From ECS Tasks

Use cluster endpoint for read/write operations:

```javascript
const connectionString = `postgresql://${username}:${password}@${endpoint}:5432/${database}`;
```

Retrieve credentials from Secrets Manager:

```javascript
const secret = await secretsmanager.getSecretValue({ SecretId: 'rds-password' }).promise();
const { username, password } = JSON.parse(secret.SecretString);
```

### From Bastion

```bash
# Retrieve password
aws secretsmanager get-secret-value --secret-id ecommerce-qa-rds-password \
  --query SecretString --output text | jq -r .password

# Connect
psql -h ecommerce-qa-aurora-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com \
     -U postgres -d ecommerce
```

## Maintenance

### Version Upgrades

Minor version upgrades automatic if `auto_minor_version_upgrade = true`.

For major version upgrades:

1. Test on snapshot-restored cluster
2. Update `engine_version` in `qa.tfvars`
3. Apply during maintenance window

### Parameter Changes

Static parameters require instance reboot. Dynamic parameters apply immediately.

### Scaling

#### Vertical Scaling (Instance Size)

Update `instance_class` in `qa.tfvars`:

```hcl
rds_instance_class = "db.r6g.xlarge"
```

Causes brief downtime during instance replacement.

#### Horizontal Scaling (Read Replicas)

Enable reader:

```hcl
rds_enable_reader = true
```

Add additional readers by modifying module code (not supported by default).

## Disaster Recovery

### Point-in-Time Restore

Restore to specific timestamp:

```bash
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier ecommerce-qa-aurora-cluster \
  --db-cluster-identifier ecommerce-qa-aurora-restored \
  --restore-to-time 2026-01-01T12:00:00Z
```

### Cross-Region Replication

Not configured by default. To enable:

1. Create replica cluster in secondary region
2. Configure replication from primary
3. Promote replica on disaster

## Cost Optimization

### Reserved Instances

For production, purchase 1-year Reserved Instances:
- db.r6g.large: $0.171/hour (40% savings)
- Annual cost: $1,498 (vs $2,524 on-demand)

### Aurora Serverless Alternative

For variable workloads, consider Aurora Serverless v2:
- Auto-scales based on load
- Pay per ACU (Aurora Capacity Unit)
- No reader replica needed

## Troubleshooting

### High CPU Usage

Check slow queries in Performance Insights. Optimize indexes:

```sql
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema');
```

### Connection Limit Reached

Increase max_connections parameter or check for connection leaks in application.

### Replication Lag

Check `AuroraReplicaLag` metric. Causes:
- Heavy write load
- Long-running transactions
- Large queries on reader

## Dependencies

- VPC module (data subnets)
- Secrets Manager module (master password)
- KMS module (encryption key)
- Compute module security group (network access)

## Used By

- Compute module (database connection)
- Bastion module (administrative access)
- CloudWatch Alarms module (monitoring)
