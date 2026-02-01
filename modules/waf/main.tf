terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ===================================
# IAM Role for Kinesis Firehose
# ===================================
resource "aws_iam_role" "firehose" {
  count = (var.enable_cloudfront_waf && var.enable_cloudfront_waf_logging) || (var.enable_alb_waf && var.enable_alb_waf_logging) ? 1 : 0
  name  = "${var.prefix}-${var.env}-waf-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-waf-firehose-role"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "firehose_s3" {
  count = (var.enable_cloudfront_waf && var.enable_cloudfront_waf_logging) || (var.enable_alb_waf && var.enable_alb_waf_logging) ? 1 : 0
  name  = "${var.prefix}-${var.env}-waf-firehose-s3-policy"
  role  = aws_iam_role.firehose[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# ===================================
# Kinesis Firehose for CloudFront WAF Logs
# ===================================
resource "aws_kinesis_firehose_delivery_stream" "cloudfront_waf" {
  count       = var.enable_cloudfront_waf && var.enable_cloudfront_waf_logging ? 1 : 0
  provider    = aws.us_east_1
  name        = "aws-waf-logs-${var.prefix}-${var.env}-cloudfront"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose[0].arn
    bucket_arn = var.s3_bucket_arn
    prefix     = "waf/cloudfront/"

    buffering_size     = 5
    buffering_interval = 300

    compression_format = "GZIP"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-cloudfront-waf-firehose"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# Kinesis Firehose for ALB WAF Logs
# ===================================
resource "aws_kinesis_firehose_delivery_stream" "alb_waf" {
  count       = var.enable_alb_waf && var.enable_alb_waf_logging ? 1 : 0
  name        = "aws-waf-logs-${var.prefix}-${var.env}-alb"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose[0].arn
    bucket_arn = var.s3_bucket_arn
    prefix     = "waf/alb/"

    buffering_size     = 5
    buffering_interval = 300

    compression_format = "GZIP"
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-alb-waf-firehose"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# WAF Logging Configuration
# ===================================
resource "aws_wafv2_web_acl_logging_configuration" "cloudfront" {
  count                   = var.enable_cloudfront_waf && var.enable_cloudfront_waf_logging ? 1 : 0
  provider                = aws.us_east_1
  resource_arn            = aws_wafv2_web_acl.cloudfront[0].arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.cloudfront_waf[0].arn]
}

resource "aws_wafv2_web_acl_logging_configuration" "alb" {
  count                   = var.enable_alb_waf && var.enable_alb_waf_logging ? 1 : 0
  resource_arn            = aws_wafv2_web_acl.alb[0].arn
  log_destination_configs = [aws_kinesis_firehose_delivery_stream.alb_waf[0].arn]
}

# ===================================
# WAF Web ACL for CloudFront
# ===================================
resource "aws_wafv2_web_acl" "cloudfront" {
  count    = var.enable_cloudfront_waf ? 1 : 0
  provider = aws.us_east_1

  name  = "${var.prefix}-${var.env}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rule 1: Geo-blocking - Only allow Colombia and USA
  rule {
    name     = "geo-restriction"
    priority = 0

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["CO", "US"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-geo-restriction"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed - Common Rule Set
  rule {
    name     = "aws-managed-common-rules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed - SQL Injection Protection
  rule {
    name     = "aws-managed-sqli-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: AWS Managed - Known Bad Inputs
  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: AWS Managed - IP Reputation List
  rule {
    name     = "aws-managed-ip-reputation"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: AWS Managed - Bot Control
  rule {
    name     = "aws-managed-bot-control"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesBotControlRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-bot-control"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.prefix}-${var.env}-cloudfront-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-cloudfront-waf"
    Environment = var.env
    Scope       = "CloudFront"
    ManagedBy   = "Terraform"
  }
}

# ===================================
# WAF Web ACL for ALB (Regional)
# ===================================
resource "aws_wafv2_web_acl" "alb" {
  count = var.enable_alb_waf ? 1 : 0

  name  = "${var.prefix}-${var.env}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Geo-blocking - Only allow Colombia and USA
  rule {
    name     = "geo-restriction"
    priority = 0

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["CO", "US"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-alb-geo-restriction"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed - Common Rule Set
  rule {
    name     = "aws-managed-common-rules"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-alb-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed - SQL Injection Protection
  rule {
    name     = "aws-managed-sqli-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-alb-sqli-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: AWS Managed - Known Bad Inputs
  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-alb-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: AWS Managed - IP Reputation List
  rule {
    name     = "aws-managed-ip-reputation"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-alb-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: AWS Managed - Bot Control
  rule {
    name     = "aws-managed-bot-control"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesBotControlRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-${var.env}-alb-bot-control"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.prefix}-${var.env}-alb-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.prefix}-${var.env}-alb-waf"
    Environment = var.env
    Scope       = "Regional"
    ManagedBy   = "Terraform"
  }
}
