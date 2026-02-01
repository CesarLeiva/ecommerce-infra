# ===================================
# S3 Bucket for Centralized Logs
# ===================================

# Get AWS account ID for unique bucket naming
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.prefix}-${var.env}-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.prefix}-${var.env}-logs"
    Environment = var.env
    Purpose     = "Centralized Logs"
    ManagedBy   = "Terraform"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  # CloudTrail logs lifecycle
  rule {
    id     = "cloudtrail-logs-lifecycle"
    status = var.cloudtrail_enabled ? "Enabled" : "Disabled"

    filter {
      prefix = "cloudtrail/"
    }

    transition {
      days          = var.cloudtrail_transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.cloudtrail_transition_to_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.cloudtrail_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # VPC Flow Logs lifecycle
  rule {
    id     = "vpc-flow-logs-lifecycle"
    status = var.vpc_flow_logs_enabled ? "Enabled" : "Disabled"

    filter {
      prefix = "vpc-flow-logs/"
    }

    transition {
      days          = var.vpc_flow_logs_transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.vpc_flow_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  # WAF logs lifecycle
  rule {
    id     = "waf-logs-lifecycle"
    status = var.waf_enabled ? "Enabled" : "Disabled"

    filter {
      prefix = "waf/"
    }

    transition {
      days          = var.waf_transition_to_ia_days
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = var.waf_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# ===================================
# S3 Bucket Policy
# ===================================
data "aws_region" "current" {}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudTrail permissions
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # VPC Flow Logs permissions
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.logs.arn
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/vpc-flow-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # WAF logs permissions (Kinesis Firehose delivery)
      {
        Sid    = "AWSWAFLogsWrite"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/waf/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}
