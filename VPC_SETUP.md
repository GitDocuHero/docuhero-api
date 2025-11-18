# VPC Connector Setup for Private Cloud SQL Access

## Current Setup

Currently using **public IP** connection for Cloud SQL:
- **IP**: 34.148.230.179
- **Connection**: Direct TCP connection from Cloud Build and Cloud Run
- **DATABASE_URL**: `postgresql://docuhero-app:[password]@34.148.230.179:5432/docuhero`

## When to Use VPC Connector

When you re-enable the organization policy that disables public IPs on Cloud SQL, you'll need to set up Serverless VPC Access to allow Cloud Build and Cloud Run to connect to the private IP.

## Setup Steps

### 1. Enable Required APIs

```bash
gcloud services enable vpcaccess.googleapis.com --project=docuherocopy
gcloud services enable servicenetworking.googleapis.com --project=docuherocopy
```

### 2. Create VPC Network (if not exists)

```bash
# Check if default VPC exists
gcloud compute networks list --project=docuherocopy

# If you need to create one:
gcloud compute networks create docuhero-vpc \
  --subnet-mode=auto \
  --project=docuherocopy
```

### 3. Configure Private Service Connection

This allows Cloud SQL to use private IP:

```bash
# Allocate IP range for Google services
gcloud compute addresses create google-managed-services-docuhero-vpc \
  --global \
  --purpose=VPC_PEERING \
  --prefix-length=16 \
  --network=default \
  --project=docuherocopy

# Create private connection
gcloud services vpc-peerings connect \
  --service=servicenetworking.googleapis.com \
  --ranges=google-managed-services-docuhero-vpc \
  --network=default \
  --project=docuherocopy
```

### 4. Update Cloud SQL Instance to Private IP Only

```bash
# Remove public IP and add private IP
gcloud sql instances patch docuhero-db \
  --no-assign-ip \
  --network=projects/docuherocopy/global/networks/default \
  --project=docuherocopy
```

**Note**: This will cause downtime. The instance needs to restart.

### 5. Create Serverless VPC Access Connector

```bash
gcloud compute networks vpc-access connectors create docuhero-connector \
  --region=us-east1 \
  --network=default \
  --range=10.8.0.0/28 \
  --min-instances=2 \
  --max-instances=3 \
  --project=docuherocopy
```

**Cost**: ~$0.08/hour per connector instance (~$120/month for 2-3 instances)

### 6. Get Cloud SQL Private IP

```bash
gcloud sql instances describe docuhero-db \
  --project=docuherocopy \
  --format="value(ipAddresses[0].ipAddress)"
```

### 7. Update DATABASE_URL Secret

Replace the public IP with the private IP:

```bash
# Get the private IP from step 6, then:
echo -n "postgresql://docuhero-app:[URL_ENCODED_PASSWORD]@[PRIVATE_IP]:5432/docuhero" | \
  gcloud secrets versions add DATABASE_URL --data-file=- --project=docuherocopy
```

### 8. Update cloudbuild.yaml

Add VPC connector to the migration step:

```yaml
steps:
  # Step 1: Run database migrations
  - name: 'node:20'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        npm install
        npx prisma generate
        npx prisma migrate deploy
    secretEnv: ['DATABASE_URL']
    env:
      - 'VPC_CONNECTOR=projects/docuherocopy/locations/us-east1/connectors/docuhero-connector'
```

**Note**: Cloud Build doesn't natively support VPC connectors. You'll need to use a workaround like running builds in a VM or using Cloud Build private pools (enterprise feature).

### 9. Update Cloud Run Deployment

Update the deploy step in cloudbuild.yaml to use the VPC connector:

```yaml
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
    - 'NODE_ENV=production,PORT=8080'
    - '--vpc-connector'
    - 'docuhero-connector'
    - '--vpc-egress'
    - 'private-ranges-only'
    - '--allow-unauthenticated'
```

## Alternative: Cloud Build Private Pools

For a production setup with private Cloud SQL, consider using Cloud Build private pools:

```bash
# Create a private worker pool
gcloud builds worker-pools create docuhero-pool \
  --region=us-east1 \
  --peered-network=projects/docuherocopy/global/networks/default \
  --project=docuherocopy
```

Then update `.github/workflows/deploy.yml` to use the private pool:

```yaml
gcloud builds submit . \
  --config=cloudbuild.yaml \
  --region=us-east1 \
  --worker-pool=projects/docuherocopy/locations/us-east1/workerPools/docuhero-pool \
  --substitutions=COMMIT_SHA=${COMMIT_SHA},_TARGET_PROJECT=${PROJECT_ID} \
  --project=${PROJECT_ID}
```

**Cost**: Private pools have additional costs (~$0.05/build-minute)

## Recommendation

For now, **stick with public IP** until you're ready for a full private networking setup. When you're ready:

1. **Best for small projects**: Use Unix socket connection with `--add-cloudsql-instances` (already configured in Cloud Run deployment)
2. **Best for production**: Set up VPC connector + private IP for full isolation

## Current Cloud Run Configuration

Your Cloud Run service already uses `--add-cloudsql-instances` which mounts a Unix socket. This means:
- ✅ Cloud Run connections are already private (via Unix socket, not TCP)
- ✅ No VPC connector needed for Cloud Run
- ⚠️ Only Cloud Build migrations need the public IP currently

### Alternative for Migrations

Instead of running migrations in Cloud Build, you could:
1. Run migrations as a Cloud Run Job with Cloud SQL connector
2. Run migrations from Cloud Shell (which has private access)
3. Run migrations from your local machine via Cloud SQL Proxy

This would eliminate the need for public IP entirely.

---

**Last Updated**: 2025-11-18
**Status**: Using public IP (34.148.230.179)
**Next Step**: Update DATABASE_URL secret with public IP, then test deployment
