# ElastiCache Redis Module

Creates a managed Redis cluster for caching and session storage.

## Purpose

Provides in-memory data store for application caching, session management, and real-time features.

## Resources Created

- ElastiCache Redis replication group (single node or cluster)
- Subnet group
- Parameter group
- Security group
- CloudWatch log groups (slow log, engine log)

## Usage

```hcl
module "elasticache" {
  source = "./modules/elasticache"

  prefix                  = "ecommerce"
  env                     = "qa"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.data_subnet_ids
  app_security_group_id   = module.compute.security_group_id
  node_type               = "cache.t3.medium"
  num_cache_nodes         = 1
  engine_version          = "7.0"
  parameter_group_family  = "redis7"
  kms_key_arn            = module.kms.kms_key_arn
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| node_type | Cache node instance type | string | - |
| num_cache_nodes | Number of cache nodes | number | 1 |
| engine_version | Redis engine version | string | "7.0" |
| parameter_group_family | Parameter group family | string | "redis7" |
| at_rest_encryption_enabled | Enable encryption at rest | bool | true |
| transit_encryption_enabled | Enable encryption in transit | bool | false |
| automatic_failover_enabled | Enable automatic failover | bool | false |
| multi_az_enabled | Enable Multi-AZ | bool | false |
| snapshot_retention_limit | Snapshot retention days | number | 5 |
| snapshot_window | Daily snapshot time window | string | "05:00-06:00" |
| maintenance_window | Weekly maintenance window | string | "sun:06:00-sun:07:00" |

## Outputs

| Name | Description |
|------|-------------|
| redis_endpoint | Primary endpoint address |
| redis_port | Redis port (6379) |
| redis_arn | Replication group ARN |
| security_group_id | Security group ID |

## Node Types

### For Development

- **cache.t3.micro**: 0.5 GB RAM (~$12/month)
- **cache.t3.small**: 1.5 GB RAM (~$24/month)
- **cache.t3.medium**: 3.2 GB RAM (~$49/month)

### For Production

- **cache.r6g.large**: 13.07 GB RAM (~$127/month, Graviton2)
- **cache.r6g.xlarge**: 26.32 GB RAM (~$254/month)
- **cache.m6g.large**: 6.38 GB RAM (~$73/month)

## High Availability

### Single Node (Default)

- One Redis node
- No automatic failover
- Downtime during maintenance
- Suitable for development

### Cluster Mode

Enable with:

```hcl
num_cache_nodes            = 2
automatic_failover_enabled = true
multi_az_enabled          = true
```

Features:
- Primary node in one AZ
- Replica node in different AZ
- Automatic failover in ~60 seconds
- Read replica for scaling

## Encryption

### At Rest

Enabled by default using KMS:
- Data encrypted on disk
- Snapshots encrypted
- No performance impact

### In Transit

Disabled by default (adds latency):

```hcl
transit_encryption_enabled = true
```

Requires:
- Redis clients support SSL/TLS
- Connection string with `tls://` prefix
- Slightly higher latency

## Backup Strategy

### Automatic Snapshots

- Daily during snapshot window
- Retention: 5 days (configurable)
- Stored in S3
- No performance impact

### Manual Snapshots

Create manual snapshot:

```bash
aws elasticache create-snapshot \
  --replication-group-id ecommerce-qa-redis \
  --snapshot-name manual-backup-$(date +%Y%m%d)
```

## Security

### Network Isolation

- Deployed in data subnets
- No public endpoint
- Security group allows access from application tier only

### Password Authentication

Stored in AWS Secrets Manager:

```bash
aws secretsmanager get-secret-value --secret-id ecommerce-qa-redis-password
```

### Encryption

- KMS encryption at rest
- Optional TLS encryption in transit

## Connection

### From ECS Tasks

Retrieve credentials and connect:

```javascript
const redis = require('redis');
const AWS = require('aws-sdk');

const secretsManager = new AWS.SecretsManager();
const secret = await secretsManager.getSecretValue({ 
  SecretId: 'ecommerce-qa-redis-password' 
}).promise();

const { password } = JSON.parse(secret.SecretString);

const client = redis.createClient({
  host: 'ecommerce-qa-redis.xxxxx.cache.amazonaws.com',
  port: 6379,
  password: password
});
```

### From Bastion

```bash
# Install redis-cli
sudo amazon-linux-extras install redis6

# Connect
redis-cli -h ecommerce-qa-redis.xxxxx.cache.amazonaws.com -a $(aws secretsmanager get-secret-value --secret-id ecommerce-qa-redis-password --query SecretString --output text | jq -r .password)
```

