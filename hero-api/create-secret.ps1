# Script to create DATABASE_URL secret in Google Cloud Secret Manager
# This uses the Unix socket connection format for Cloud Run

$PROJECT_ID = "docuhero-583a5"
$REGION = "us-east1"
$INSTANCE_NAME = "docuhero-db"
$USERNAME = "dbuser"
$PASSWORD = "bIiwxA3U7Lr5fSO0NV9lpdzZ"
$DATABASE = "docuhero"

# Connection string for Cloud Run (using Unix socket)
$DATABASE_URL = "postgresql://${USERNAME}:${PASSWORD}@/${DATABASE}?host=/cloudsql/${PROJECT_ID}:${REGION}:${INSTANCE_NAME}"

Write-Host "Creating secret DATABASE_URL in project $PROJECT_ID..." -ForegroundColor Yellow
Write-Host "Connection string format: postgresql://user:password@/database?host=/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME" -ForegroundColor Gray

# Create the secret
echo $DATABASE_URL | gcloud secrets create DATABASE_URL --data-file=- --project=$PROJECT_ID

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Secret created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To view the secret:" -ForegroundColor Cyan
    Write-Host "  gcloud secrets versions access latest --secret=DATABASE_URL" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To grant access to Cloud Run service account:" -ForegroundColor Cyan
    Write-Host "  gcloud secrets add-iam-policy-binding DATABASE_URL --member='serviceAccount:YOUR_SERVICE_ACCOUNT@${PROJECT_ID}.iam.gserviceaccount.com' --role='roles/secretmanager.secretAccessor'" -ForegroundColor Gray
} else {
    Write-Host "❌ Failed to create secret. Error code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  1. Secret already exists - use 'gcloud secrets versions add' instead" -ForegroundColor Gray
    Write-Host "  2. Not authenticated - run 'gcloud auth login'" -ForegroundColor Gray
    Write-Host "  3. API not enabled - run 'gcloud services enable secretmanager.googleapis.com'" -ForegroundColor Gray
    Write-Host "  4. Insufficient permissions - need Secret Manager Admin role" -ForegroundColor Gray
}

