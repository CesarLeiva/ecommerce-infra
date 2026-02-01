# ===================================
# CloudTrail
# ===================================
resource "aws_cloudtrail" "main" {
  name                          = "${var.prefix}-${var.env}-trail"
  s3_bucket_name                = var.s3_bucket_name
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = var.include_global_service_events
  is_multi_region_trail         = var.is_multi_region_trail
  enable_logging                = var.enable_logging
  enable_log_file_validation    = var.enable_log_file_validation
  kms_key_id                    = var.kms_key_arn

  # Event selectors for data events
  dynamic "event_selector" {
    for_each = var.enable_s3_data_events || var.enable_lambda_data_events ? [1] : []
    content {
      read_write_type           = var.read_write_type
      include_management_events = var.include_management_events

      # S3 data events
      dynamic "data_resource" {
        for_each = var.enable_s3_data_events ? [1] : []
        content {
          type   = "AWS::S3::Object"
          values = ["arn:aws:s3:::*/"]
        }
      }

      # Lambda data events
      dynamic "data_resource" {
        for_each = var.enable_lambda_data_events ? [1] : []
        content {
          type   = "AWS::Lambda::Function"
          values = ["arn:aws:lambda"]
        }
      }
    }
  }

  # CloudWatch Logs integration (optional)
  cloud_watch_logs_group_arn = var.cloudwatch_log_group_arn != "" ? "${var.cloudwatch_log_group_arn}:*" : null
  cloud_watch_logs_role_arn  = var.cloudwatch_log_group_arn != "" ? var.cloudwatch_logs_role_arn : null

  tags = {
    Name        = "${var.prefix}-${var.env}-trail"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# CloudWatch Log Group (Optional)
# ===================================
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/cloudtrail/${var.prefix}-${var.env}"
  retention_in_days = var.cloudwatch_retention_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.prefix}-${var.env}-cloudtrail-logs"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# IAM Role for CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.prefix}-${var.env}-cloudtrail-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-cloudtrail-cloudwatch-role"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.prefix}-${var.env}-cloudtrail-cloudwatch-policy"
  role  = aws_iam_role.cloudtrail_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
      }
    ]
  })
}
