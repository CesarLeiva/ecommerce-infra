# Guía de Configuración CI/CD con GitHub Actions

## Requisitos Previos

1. **Desplegar infraestructura Terraform** con `enable_cicd = true`
2. **Obtener el ARN del rol** desde los outputs de Terraform
3. **Configurar repositorios GitHub** (backend y/o frontend)

## Configuración Paso a Paso

### 1. Desplegar Infraestructura

```bash
# Desde el directorio ecommerce-infra
terraform init
terraform plan -var-file=environments/qa.tfvars
terraform apply -var-file=environments/qa.tfvars
```

Después del deploy, obtén el ARN del rol:

```bash
terraform output github_actions_role_arn
# Output: arn:aws:iam::123456789012:role/ecommerce-qa-github-actions-role
```

### 2. Configurar Secrets en GitHub

Para **cada repositorio** (backend/frontend):

1. Ve a **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Añade:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: `arn:aws:iam::123456789012:role/ecommerce-qa-github-actions-role`

### 3. Estructura de Repositorios

#### Opción A: Monorepo

```
ecommerce/
├── .github/
│   └── workflows/
│       ├── backend.yml
│       └── frontend.yml
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
└── frontend/
    ├── package.json
    └── src/
```

Copia los workflows de `ecommerce-infra/.github/workflows/` al monorepo.

#### Opción B: Repos Separados

**ecommerce-backend:**
```
ecommerce-backend/
├── .github/
│   └── workflows/
│       └── deploy.yml  (usar backend.yml)
├── Dockerfile
├── package.json
└── src/
```

**ecommerce-frontend:**
```
ecommerce-frontend/
├── .github/
│   └── workflows/
│       └── deploy.yml  (usar frontend.yml)
├── package.json
└── src/
```

### 4. Ajustar Variables en Workflows

Edita los archivos `.github/workflows/*.yml`:

**Backend (backend.yml):**
```yaml
env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: ecommerce-qa-api  # Debe coincidir con el servicio
  ECS_CLUSTER: ecommerce-qa-cluster
  ECS_SERVICE: ecommerce-qa-api
```

**Frontend (frontend.yml):**
```yaml
env:
  AWS_REGION: us-east-1
  S3_BUCKET: ecommerce-qa-frontend
  NODE_VERSION: '20'  # Ajustar según el proyecto
```

### 5. Dockerfile para Backend

Asegurarse de que el `Dockerfile` soporte **ARM64**:

```dockerfile
FROM --platform=linux/arm64 node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000
CMD ["node", "src/index.js"]
```

### 6. Health Check Endpoint

El backend (cada servicio) debe tener un endpoint de health check:

```javascript
// src/routes/health.js
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});
```

## 🔒 Seguridad OIDC

**Ventajas vs Access Keys:**
- ✅ Sin credenciales estáticas en GitHub
- ✅ Tokens temporales (1 hora de validez)
- ✅ Permisos granulares por repositorio
- ✅ Auditable con CloudTrail

**Cómo funciona:**
1. GitHub Actions solicita token a AWS STS
2. AWS valida que el repositorio está autorizado
3. Genera credenciales temporales
4. Workflow usa credenciales para deploy
5. Credenciales expiran automáticamente

## 📊 Verificación

### Validar Configuración OIDC

```bash
# Ver el OIDC provider creado
aws iam list-open-id-connect-providers

# Ver detalles del rol
aws iam get-role --role-name ecommerce-qa-github-actions-role

# Ver políticas adjuntas
aws iam list-attached-role-policies --role-name ecommerce-qa-github-actions-role
```

### Probar Deploy

1. Haz un commit en `main`:
   ```bash
   git add .
   git commit -m "feat: initial deployment"
   git push origin main
   ```

2. Ve a **Actions** tab en GitHub y observa el workflow

3. Verifica el deploy:
   ```bash
   # Backend
   aws ecs describe-services --cluster ecommerce-qa-cluster --services ecommerce-qa-api
   
   # Frontend
   aws s3 ls s3://ecommerce-qa-frontend/
   ```

## 🐛 Troubleshooting

### Error: "User is not authorized to perform: sts:AssumeRoleWithWebIdentity"

**Causa:** El repositorio no está en la lista de `github_repositories` en Terraform.

**Solución:**
```hcl
# qa.tfvars
github_repositories = ["TU_USUARIO/ecommerce-backend", "TU_USUARIO/ecommerce-frontend"]
```
Luego ejecuta `terraform apply`.

### Error: "Access Denied" en ECR

**Causa:** El ARN del repositorio ECR no coincide.

**Verificar:**
```bash
aws ecr describe-repositories --repository-names ecommerce-qa-api
```

### Error: Task Definition no actualiza

**Causa:** El workflow descarga la task definition antigua.

**Solución:** Verifica que el nombre del contenedor en task definition coincida:
```yaml
container-name: api  # Debe coincidir con el nombre en ECS
```

## 🎯 Flujo Completo

```
┌─────────────┐
│ git push    │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ GitHub Actions      │
│ - Detect changes    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Request OIDC Token  │
│ from AWS STS        │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Build Docker Image  │ (Backend)
│ or npm build        │ (Frontend)
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Push to ECR/S3      │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Update ECS Service  │ (Backend)
│ or Invalidate CF    │ (Frontend)
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ ✅ Deployment Done  │
└─────────────────────┘
```

## 📚 Recursos Adicionales

- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS ECS Deploy Action](https://github.com/aws-actions/amazon-ecs-deploy-task-definition)
- [ECR Login Action](https://github.com/aws-actions/amazon-ecr-login)
