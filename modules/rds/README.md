# RDS PostgreSQL Module

Creates an RDS PostgreSQL instance with optional read replica for high availability.

## Purpose

Provides a managed relational database with automated backups, encryption, and optional read scaling.

## Resources Created

- RDS PostgreSQL instance (primary)
- Read replica instance (optional)
- DB subnet group
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
  engine_version             = "15.8"
  instance_class             = "db.r6g.large"
  allocated_storage          = 100
  storage_type               = "gp3"
  multi_az                   = false
  kms_key_arn               = module.kms.kms_key_arn
  enable_reader             = false
  backup_retention_period   = 7
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| database_name | Database name | string | - |
| master_username | Master username | string | - |
| master_password_secret_arn | Secrets Manager ARN | string | - |
| engine_version | PostgreSQL version | string | "15.8" |
| instance_class | Instance type | string | - |
| parameter_group_family | Parameter group family | string | - |
| allocated_storage | Allocated storage in GB | number | - |
| storage_type | Storage type (gp3, gp2, io1, io2) | string | "gp3" |
| iops | Provisioned IOPS (io1/io2 only) | number | null |
| multi_az | Enable Multi-AZ deployment | bool | false |
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
| db_instance_id | Instance identifier |
| db_instance_identifier | Instance identifier (alias) |
| db_instance_endpoint | Connection endpoint (host:port) |
| db_instance_address | Instance address (hostname) |
| db_instance_port | Database port |
| db_instance_arn | Instance ARN |
| replica_id | Read replica identifier (if enabled) |
| replica_endpoint | Read replica endpoint (if enabled) |
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

## Storage Types

### General Purpose SSD (gp3) - Recommended
- **Baseline**: 3,000 IOPS, 125 MB/s throughput
- **Configurable**: Up to 16,000 IOPS, 1,000 MB/s
- **Cost**: ~$0.115/GB-month
- **Use case**: Most workloads

### General Purpose SSD (gp2)
- **IOPS**: 3 IOPS per GB (100-16,000 IOPS)
- **Cost**: ~$0.115/GB-month
- **Use case**: Legacy applications

### Provisioned IOPS SSD (io1/io2)
- **IOPS**: Up to 64,000 IOPS (io1), 256,000 IOPS (io2)
- **Cost**: ~$0.125/GB-month + $0.10/IOPS-month
- **Use case**: I/O intensive workloads

## High Availability

### Multi-AZ Deployment

When `multi_az = true`:
- Standby instance in different AZ
- Automatic failover in 1-2 minutes
- Synchronous replication to standby
- Same endpoint after failover
- Higher cost (~2x instance price)

### Read Replica

When `enable_reader = true`:
- Separate read-only instance
- Asynchronous replication from primary
- Different endpoint for read traffic
- Can be in same or different AZ
- Does NOT provide automatic failover
- Can be manually promoted to standalone instance

**Note**: Multi-AZ and Read Replica serve different purposes:
- **Multi-AZ**: High availability and disaster recovery
- **Read Replica**: Read scaling and workload distribution

## Backup and Recovery

### Automated Backups

- Daily snapshots during backup window
- Transaction logs backed up every 5 minutes
- Point-in-time recovery (PITR) to any second
- Retention: 1-35 days (default: 7)

### Manual Snapshots

```bash
# Create snapshot
aws rds create-db-snapshot \
  --db-instance-identifier ecommerce-qa-postgres \
  --db-snapshot-identifier ecommerce-qa-manual-backup-$(date +%Y%m%d)

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier ecommerce-qa-postgres

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier ecommerce-qa-postgres-restored \
  --db-snapshot-identifier ecommerce-qa-manual-backup-20260115
```

### Point-in-Time Recovery

```bash
# Restore to specific time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier ecommerce-qa-postgres \
  --target-db-instance-identifier ecommerce-qa-postgres-pitr \
  --restore-time 2026-01-15T12:00:00Z

# Restore to latest restorable time
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier ecommerce-qa-postgres \
  --target-db-instance-identifier ecommerce-qa-postgres-latest \
  --use-latest-restorable-time
```

## Performance Optimization

### Performance Insights

When enabled (`enable_performance_insights = true`):
- 7-day retention (free tier)
- Query-level performance metrics
- Wait event analysis
- Database load monitoring

Access via AWS Console → RDS → Performance Insights

### Enhanced Monitoring

- OS-level metrics (CPU, memory, disk I/O)
- Process list
- 1-60 second granularity (default: 60)
- CloudWatch Logs integration

### Parameter Tuning

Common PostgreSQL parameters in parameter group:

