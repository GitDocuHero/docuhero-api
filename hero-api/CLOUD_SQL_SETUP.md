# Cloud SQL Proxy Setup Guide

## Step-by-Step Setup

### Step 1: Install Cloud SQL Proxy

**On Windows:**
1. Download from: https://github.com/GoogleCloudPlatform/cloud-sql-proxy/releases/latest
2. Download `cloud-sql-proxy-x64.exe`
3. Rename to `cloud-sql-proxy.exe` and place in a folder in your PATH
4. Or use Chocolatey: `choco install cloud-sql-proxy`

Verify installation:
```powershell
cloud-sql-proxy --version
```

### Step 2: Authenticate with Google Cloud

Make sure you're authenticated:
```powershell
gcloud auth application-default login
```

This will open a browser to authenticate. You need the "Cloud SQL Client" role.

### Step 3: Create Your Cloud SQL Instance (with Private IP)

First, ensure you have Private Service Access set up:
```powershell
# Get your project ID
gcloud config get-value project

# Enable necessary APIs
gcloud services enable servicenetworking.googleapis.com
gcloud services enable sqladmin.googleapis.com

# Create the instance with private IP (no public IP)
gcloud sql instances create docuhero-db `
  --database-version=POSTGRES_15 `
  --tier=db-f1-micro `
  --region=us-east1 `
  --network=default `
  --no-assign-ip
```

### Step 4: Create Database and User

```powershell
# Create database
gcloud sql databases create docuhero --instance=docuhero-db

# Create user (replace with your desired username/password)
gcloud sql users create dbuser `
  --instance=docuhero-db `
  --password=YOUR_SECURE_PASSWORD
```

### Step 5: Start Cloud SQL Proxy (Local Development)

**Option A: Using the provided script**
```powershell
cd hero-api
.\scripts\start-proxy.ps1 -ProjectId YOUR_PROJECT_ID
```

**Option B: Manual command**
```powershell
# Get your connection name
$PROJECT_ID = gcloud config get-value project
$CONNECTION_NAME = "${PROJECT_ID}:us-east1:docuhero-db"

# Start proxy on port 5432
cloud-sql-proxy --port=5432 $CONNECTION_NAME
```

The proxy will run in the foreground. Keep this terminal open.

### Step 6: Configure Your Application

Create a `.env` file in `hero-api/`:
```env
DATABASE_URL="postgresql://dbuser:YOUR_PASSWORD@localhost:5432/docuhero?schema=public"
```

### Step 7: Test the Connection

In a new terminal, test the connection:
```powershell
cd hero-api

# If using Prisma
npx prisma db pull  # Test connection
npx prisma generate
```

## Production Setup (Cloud Run)

For Cloud Run, you don't need to run the proxy manually. Cloud Run handles it automatically.

1. **Enable Cloud SQL connection in your service:**
   ```yaml
   # In your Cloud Run service configuration
   cloudSqlInstances:
     - PROJECT_ID:us-east1:docuhero-db
   ```

2. **Use Unix socket connection:**
   ```env
   DATABASE_URL="postgresql://dbuser:PASSWORD@/docuhero?host=/cloudsql/PROJECT_ID:us-east1:docuhero-db&schema=public"
   ```

## Troubleshooting

### "Authentication failed"
- Run: `gcloud auth application-default login`
- Ensure your account has "Cloud SQL Client" role

### "Connection refused"
- Make sure Cloud SQL Proxy is running
- Check that the port (5432) matches in your DATABASE_URL

### "Instance not found"
- Verify the connection name: `PROJECT_ID:REGION:INSTANCE_NAME`
- Check: `gcloud sql instances list`

