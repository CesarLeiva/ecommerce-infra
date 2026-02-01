# Estimación de Costos Mensuales - Infraestructura Ecommerce

## Configuración Actual (us-east-1)

### Networking (~$82/mes)
- **NAT Gateway**: $0.045/hora × 730h = $32.40/mes
- **NAT Gateway Data Transfer**: ~$20/mes (estimado con tráfico moderado)
- **VPC Flow Logs (S3)**: ~$15/mes (millones de registros)
- **Data Transfer OUT**: ~$15/mes
- Subtotal: **$82/mes**

### Compute (~$76/mes)
- **ECS Fargate (ARM64)**: 2 tareas × (1 vCPU + 2GB RAM + 20GB storage)
  - vCPU: $0.03238/vCPU/hora × 2 × 730h = $47.27/mes
  - Memoria: $0.00356/GB/hora × 4GB × 730h = $10.39/mes
  - Storage: $0.000111/GB/hora × 40GB × 730h = $3.24/mes
- **ECR**: ~50GB storage × $0.10/GB = $5/mes
- **Bastion (t3.micro)**: $0.0104/hora × 730h + 20GB EBS = $9.19/mes
- Subtotal: **$76/mes**

### Database (~$505/mes) - On-Demand Pricing with Read Replica
- **RDS Aurora PostgreSQL (db.r6g.large)**:
  - Writer instance: $0.29/hora × 730h = $211.70/mes
  - Reader instance (read replica): $0.29/hora × 730h = $211.70/mes
  - Storage: 100GB × $0.10/GB = $10/mes
  - I/O requests: ~$20/mes
  - Backup storage: 50GB × $0.021/GB = $1.05/mes
- **ElastiCache Redis (cache.t3.medium)**:
  - Instance: $0.068/hora × 730h = $49.64/mes
  - Backup: 10GB × $0.085/GB = $0.85/mes
- Subtotal: **$505/mes** (on-demand, includes writer + reader instances)

### Storage & CDN (~$36/mes)
- **S3**:
  - Logs bucket: 500GB × $0.023/GB = $11.50/mes
  - Frontend bucket: 10GB × $0.023/GB = $0.23/mes
  - Requests: ~$2/mes
- **CloudFront**:
  - Requests: ~$5/mes
  - Data Transfer OUT: 100GB × $0.085/GB = $8.50/mes
  - Invalidations: ~$1/mes
- Subtotal: **$36/mes**

### Load Balancing (~$28/mes)
- **ALB**: $0.0225/hora × 730h = $16.43/mes
- **LCU**: ~2 LCUs × $5.76/LCU = $11.52/mes
- Subtotal: **$28/mes**

### Security (~$53/mes)
- **WAF**:
  - 2 Web ACLs × $5/mes = $10/mes
  - 12 rules (6 per ACL) × $1/mes = $12/mes
  - Requests: ~$10/mes
- **Kinesis Firehose (WAF logs)**: 2 streams × ~$7.50/mes = $15/mes
- **KMS**: $1/mes + requests ~$3/mes = $4/mes
- **Secrets Manager**: 3 secrets × $0.40/mes + API calls = $2/mes
- Subtotal: **$53/mes**

### Monitoring (~$37/mes)
- **CloudWatch**:
  - Logs ingestion: 10GB × $0.50/GB = $5/mes
  - Logs storage: 10GB × $0.03/GB = $0.30/mes
  - Custom metrics: 100 × $0.30 = $30/mes
  - Alarms: 20 × $0.10 = $2/mes
- **SNS**: Gratis (email notifications)
- Subtotal: **$37/mes**

---

## TOTAL ESTIMADO MENSUAL: **~$817/mes**

### Desglose por Categoría:
1. **Database**: $505/mes (62%) - on-demand with writer + reader instances
2. **Networking**: $82/mes (10%)
3. **Compute**: $76/mes (9%)
4. **Security**: $53/mes (7%)
5. **Monitoring**: $37/mes (5%)
6. **Storage & CDN**: $36/mes (4%)
7. **Load Balancing**: $28/mes (3%)

### Notas:
- Costos basados en precios de AWS us-east-1 (febrero 2026)
- Estimaciones asumen tráfico moderado (~100GB/mes egress, 1M requests/mes)
- CloudTrail deshabilitado (enable_cloudtrail=false)
- Costos pueden variar según uso real
- No incluye costos de transferencia de datos entre AZs (~1-2% adicional)
- Sugerencia: Considerar Reserved Instances para RDS (ahorro ~40% = $169/mes)