```hcl
rds_instance_parameters = [
  {
    name  = "shared_buffers"
    value = "{DBInstanceClassMemory/32768}"  # 25% of RAM
  },
  {
    name  = "max_connections"
    value = "200"
  },
  {
    name  = "work_mem"
    value = "16384"  # 16 MB
  },
  {
    name  = "maintenance_work_mem"
    value = "524288"  # 512 MB
  },
  {
    name  = "effective_cache_size"
    value = "{DBInstanceClassMemory/10922}"  # 75% of RAM
  }
]
```

## Security

### Encryption

- **At Rest**: KMS encryption for storage, snapshots, and replicas
- **In Transit**: SSL/TLS enforced via parameter group

### Network Isolation

- Private subnets only (no public access)
- Security group restricts access to application tier
- VPC endpoints for AWS service communication

### Access Control

```bash
# Connect from bastion host
psql -h <db-instance-endpoint> -U postgres -d ecommerce

# Verify SSL connection
psql -h <db-instance-endpoint> -U postgres -d ecommerce -c "SHOW ssl;"
```

## Monitoring

### CloudWatch Metrics

Key metrics:
- **CPUUtilization**: CPU usage percentage
- **DatabaseConnections**: Active connections
- **FreeableMemory**: Available RAM
- **ReadLatency/WriteLatency**: I/O latency
- **ReadThroughput/WriteThroughput**: Disk throughput
- **ReadIOPS/WriteIOPS**: I/O operations per second

### Logs

PostgreSQL logs exported to CloudWatch:
- `postgresql.log`: General database activity
- Query errors and slow queries

View logs:
```bash
aws logs tail /aws/rds/instance/ecommerce-qa-postgres/postgresql --follow
```

## Maintenance

### Maintenance Window

- Default: Sunday 04:00-05:00 UTC
- Engine updates applied automatically (if enabled)
- Minor version upgrades: automatic
- Major version upgrades: manual only

### Version Upgrades

```bash
# Check available versions
aws rds describe-db-engine-versions \
  --engine postgres \
  --engine-version 15.8

# Modify instance version
aws rds modify-db-instance \
  --db-instance-identifier ecommerce-qa-postgres \
  --engine-version 16.2 \
  --apply-immediately
```

## Cost Optimization

### Recommendations

1. **Right-size instances**: Monitor CPU/Memory, downsize if consistently low
2. **Use gp3 storage**: Better performance than gp2 at same price
3. **Optimize backup retention**: Balance between cost and recovery needs
4. **Disable Multi-AZ in non-prod**: Use read replica instead if high availability not critical
5. **Delete unused snapshots**: Manual snapshots accumulate storage costs
6. **Use Reserved Instances**: 1-year commitment saves ~30%, 3-year saves ~60%

### Cost Breakdown (db.r6g.large, 100 GB gp3, Multi-AZ disabled)

- Instance: ~$208/month (on-demand)
- Storage: ~$12/month (100 GB gp3)
- Backups: ~$12/month (100 GB, 7-day retention)
- **Total**: ~$232/month

With Multi-AZ enabled: ~$440/month

## Troubleshooting

### Connection Issues

```bash
# Test network connectivity
telnet <db-endpoint> 5432

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids <rds-security-group-id>

# Verify instance status
aws rds describe-db-instances \
  --db-instance-identifier ecommerce-qa-postgres
```

### Performance Issues

1. Check CPU/Memory metrics in CloudWatch
2. Review slow query log
3. Analyze Performance Insights for top queries
4. Check for missing indexes
5. Review connection pool settings

### Common Errors

**Error**: "too many connections"
- **Solution**: Increase `max_connections` parameter or optimize connection pooling

**Error**: "out of memory"
- **Solution**: Reduce `work_mem` or upgrade instance class

**Error**: "disk full"
- **Solution**: Enable storage autoscaling or increase `allocated_storage`

## Migration from Aurora

If migrating from Aurora PostgreSQL to RDS PostgreSQL:

1. **Export Aurora data**:
```bash
pg_dump -h <aurora-endpoint> -U postgres -d ecommerce -f dump.sql
```

2. **Import to RDS**:
```bash
psql -h <rds-endpoint> -U postgres -d ecommerce -f dump.sql
```

3. **Update application connection strings**
4. **Test application thoroughly**
5. **Decommission Aurora cluster**

**Note**: This migration will incur downtime. Plan maintenance window accordingly.

## References

- [Amazon RDS for PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/15/index.html)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [RDS Pricing](https://aws.amazon.com/rds/postgresql/pricing/)
