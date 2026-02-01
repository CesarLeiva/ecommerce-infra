# Frontend Module

Deploys static frontend assets to S3 with CloudFront CDN distribution for global content delivery and HTTPS access.

## Purpose

Hosts single-page application (React, Vue, Angular) or static website with SSL/TLS, caching, and global edge delivery.

## Resources Created

- S3 bucket for static assets
- S3 bucket policy for CloudFront access
- CloudFront distribution with custom domain
- CloudFront Origin Access Identity (OAI)
- Route53 DNS record (A alias)
- WAF Web ACL for CloudFront (optional)

## Usage

```hcl
module "frontend" {
  source = "./modules/frontend"

  prefix = "ecommerce"
  env    = "qa"
  
  domain_name             = "qa.ecommerce.com"
  acm_certificate_arn     = module.acm.certificate_arn
  route53_zone_id         = module.route53.zone_id
  enable_waf              = true
  waf_web_acl_id          = module.waf.cloudfront_waf_acl_id
  kms_key_id              = module.kms.kms_key_id
  cloudfront_price_class  = "PriceClass_100"
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| domain_name | Custom domain | string | - |
| acm_certificate_arn | ACM certificate ARN (us-east-1) | string | - |
| route53_zone_id | Route53 hosted zone ID | string | - |
| enable_waf | Attach WAF to CloudFront | bool | false |
| waf_web_acl_id | WAF Web ACL ID | string | null |
| cloudfront_price_class | Price class for edge locations | string | PriceClass_100 |

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | S3 bucket name |
| cloudfront_distribution_id | CloudFront distribution ID |
| cloudfront_domain_name | CloudFront domain |
| website_url | Full HTTPS URL |

## Architecture

```
User Request (https://qa.ecommerce.com)
          ↓
    Route53 DNS
          ↓
    WAF (optional) → Block malicious requests
          ↓
    CloudFront Edge Location (200+ global)
          ↓
    Origin Access Identity (OAI)
          ↓
    S3 Bucket (private, not public)
```

## CloudFront Configuration

### Caching Behavior

- **HTML files**: No cache (always fetch latest)
  - index.html, 404.html
  - Cache-Control: no-cache, no-store, must-revalidate

- **Static assets** (JS, CSS, images): Cache 1 year
  - app.abc123.js, styles.def456.css
  - Cache-Control: public, max-age=31536000, immutable

### Price Classes

Determines edge location availability and cost:

- **PriceClass_100**: US, Canada, Europe (~50 locations, lowest cost)
- **PriceClass_200**: + Asia, Africa, Middle East (~100 locations)
- **PriceClass_All**: All 200+ edge locations (highest cost)

For North American users only:

```hcl
cloudfront_price_class = "PriceClass_100"  # Saves 30-40% vs PriceClass_All
```

### SSL/TLS

Requires ACM certificate in **us-east-1** region (CloudFront requirement):

```bash
# Request certificate in us-east-1
aws acm request-certificate \
  --domain-name qa.ecommerce.com \
  --validation-method DNS \
  --region us-east-1
```

Supported TLS versions: TLSv1.2 and TLSv1.3 only (secure, modern browsers).

## Deployment

### Initial Build and Upload

```bash
# Build frontend application
cd frontend-app
npm run build

# Upload to S3
aws s3 sync ./dist s3://ecommerce-qa-frontend --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E1234ABCD5678 \
  --paths "/*"
```

### CI/CD Deployment

GitHub Actions workflow (see [CI/CD module](../cicd/README.md)):

```yaml
- name: Build Frontend
  run: npm run build
  working-directory: ./frontend

- name: Deploy to S3
  run: |
    aws s3 sync ./frontend/dist s3://${{ secrets.FRONTEND_BUCKET }} --delete
  env:
    AWS_REGION: us-east-1

- name: Invalidate CloudFront
  run: |
    aws cloudfront create-invalidation \
      --distribution-id ${{ secrets.CLOUDFRONT_ID }} \
      --paths "/*"
```

### Asset Versioning

Use content hashing in filenames for cache busting:

```javascript
// webpack.config.js or vite.config.js
output: {
  filename: '[name].[contenthash].js',
  chunkFilename: '[name].[contenthash].js'
}
```

Generated files:
```
index.html
app.a1b2c3d4.js
styles.e5f6g7h8.css
logo.i9j0k1l2.png
```

CloudFront caches aggressively, but new hash = new file = no cache conflict.

## Custom Error Pages

### 404 Not Found

For single-page apps (React Router, Vue Router):

CloudFront returns index.html for 404 errors:

```hcl
custom_error_response {
  error_code         = 404
  response_code      = 200
  response_page_path = "/index.html"
}
```

Client-side router handles actual routing.

### 403 Forbidden

Also redirect to index.html (S3 returns 403 for missing objects):

```hcl
custom_error_response {
  error_code         = 403
  response_code      = 200
  response_page_path = "/index.html"
}
```

## Performance Optimization

### Enable Compression

CloudFront automatically compresses:
- JavaScript (.js)
- CSS (.css)
- HTML (.html)
- JSON (.json)
- SVG (.svg)

Typical 70% size reduction.

### Viewer Protocol Policy

Redirect HTTP to HTTPS:

```hcl
viewer_protocol_policy = "redirect-to-https"
```

All traffic forced to HTTPS, improving security and SEO.

### Smooth Streaming

Enable for video content (HLS, DASH):

```hcl
smooth_streaming = true
```

## Monitoring

### CloudFront Metrics

CloudWatch metrics (5-minute granularity):

- **Requests**: Total requests per edge location
- **BytesDownloaded**: Data transfer
- **ErrorRate**: 4xx and 5xx error percentage
- **CacheHitRate**: Percentage of requests served from cache (target: >80%)

View metrics:

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=E1234ABCD5678 \
  --start-time 2026-01-15T00:00:00Z \
  --end-time 2026-01-15T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

### Access Logs

Enable for detailed request analysis:

```hcl
logging_config {
  bucket = "ecommerce-qa-logs.s3.amazonaws.com"
  prefix = "cloudfront/"
}
```

Log fields include: timestamp, edge location, bytes, IP, method, host, URI, status, referer, user-agent.

## Security

### S3 Bucket Security

- **Private bucket**: No public access
- **OAI**: Only CloudFront can access S3
- **Encryption**: AES-256 with KMS
- **Versioning**: Enabled for rollback

### CloudFront Security Headers

Add security headers via Lambda@Edge or CloudFront Functions:

```javascript
// CloudFront Function
function handler(event) {
  var response = event.response;
  response.headers['strict-transport-security'] = { value: 'max-age=31536000; includeSubDomains' };
  response.headers['x-content-type-options'] = { value: 'nosniff' };
  response.headers['x-frame-options'] = { value: 'DENY' };
  response.headers['x-xss-protection'] = { value: '1; mode=block' };
  return response;
}
```

### WAF Protection

When `enable_waf = true`, CloudFront protected by:
- Rate limiting
- SQL injection blocking
- XSS filtering
- Geo-blocking
- Bot detection

See [WAF module](../waf/README.md) for details.

## Maintenance

### Update Content

Simple sync:

```bash
aws s3 sync ./dist s3://ecommerce-qa-frontend --delete
aws cloudfront create-invalidation --distribution-id E1234ABCD5678 --paths "/*"
```

### Rollback Deployment

S3 versioning enabled, restore previous version:

```bash
# List versions
aws s3api list-object-versions --bucket ecommerce-qa-frontend --prefix index.html

# Restore specific version
aws s3api copy-object \
  --bucket ecommerce-qa-frontend \
  --key index.html \
  --copy-source ecommerce-qa-frontend/index.html?versionId=abc123

# Invalidate
aws cloudfront create-invalidation --distribution-id E1234ABCD5678 --paths "/index.html"
```

### Change Domain

1. Request new ACM certificate in us-east-1
2. Update `domain_name` in tfvars
3. Apply Terraform
4. Update DNS in Route53 (automatic with module)

### Monitor Cache Hit Ratio

Target: >80% cache hit rate

Low cache hit rate indicates:
- Too many unique URLs (query parameters)
- Cache headers preventing caching
- TTL too short

Improve cache:

```javascript
// Set cache headers in build
Cache-Control: public, max-age=31536000, immutable  // Static assets
Cache-Control: no-cache  // HTML files
```

## Cost

### Pricing Components

- **Data transfer out**: $0.085/GB (first 10 TB, US/Europe)
- **HTTPS requests**: $0.0100/10,000 requests
- **Invalidations**: First 1,000 paths/month free, then $0.005/path
- **S3 storage**: $0.023/GB/month
- **WAF** (if enabled): ~$45/month

### Example Monthly Cost

Small site (100 GB transfer, 1M requests):
- Data transfer: 100 GB × $0.085 = $8.50
- HTTPS requests: 1M / 10,000 × $0.01 = $1.00
- S3 storage: 1 GB × $0.023 = $0.02
- **Total**: ~$9.52/month (without WAF)

Medium site (1 TB transfer, 10M requests):
- Data transfer: 1000 GB × $0.085 = $85
- Requests: 10M / 10,000 × $0.01 = $10
- S3 storage: $0.02
- **Total**: ~$95/month (without WAF)

### Cost Optimization

1. **Use appropriate price class**: PriceClass_100 for North America only
2. **Optimize images**: Compress, use WebP format, lazy load
3. **Minimize invalidations**: Use versioned filenames instead
4. **Enable compression**: Reduces data transfer
5. **Review cache hit ratio**: Higher ratio = less origin requests

## Troubleshooting

### 403 Forbidden Error

1. Verify OAI has S3 bucket access
2. Check S3 bucket policy
3. Ensure files exist in S3

### CloudFront Serving Stale Content

Cache invalidation needed:

```bash
aws cloudfront create-invalidation --distribution-id E1234ABCD5678 --paths "/*"
```

Wait 30-60 seconds for propagation.

### Domain Not Resolving

1. Verify Route53 record created
2. Check ACM certificate validated and issued
3. Confirm CloudFront alternate domain names configured
4. Test with dig:
   ```bash
   dig qa.ecommerce.com
   ```

### Slow Performance

1. Check cache hit ratio (should be >80%)
2. Verify using closest edge locations (price class)
3. Enable compression
4. Optimize asset sizes
5. Use HTTP/2 (enabled by default)

## Dependencies

- Route53 module (DNS)
- ACM certificate (us-east-1)
- WAF module (optional, CloudFront protection)
- KMS module (S3 encryption)

## Used By

End users accessing the e-commerce frontend application via web browsers.
