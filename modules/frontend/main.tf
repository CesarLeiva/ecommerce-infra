# ===================================
# S3 Bucket for Frontend Static Files
# ===================================
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.prefix}-${var.env}-frontend"

  tags = {
    Name        = "${var.prefix}-${var.env}-frontend"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# Block public access (CloudFront will access via OAC)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle configuration for old versions
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ===================================
# CloudFront Origin Access Control
# ===================================
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.prefix}-${var.env}-frontend-oac"
  description                       = "OAC for ${var.prefix}-${var.env} frontend"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ===================================
# S3 Bucket Policy for CloudFront
# ===================================
data "aws_cloudfront_distribution" "frontend" {
  id = aws_cloudfront_distribution.frontend.id
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# ===================================
# CloudFront Distribution
# ===================================
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.prefix}-${var.env} frontend distribution"
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = var.domain_name != "" ? [var.domain_name, "www.${var.domain_name}"] : []
  web_acl_id          = var.waf_web_acl_arn

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true

    # Security headers for React SPA
    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }
  }

  # Custom error responses for React SPA routing
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL/TLS configuration
  viewer_certificate {
    cloudfront_default_certificate = var.domain_name == "" ? true : false
    acm_certificate_arn            = var.domain_name != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-frontend-cdn"
    Environment = var.env
    ManagedBy   = "Terraform"
  }

  lifecycle {
    ignore_changes = [viewer_certificate[0].minimum_protocol_version]
  }

  depends_on = [aws_cloudfront_function.security_headers]
}

# ===================================
# CloudFront Function for Security Headers
# ===================================
resource "aws_cloudfront_function" "security_headers" {
  name    = "${var.prefix}-${var.env}-security-headers"
  runtime = "cloudfront-js-1.0"
  comment = "Add security headers for React SPA"
  publish = true

  code = <<-EOT
    function handler(event) {
      var response = event.response;
      var headers = response.headers;
      
      // Security headers
      headers['strict-transport-security'] = { value: 'max-age=31536000; includeSubDomains; preload' };
      headers['x-content-type-options'] = { value: 'nosniff' };
      headers['x-frame-options'] = { value: 'DENY' };
      headers['x-xss-protection'] = { value: '1; mode=block' };
      headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
      headers['permissions-policy'] = { value: 'geolocation=(), microphone=(), camera=()' };
      
      // Content Security Policy for React
      headers['content-security-policy'] = { 
        value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://*; frame-ancestors 'none';" 
      };
      
      return response;
    }
  EOT
}

# ===================================
# Cache Invalidation (Optional)
# ===================================
# This resource is created but not triggered automatically
# Use AWS CLI or CI/CD to invalidate cache after deployments:
# aws cloudfront create-invalidation --distribution-id <ID> --paths "/*"
