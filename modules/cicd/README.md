# CI/CD Module

Configures GitHub Actions integration using OpenID Connect (OIDC) for secure, credential-free deployments.

## Purpose

Enables GitHub Actions workflows to deploy to AWS without static access keys using temporary credentials.

## Resources Created

- IAM OIDC identity provider for GitHub
- IAM role for GitHub Actions
- IAM policies for ECR, ECS, S3, and CloudFront access
- Trust policy restricting access to specified repositories

## Usage

```hcl
module "cicd" {
  source = "./modules/cicd"

  prefix              = "ecommerce"
  env                 = "qa"
  github_repositories = ["yourorg/ecommerce-backend", "yourorg/ecommerce-frontend"]

  ecr_repository_arns     = [module.compute["api"].repository_arn]
  ecs_service_arns        = [module.compute["api"].service_arn]
  ecs_task_role_arns      = [
    module.compute["api"].task_role_arn,
    module.compute["api"].execution_role_arn
  ]

  enable_frontend_deploy      = true
  frontend_bucket_arn         = module.frontend.s3_bucket_arn
  cloudfront_distribution_arn = module.frontend.cloudfront_distribution_arn
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Resource name prefix | string | - |
| env | Environment name | string | - |
| github_repositories | Allowed repositories (owner/repo format) | list(string) | [] |
| ecr_repository_arns | ECR repository ARNs | list(string) | [] |
| ecs_service_arns | ECS service ARNs | list(string) | [] |
| ecs_task_role_arns | ECS task/execution role ARNs | list(string) | [] |
| enable_frontend_deploy | Enable S3/CloudFront permissions | bool | false |
| frontend_bucket_arn | S3 bucket ARN for frontend | string | "" |
| cloudfront_distribution_arn | CloudFront distribution ARN | string | "" |

## Outputs

| Name | Description |
|------|-------------|
| oidc_provider_arn | GitHub OIDC provider ARN |
| github_actions_role_arn | IAM role ARN for workflows |
| github_actions_role_name | IAM role name |
| ecr_policy_arn | ECR access policy ARN |
| ecs_policy_arn | ECS deployment policy ARN |
| s3_policy_arn | S3 frontend policy ARN |
| cloudfront_policy_arn | CloudFront policy ARN |

## OIDC Authentication Flow

1. GitHub Actions workflow requests token from GitHub OIDC provider
2. Workflow presents token to AWS STS AssumeRoleWithWebIdentity
3. AWS validates token against trust policy
4. AWS issues temporary credentials (valid 1 hour)
5. Workflow uses credentials for deployment
6. Credentials expire automatically

## Trust Policy

Restricts role assumption to specified repositories:

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:yourorg/ecommerce-backend:*",
        "repo:yourorg/ecommerce-frontend:*"
      ]
    }
  }
}
```

Only workflows from listed repositories can assume the role.

## Permissions

### ECR Access

- Get authorization token
- Push/pull images
- Describe repositories
- List images

### ECS Deployment

- Describe services and tasks
- Register task definitions
- Update services
- Pass IAM roles to tasks

### S3 Frontend

- Put/get/delete objects
- List bucket
- Set object ACLs

### CloudFront

- Create invalidations
- Get invalidation status
- List invalidations

## GitHub Workflow Configuration

### Backend Deployment

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$GITHUB_SHA
      
      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: task-definition.json
          service: ecommerce-qa-api
          cluster: ecommerce-qa-cluster
```

### Frontend Deployment

```yaml
name: Deploy Frontend

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Build
        run: npm ci && npm run build
      
      - name: Deploy to S3
        run: aws s3 sync ./dist s3://$S3_BUCKET --delete
      
      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id $CLOUDFRONT_ID \
            --paths "/*"
```

## Setup Instructions

### 1. Deploy Infrastructure

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### 2. Retrieve Role ARN

```bash
terraform output github_actions_role_arn
```

Copy the ARN (e.g., `arn:aws:iam::123456789012:role/ecommerce-qa-github-actions-role`).

### 3. Configure GitHub Secret

In each repository:
1. Go to Settings → Secrets → Actions
2. Click "New repository secret"
3. Name: `AWS_ROLE_ARN`
4. Value: Paste the role ARN
5. Click "Add secret"

### 4. Add Workflow Files

Copy workflow templates from `.github/workflows/` to your repositories.

### 5. Test Deployment

Push to main branch and verify workflow succeeds.

## Security Best Practices

### Principle of Least Privilege

Policies grant only necessary permissions:
- ECR: Push to specific repositories only
- ECS: Update specific services only
- S3: Access specific bucket only

### Repository Restriction

Trust policy limits role to specified repositories. Unauthorized repositories cannot assume the role.

### Temporary Credentials

Credentials expire after 1 hour. No long-lived access keys.

### Audit Logging

All API calls logged to CloudTrail (if enabled).

## Troubleshooting

### Error: Not Authorized to Assume Role

**Cause**: Repository not in `github_repositories` list.

**Solution**: Add repository to `qa.tfvars`:

```hcl
github_repositories = ["yourorg/repo1", "yourorg/repo2"]
```

Apply changes:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### Error: Access Denied to ECR

**Cause**: ECR repository ARN not in `ecr_repository_arns`.

**Solution**: Verify ARNs in module call match actual repository ARNs.

### Error: Cannot Update ECS Service

**Cause**: Service ARN not in `ecs_service_arns` or task role not in `ecs_task_role_arns`.

**Solution**: Check module configuration includes all required ARNs.

## Private vs Public Repositories

OIDC works with both:
- **Private repositories**: Only collaborators can trigger workflows
- **Public repositories**: Workflows can be triggered by anyone with push access

Trust policy validates repository ownership regardless of visibility.

## Multi-Environment Support

For multiple environments (dev, staging, prod):

1. Create separate roles per environment
2. Use environment-specific secrets in GitHub
3. Reference correct role in workflow:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN_PROD }}
    aws-region: us-east-1
```

## Cost

OIDC integration is free:
- No charge for OIDC provider
- No charge for IAM role
- No charge for temporary credentials
- GitHub Actions minutes charged per repository plan

## Maintenance

### Add New Repository

Update `github_repositories` in `qa.tfvars`:

```hcl
github_repositories = [
  "yourorg/backend",
  "yourorg/frontend",
  "yourorg/new-repo"
]
```

Apply:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

### Update Permissions

Modify IAM policies in `modules/cicd/main.tf` and apply changes.

### Rotate OIDC Thumbprints

OIDC thumbprints should be updated if GitHub changes certificates:

```bash
terraform apply -var-file="environments/qa.tfvars"
```

Terraform will detect thumbprint changes.

## Dependencies

- Compute module (ECR and ECS ARNs)
- Frontend module (S3 and CloudFront ARNs)

## Used By

- GitHub Actions workflows in application repositories
