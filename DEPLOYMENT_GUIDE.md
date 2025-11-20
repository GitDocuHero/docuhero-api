# Complete Deployment Guide for DocuHero API

This guide documents the complete setup process for deploying the DocuHero API to Google Cloud Platform with Cloud Run, Cloud SQL, and GitHub Actions CI/CD.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup](#infrastructure-setup)
3. [Repository Configuration](#repository-configuration)
4. [Critical Files](#critical-files)
5. [Common Issues and Solutions](#common-issues-and-solutions)
6. [Verification Steps](#verification-steps)

---

## Prerequisites

### Required Tools
- Google Cloud SDK (gcloud CLI)
- Git
- Node.js 20+
- Access to Google Cloud Console
- GitHub repository with admin access

### Required GCP APIs
Enable these APIs in your project:
```bash
gcloud services enable cloudbuild.googleapis.com \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  --project=YOUR_PROJECT_ID
```

---

## Infrastructure Setup

### Step 1: Create Cloud SQL Instance

```bash
gcloud sql instances create docuhero-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-east1 \
  --project=YOUR_PROJECT_ID
```

**Wait 5-10 minutes** for the instance to be created. Check status:
```bash
gcloud sql instances describe docuhero-db \
  --project=YOUR_PROJECT_ID \
  --format="value(state)"
```

### Step 2: Create Database

```bash
gcloud sql databases create docuhero \
  --instance=docuhero-db \
  --project=YOUR_PROJECT_ID
```

### Step 3: Create Database User

```bash
gcloud sql users create docuhero-app \
  --instance=docuhero-db \
  --password=YOUR_SECURE_PASSWORD \
  --project=YOUR_PROJECT_ID
```

### Step 4: Get Connection Details

```bash
# Get public IP (for local development)
gcloud sql instances describe docuhero-db \
  --project=YOUR_PROJECT_ID \
  --format="value(ipAddresses[0].ipAddress)"

# Get connection name (for Cloud Run)
gcloud sql instances describe docuhero-db \
  --project=YOUR_PROJECT_ID \
  --format="value(connectionName)"
# Format: PROJECT_ID:REGION:INSTANCE_NAME
```

### Step 5: Create DATABASE_URL Secret

```bash
# Format: postgresql://username:password@localhost:5432/database?host=/cloudsql/CONNECTION_NAME
# Note: Use localhost with /cloudsql/ socket path for Cloud Run

echo -n "postgresql://docuhero-app:YOUR_PASSWORD@localhost:5432/docuhero?host=/cloudsql/YOUR_PROJECT_ID:us-east1:docuhero-db" | \
  gcloud secrets create DATABASE_URL \
    --data-file=- \
    --replication-policy=automatic \
    --project=YOUR_PROJECT_ID
```

### Step 6: Set Up Workload Identity Federation

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool" \
  --project=YOUR_PROJECT_ID

# Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
  --attribute-condition="assertion.repository_owner=='YOUR_GITHUB_ORG'" \
  --project=YOUR_PROJECT_ID

# Create Service Account for GitHub Actions
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Service Account" \
  --project=YOUR_PROJECT_ID

# Grant necessary roles to the service account
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Allow GitHub Actions to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GITHUB_ORG/YOUR_REPO" \
  --project=YOUR_PROJECT_ID
```

### Step 7: Configure Cloud Build Service Account

```bash
# Get project number
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format="value(projectNumber)")

# Grant Cloud Build service account necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## Repository Configuration

### Critical Files That Must Be Present

#### 1. `.gitignore`
```gitignore
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
yarn.lock

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Build outputs
dist/
build/
*.log

# IDE and editor files
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Testing
coverage/
.nyc_output/

# Temporary files
*.tmp
.cache/

# Google Cloud
gcloud-key.json
service-account*.json

# Credentials and secrets
*credentials*
*secret*
*secrets*
*.pem
*.key
*.crt
*.p12
*.pfx
*-key.json
config/secrets.json
config/credentials.json
DATABASE_CREDENTIALS.txt
```

**CRITICAL**: Do NOT exclude `package-lock.json` or `.gcloudignore` in .gitignore!

#### 2. `.gcloudignore`
```gcloudignore
.gcloudignore
.git
.gitignore

# Node.js dependencies
node_modules/

# Environment files
.env
.env.*

# Development and documentation
*.md
!README.md
.vscode/
.idea/
docs/

# Test files
*.test.js
*.test.ts
*.spec.js
*.spec.ts
__tests__/
coverage/

# Logs
*.log
logs/

# OS files
.DS_Store
Thumbs.db

# Credentials and secrets (but NOT package-lock.json!)
*credentials*
*secret*
*secrets*
*.pem
*.key
*.crt
*.p12
*.pfx
*-key.json
config/secrets.json
config/credentials.json
DATABASE_CREDENTIALS.txt

# Scripts (PowerShell scripts not needed in cloud)
scripts/

# GitHub Actions
.github/
```

**CRITICAL**: This file MUST be committed to the repository. Without it, Cloud Build uses .gitignore, which would exclude package-lock.json.

#### 3. `.dockerignore`
```dockerignore
# Node modules
node_modules/
npm-debug.log

# But include lock files
!package-lock.json
!yarn.lock
!pnpm-lock.yaml

# Git
.git/
.gitignore

# Environment files
.env
.env.*

# Development files
*.md
.vscode/
.idea/

# Build artifacts
dist/

# Test files
*.test.js
*.test.ts
*.spec.js
*.spec.ts
__tests__/
coverage/

# Documentation
docs/

# CI/CD
.github/
cloudbuild.yaml

# OS files
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Scripts
scripts/
```

#### 4. `Dockerfile`
```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npx prisma generate
RUN npm run build
RUN npm prune --production

EXPOSE 8080

CMD sh -c "npx prisma migrate deploy && npm start"
```

**KEY POINTS**:
- Migrations run at container startup (not in Cloud Build)
- Uses npm ci for reproducible builds
- Prunes dev dependencies after build
- Uses Unix socket connection via Cloud Run's --add-cloudsql-instances

#### 5. `cloudbuild.yaml`
```yaml
steps:
  # Step 1: Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/${_TARGET_PROJECT}/hero-api:$COMMIT_SHA', '.']

  # Step 2: Push Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/${_TARGET_PROJECT}/hero-api:$COMMIT_SHA']

  # Step 3: Deploy to Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: gcloud
    args:
      - 'run'
      - 'deploy'
      - 'hero-api'
      - '--image'
      - 'gcr.io/${_TARGET_PROJECT}/hero-api:$COMMIT_SHA'
      - '--region'
      - 'us-east1'
      - '--platform'
      - 'managed'
      - '--add-cloudsql-instances'
      - '${_TARGET_PROJECT}:us-east1:docuhero-db'
      - '--update-secrets'
      - 'DATABASE_URL=DATABASE_URL:latest'
      - '--set-env-vars'
      - 'NODE_ENV=production'
      - '--allow-unauthenticated'

options:
  logging: CLOUD_LOGGING_ONLY

images:
  - 'gcr.io/${_TARGET_PROJECT}/hero-api:$COMMIT_SHA'
```

**KEY POINTS**:
- No migration step (migrations run in container)
- No PORT environment variable (Cloud Run sets this automatically)
- Uses ${_TARGET_PROJECT} substitution variable

#### 6. `.github/workflows/deploy.yml`
```yaml
name: Deploy to Cloud Run

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'github-actions@YOUR_PROJECT_ID.iam.gserviceaccount.com'

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Submit build to Cloud Build
        run: |
          gcloud builds submit \
            --config=cloudbuild.yaml \
            --substitutions=_TARGET_PROJECT=YOUR_PROJECT_ID \
            --project=YOUR_PROJECT_ID
```

#### 7. `package.json`
```json
{
  "name": "hero-api",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node src/index.ts"
  },
  "dependencies": {
    "@prisma/client": "^6.19.0",
    "express": "^4.18.2",
    "prisma": "^6.19.0"
  },
  "devDependencies": {
    "@types/express": "^4.17.17",
    "@types/node": "^20.10.6",
    "ts-node": "^10.9.2",
    "typescript": "^5.3.3"
  }
}
```

#### 8. `tsconfig.json`
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

#### 9. `src/index.ts`
```typescript
// Main entry point
import express from 'express';
import { PrismaClient } from '@prisma/client';

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.PORT || 8080;

app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'DocuHero API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      api: '/api'
    }
  });
});

// API routes placeholder
app.get('/api', (req, res) => {
  res.json({ message: 'API routes will be added here' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  await prisma.$disconnect();
  process.exit(0);
});
```

---

## Critical Migration File Setup

### Issue: UTF-16 Encoding
The migration file MUST be UTF-8 encoded. If you have encoding issues:

```bash
# Delete corrupted migration
rm -rf prisma/migrations/0_init

# Generate fresh migration with correct encoding
npx prisma migrate diff \
  --from-empty \
  --to-schema-datamodel prisma/schema.prisma \
  --script > migration.sql

# Move to correct location
mkdir -p prisma/migrations/0_init
mv migration.sql prisma/migrations/0_init/

# Verify encoding
file prisma/migrations/0_init/migration.sql
# Should output: ASCII text or UTF-8 Unicode text
```

---

## Common Issues and Solutions

### Issue 1: "npm ci can only install with existing package-lock.json"

**Cause**: package-lock.json not uploaded to Cloud Build

**Solution**:
1. Ensure .gitignore does NOT exclude package-lock.json
2. Ensure .gcloudignore does NOT exclude package-lock.json
3. Ensure .gcloudignore is committed to the repository
4. Commit package-lock.json to the repository

### Issue 2: "string contains embedded null" in migration

**Cause**: Migration file is UTF-16 encoded instead of UTF-8

**Solution**: Regenerate migration file using Prisma CLI (see above)

### Issue 3: "Can't reach database server"

**Cause**: Trying to connect via public IP without authorized networks

**Solution**: Use Unix socket connection in Cloud Run
- DATABASE_URL format: `postgresql://user:pass@localhost:5432/db?host=/cloudsql/PROJECT:REGION:INSTANCE`
- Ensure cloudbuild.yaml has `--add-cloudsql-instances` flag

### Issue 4: Container exits immediately with code 0

**Cause**: No server running after migrations complete

**Solution**: Ensure src/index.ts has Express server that listens on PORT

### Issue 5: 403 Forbidden accessing deployed API

**Cause**: Cloud Run service not publicly accessible

**Solution**:
```bash
gcloud run services add-iam-policy-binding hero-api \
  --region=us-east1 \
  --member=allUsers \
  --role=roles/run.invoker \
  --project=YOUR_PROJECT_ID
```

### Issue 6: "reserved env names were provided: PORT"

**Cause**: Cloud Run automatically sets PORT environment variable

**Solution**: Remove PORT from --set-env-vars in cloudbuild.yaml

### Issue 7: Permission denied in Cloud Build

**Cause**: Cloud Build service account missing permissions

**Solution**: Grant these roles:
- roles/run.admin
- roles/iam.serviceAccountUser
- roles/secretmanager.secretAccessor

---

## Verification Steps

### 1. Verify Cloud SQL Instance
```bash
gcloud sql instances list --project=YOUR_PROJECT_ID
# Status should be RUNNABLE
```

### 2. Verify Database Created
```bash
gcloud sql databases list --instance=docuhero-db --project=YOUR_PROJECT_ID
# Should show 'docuhero' database
```

### 3. Verify Secret Created
```bash
gcloud secrets describe DATABASE_URL --project=YOUR_PROJECT_ID
# Should show secret details
```

### 4. Verify Workload Identity Federation
```bash
gcloud iam workload-identity-pools describe github-pool \
  --location=global \
  --project=YOUR_PROJECT_ID
# Should show pool details
```

### 5. Test GitHub Actions
Push to main branch and check:
```bash
# View builds
gcloud builds list --project=YOUR_PROJECT_ID --limit=5

# View specific build logs
gcloud builds log BUILD_ID --project=YOUR_PROJECT_ID
```

### 6. Test Deployed API
```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe hero-api \
  --region=us-east1 \
  --project=YOUR_PROJECT_ID \
  --format="value(status.url)")

# Test health endpoint
curl ${SERVICE_URL}/health

# Test root endpoint
curl ${SERVICE_URL}/
```

### 7. Verify Database Connection
Check Cloud Run logs:
```bash
gcloud logs read \
  --project=YOUR_PROJECT_ID \
  --resource-type=cloud_run_revision \
  --limit=50
```

Should show:
- "All migrations have been successfully applied"
- "🚀 Server running on port 8080"

---

## Deployment Checklist

Before deploying to a new project:

- [ ] Enable all required GCP APIs
- [ ] Create Cloud SQL instance and wait for RUNNABLE status
- [ ] Create database and user with secure password
- [ ] Create DATABASE_URL secret with Unix socket format
- [ ] Set up Workload Identity Federation (pool + provider)
- [ ] Create and configure GitHub Actions service account
- [ ] Grant Cloud Build service account necessary roles
- [ ] Verify .gitignore does NOT exclude package-lock.json or .gcloudignore
- [ ] Verify .gcloudignore exists and is committed
- [ ] Verify package-lock.json is committed
- [ ] Verify migration files are UTF-8 encoded
- [ ] Update all YOUR_PROJECT_ID placeholders in files
- [ ] Update GitHub workflow with correct project number and ID
- [ ] Commit and push to main branch
- [ ] Monitor first build in Cloud Build console
- [ ] Add public IAM policy binding if needed
- [ ] Test all API endpoints

---

## Cost Estimates (us-east1)

- **Cloud SQL** (db-f1-micro): ~$7-10/month
- **Cloud Run**: Pay-per-use (free tier: 2M requests/month)
- **Cloud Build**: Free tier: 120 build-minutes/day
- **Secret Manager**: ~$0.06/secret/month + $0.03 per 10K accesses
- **Container Registry**: ~$0.026/GB/month

**Estimated Total**: $10-15/month for low-traffic development

---

## Lessons Learned from docuherocopy Migration

1. **Migration Strategy**: Run migrations in container startup, not Cloud Build
   - Reason: Cloud Build can't connect to Cloud SQL without VPC or authorized networks
   - Solution: Use Cloud Run's Unix socket mount via --add-cloudsql-instances

2. **File Encoding**: Always verify migration files are UTF-8
   - UTF-16 causes "embedded null" errors
   - Use `file` command to verify encoding

3. **Lock Files**: Always commit package-lock.json
   - Enables reproducible builds with npm ci
   - Faster installs in CI/CD

4. **.gcloudignore**: Must be committed to repository
   - Without it, Cloud Build uses .gitignore
   - Results in package-lock.json being excluded

5. **Environment Variables**: Don't set PORT in Cloud Run
   - Cloud Run sets this automatically
   - Causes "reserved env names" error

6. **IAM Permissions**: Cloud Build service account needs specific roles
   - roles/run.admin to deploy Cloud Run services
   - roles/iam.serviceAccountUser to act as Cloud Run service account
   - roles/secretmanager.secretAccessor to read secrets

7. **Public Access**: Cloud Run services are private by default
   - Need IAM policy binding for public access
   - Use --allow-unauthenticated or add allUsers invoker role

---

## Next Steps for New Project Setup

1. Create new GCP project with appropriate name (e.g., "docu-hero")
2. Follow infrastructure setup steps sequentially
3. Clone this repository configuration
4. Update all project ID references
5. Test locally with development DATABASE_URL
6. Commit and push to trigger first deployment
7. Monitor Cloud Build logs for issues
8. Verify all endpoints working

## Support

For issues, refer to:
- Cloud Build logs: `gcloud builds log BUILD_ID --project=PROJECT_ID`
- Cloud Run logs: Cloud Console → Cloud Run → hero-api → Logs
- Migration logs: Cloud Run container logs show Prisma migration output
