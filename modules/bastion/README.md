# Bastion Host Module

Creates EC2 instance for secure SSH access to private resources (RDS, Redis, private ECS tasks).

## Purpose

Provides jump server for database administration, debugging, and maintenance tasks in private subnets.

## Resources Created

- EC2 instance (t3.micro)
- Security group (SSH inbound, all outbound)
- IAM instance profile for Session Manager
- CloudWatch log group
- Elastic IP (optional)

## Usage

```hcl
module "bastion" {
  source = "./modules/bastion"

  prefix = "ecommerce"
  env    = "qa"
  
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnets[0]
  instance_type     = "t3.micro"
  key_name          = "my-keypair"
  allowed_ssh_cidrs = ["203.0.113.0/24"]  # Your office IP
  
  kms_key_id = module.kms.kms_key_id
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Resource prefix | string | - |
| env | Environment | string | - |
| vpc_id | VPC ID | string | - |
| subnet_id | Public subnet ID | string | - |
| instance_type | EC2 instance type | string | t3.micro |
| key_name | SSH key pair name | string | - |
| allowed_ssh_cidrs | CIDR blocks for SSH | list(string) | [] |
| kms_key_id | KMS key for encryption | string | - |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | Bastion instance ID |
| public_ip | Public IP address |
| security_group_id | Security group ID |

## Access Methods

### 1. SSH with Key Pair

Create key pair before deployment:

```bash
# Generate key pair
aws ec2 create-key-pair \
  --key-name ecommerce-bastion \
  --query 'KeyMaterial' \
  --output text > ecommerce-bastion.pem

chmod 400 ecommerce-bastion.pem
```

Connect:

```bash
ssh -i ecommerce-bastion.pem ec2-user@<public-ip>
```

### 2. Session Manager (No Key Pair Needed)

Recommended for enhanced security (no open SSH port, session logging).

```bash
aws ssm start-session --target <instance-id>
```

Requirements:
- AWS CLI with Session Manager plugin
- IAM user with ssm:StartSession permission

Install plugin:

```bash
# Windows
choco install awscli-session-manager

# macOS
brew install --cask session-manager-plugin

# Linux
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
sudo yum install -y session-manager-plugin.rpm
```

## Installed Tools

Bastion comes pre-installed with:

- **PostgreSQL Client** (psql) - RDS database access
- **Redis CLI** (redis-cli) - ElastiCache access
- **MySQL Client** - alternative database support
- **curl, wget** - HTTP testing
- **telnet, nc** - network debugging
- **dig, nslookup** - DNS troubleshooting
- **CloudWatch Logs Agent** - session logging

## Common Tasks

### Connect to RDS Database

```bash
# Get credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id ecommerce-qa-rds-password \
  --query SecretString \
  --output text

# Connect to writer
psql -h ecommerce-qa-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com \
     -U dbadmin \
     -d ecommerce

# Connect to reader (if enabled)
psql -h ecommerce-qa-cluster.cluster-ro-xxxxx.us-east-1.rds.amazonaws.com \
     -U dbadmin \
     -d ecommerce
```

### Connect to Redis

```bash
# Get password
REDIS_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id ecommerce-qa-redis-password \
  --query SecretString \
  --output text)

# Connect with TLS
redis-cli -h ecommerce-qa-redis.xxxxx.cache.amazonaws.com \
          -p 6379 \
          --tls \
          -a "$REDIS_PASSWORD"

# Test connection
redis-cli> PING
PONG

# View keys
redis-cli> KEYS *

# Get value
redis-cli> GET session:abc123
```

### Test ECS Service Endpoints

```bash
# Internal ALB health check
curl http://internal-ecommerce-qa-alb-xxx.us-east-1.elb.amazonaws.com/health

# Specific backend service
curl http://internal-ecommerce-qa-alb-xxx.us-east-1.elb.amazonaws.com/api/products
```

### Debug DNS

```bash
# Check internal DNS
dig ecommerce-qa-cluster.cluster-xxxxx.us-east-1.rds.amazonaws.com

# Verify VPC DNS resolver
nslookup internal-ecommerce-qa-alb-xxx.us-east-1.elb.amazonaws.com
```

### Run Database Migrations

```bash
# Download migration scripts
aws s3 cp s3://my-migrations/v1.0.sql .

# Execute migration
psql -h <rds-endpoint> -U dbadmin -d ecommerce -f v1.0.sql

# Verify
psql -h <rds-endpoint> -U dbadmin -d ecommerce -c "SELECT version FROM schema_migrations;"
```

## Security Considerations

### SSH Access Restriction

Limit SSH to known IPs only:

```hcl
bastion_allowed_ssh_cidrs = ["203.0.113.50/32"]  # Single office IP
```

Avoid `0.0.0.0/0` in production.

### Session Logging

All Session Manager sessions logged to CloudWatch:

```bash
# View session logs
aws logs tail /aws/ssm/ecommerce-qa-bastion --follow
```

### Key Management

- Store `.pem` file securely (encrypted folder, password manager)
- Never commit to version control
- Rotate keys periodically
- Use Session Manager instead when possible

### Instance Hardening

Bastion includes:
- Automatic security updates
- Disabled password authentication
- Minimal installed packages
- CloudWatch monitoring

## Maintenance

### Update Bastion

Replace instance to get latest AMI:

```bash
terraform taint module.bastion.aws_instance.bastion
terraform apply -var-file="environments/qa.tfvars"
```

### Resize Instance

For heavy workload (large DB exports):

```hcl
bastion_instance_type = "t3.small"  # Upgrade from t3.micro
```

### Start/Stop to Save Costs

Bastion not needed 24/7:

```bash
# Stop when not in use
aws ec2 stop-instances --instance-ids <instance-id>

# Start when needed
aws ec2 start-instances --instance-ids <instance-id>

# Get new public IP after start
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

Stopped instances cost ~$0.10/month (EBS volume), running costs ~$7.50/month.

### Assign Elastic IP

For static IP (optional, +$3.60/month):

```hcl
resource "aws_eip" "bastion" {
  domain   = "vpc"
  instance = aws_instance.bastion.id
  tags     = { Name = "${var.prefix}-${var.env}-bastion-eip" }
}
```

## Troubleshooting

### Cannot SSH

1. Verify security group allows your IP:
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

2. Check instance state:
   ```bash
   aws ec2 describe-instances --instance-ids <instance-id>
   ```

3. Verify key pair:
   ```bash
   aws ec2 describe-key-pairs --key-names ecommerce-bastion
   ```

4. Use Session Manager as fallback

### Session Manager Connection Failed

1. Verify IAM role attached to instance
2. Check SSM agent running:
   ```bash
   ssh -i key.pem ec2-user@<ip>
   sudo systemctl status amazon-ssm-agent
   ```

3. Ensure instance has internet access (NAT Gateway)

### Database Connection Timeout

1. Verify bastion in correct VPC
2. Check RDS security group allows bastion SG
3. Verify database endpoint correct:
   ```bash
   aws rds describe-db-clusters --db-cluster-identifier ecommerce-qa-cluster
   ```

## Cost

- **t3.micro instance**: $0.0104/hour × 730 hours = $7.59/month
- **EBS volume** (8 GB): $0.10/GB/month = $0.80/month
- **Data transfer**: Usually minimal (<$1/month)
- **Total**: ~$8.50/month (24/7), ~$0.10/month (stopped when not needed)

## Dependencies

- VPC module (subnet, security groups)
- KMS module (EBS encryption)
- RDS module (database to access)
- ElastiCache module (Redis to access)

## Used By

Database administrators, DevOps engineers, support teams for troubleshooting and maintenance.
