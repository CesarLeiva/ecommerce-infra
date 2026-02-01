# ===================================
# OIDC Provider for GitHub Actions
# ===================================
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]

  tags = {
    Name        = "${var.prefix}-${var.env}-github-oidc"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# IAM Role for GitHub Actions
# ===================================

resource "aws_iam_role" "github_actions" {
  name = "${var.prefix}-${var.env}-github-actions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.github_repositories : "repo:${repo}:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-github-actions-role"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# IAM Policy for ECR Access
# ===================================
resource "aws_iam_policy" "ecr_access" {
  name        = "${var.prefix}-${var.env}-github-ecr-policy"
  description = "Policy for GitHub Actions to push images to ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRGetAuthorizationToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPullImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = var.ecr_repository_arns
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-github-ecr-policy"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# IAM Policy for ECS Deployment
# ===================================
resource "aws_iam_policy" "ecs_deploy" {
  name        = "${var.prefix}-${var.env}-github-ecs-policy"
  description = "Policy for GitHub Actions to deploy to ECS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSDescribeServices"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:ListTaskDefinitions"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSRegisterTaskDefinition"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSUpdateService"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService"
        ]
        Resource = var.ecs_service_arns
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.ecs_task_role_arns
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-github-ecs-policy"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# IAM Policy for S3 Frontend Deployment
# ===================================
resource "aws_iam_policy" "s3_frontend" {
  count       = var.enable_frontend_deploy ? 1 : 0
  name        = "${var.prefix}-${var.env}-github-s3-policy"
  description = "Policy for GitHub Actions to deploy frontend to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3FrontendAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:PutObjectAcl"
        ]
        Resource = [
          var.frontend_bucket_arn,
          "${var.frontend_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-github-s3-policy"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# IAM Policy for CloudFront Invalidation
# ===================================
resource "aws_iam_policy" "cloudfront_invalidation" {
  count       = var.enable_frontend_deploy ? 1 : 0
  name        = "${var.prefix}-${var.env}-github-cloudfront-policy"
  description = "Policy for GitHub Actions to invalidate CloudFront cache"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation",
          "cloudfront:ListInvalidations"
        ]
        Resource = var.cloudfront_distribution_arn
      }
    ]
  })

  tags = {
    Name        = "${var.prefix}-${var.env}-github-cloudfront-policy"
    Environment = var.env
    ManagedBy   = "Terraform"
  }
}

# ===================================
# Attach Policies to Role
# ===================================
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

resource "aws_iam_role_policy_attachment" "ecs_deploy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecs_deploy.arn
}

resource "aws_iam_role_policy_attachment" "s3_frontend" {
  count      = var.enable_frontend_deploy ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.s3_frontend[0].arn
}

resource "aws_iam_role_policy_attachment" "cloudfront_invalidation" {
  count      = var.enable_frontend_deploy ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.cloudfront_invalidation[0].arn
}