## Monitoring

### CloudWatch Metrics

- **CPUUtilization**: CPU usage
- **FreeableMemory**: Available memory
- **NetworkBytesIn/Out**: Network throughput
- **CurrConnections**: Active connections
- **Evictions**: Items evicted due to memory pressure
- **CacheHits/Misses**: Cache hit ratio

### Logs

Two log streams in CloudWatch:
- **Slow Log**: Commands exceeding threshold
- **Engine Log**: Redis server events

## Common Use Cases

### Session Storage

```javascript
// Store session
await client.setex(`session:${userId}`, 3600, JSON.stringify(sessionData));

// Retrieve session
const session = await client.get(`session:${userId}`);
```

### Application Caching

```javascript
// Check cache
let data = await client.get('products:list');

if (!data) {
  // Cache miss - fetch from database
  data = await fetchFromDatabase();
  
  // Store in cache for 1 hour
  await client.setex('products:list', 3600, JSON.stringify(data));
}
```

### Rate Limiting

```javascript
const key = `ratelimit:${userId}:${endpoint}`;
const count = await client.incr(key);

if (count === 1) {
  await client.expire(key, 60); // 1 minute window
}

if (count > 100) {
  throw new Error('Rate limit exceeded');
}
```

## Maintenance

### Version Upgrades

Update `engine_version` in `qa.tfvars`:

```hcl
elasticache_engine_version = "7.2"
```

Apply during maintenance window.

### Scaling

#### Vertical (Node Size)

Update `node_type`:

```hcl
elasticache_node_type = "cache.r6g.large"
```

Causes brief downtime during node replacement.

#### Horizontal (Add Replicas)

Increase `num_cache_nodes`:

```hcl
elasticache_num_cache_nodes        = 2
elasticache_automatic_failover_enabled = true
elasticache_multi_az_enabled          = true
```

## Performance Tuning

### Memory Management

Monitor `FreeableMemory` metric. If low:

1. Increase node size
2. Implement eviction policy
3. Review data expiration times

### Connection Pooling

Use connection pooling in applications:

```javascript
const redis = require('redis');
const { promisify } = require('util');

const pool = redis.createClient({
  host: REDIS_HOST,
  port: 6379,
  password: REDIS_PASSWORD,
  retry_strategy: (options) => {
    if (options.total_retry_time > 1000 * 60) {
      return new Error('Retry time exhausted');
    }
    return Math.min(options.attempt * 100, 3000);
  }
});
```

### Eviction Policies

Configure in parameter group:
- **allkeys-lru**: Evict least recently used keys
- **volatile-lru**: Evict LRU among keys with TTL
- **allkeys-lfu**: Evict least frequently used
- **noeviction**: Return errors when memory full

## Disaster Recovery

### Restore from Snapshot

```bash
aws elasticache create-replication-group \
  --replication-group-id ecommerce-qa-redis-restored \
  --snapshot-name manual-backup-20260101 \
  --cache-node-type cache.t3.medium
```

### Cross-Region Backup

Snapshots are region-specific. For disaster recovery:

1. Copy snapshots to secondary region
2. Restore in secondary region if needed

## Cost Optimization

### Reserved Nodes

Purchase 1-year Reserved Instances for production:
- cache.t3.medium: $20/month (60% savings)
- cache.r6g.large: $51/month (60% savings)

### Right-Sizing

Monitor memory usage. If consistently below 50%, downsize node type.

## Troubleshooting

### High CPU Usage

Causes:
- Expensive commands (KEYS, SMEMBERS on large sets)
- Insufficient node size
- Too many concurrent connections

Solutions:
- Use SCAN instead of KEYS
- Increase node type
- Implement connection pooling

### High Evictions

Causes:
- Insufficient memory
- No expiration on keys
- Memory leak in application

Solutions:
- Increase node size
- Set TTL on all cached data
- Review application caching logic

### Connection Timeouts

Causes:
- Security group misconfiguration
- Network latency
- Redis server overloaded

Solutions:
- Verify security groups allow port 6379
- Check application subnet routing
- Monitor CPU and memory metrics

## Dependencies

- VPC module (data subnets)
- KMS module (encryption)
- Secrets Manager module (password)
- Compute module security group (network access)

## Used By

- Compute module (application connection)
- Bastion module (administrative access)
- CloudWatch Alarms module (monitoring)
