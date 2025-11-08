# PowerShell script to set up Workload Identity Federation for GitHub Actions
# Run this script to create the WIF pool, provider, and service account

# Set your variables
$PROJECT_ID = "docuhero-583a5"
$POOL_NAME = "github-actions-pool"
$PROVIDER_NAME = "github-provider"
$SERVICE_ACCOUNT_NAME = "github-actions"
$SERVICE_ACCOUNT_EMAIL = "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
$GITHUB_ORG = "GitDocuHero"
$GITHUB_REPO_API = "GitDocuHero/docuhero-api"
$GITHUB_REPO_UI = "GitDocuHero/hero-ui"

Write-Host "Setting up Workload Identity Federation for project: $PROJECT_ID" -ForegroundColor Green

# Step 1: Enable required APIs
Write-Host "Enabling required APIs..." -ForegroundColor Yellow
gcloud services enable `
  iamcredentials.googleapis.com `
  sts.googleapis.com `
  --project=$PROJECT_ID

# Step 2: Create Workload Identity Pool
Write-Host "Creating Workload Identity Pool: $POOL_NAME..." -ForegroundColor Yellow
gcloud iam workload-identity-pools create $POOL_NAME `
  --project=$PROJECT_ID `
  --location="global" `
  --display-name="GitHub Actions Pool"

# Step 3: Create Workload Identity Provider for GitHub
Write-Host "Creating Workload Identity Provider: $PROVIDER_NAME..." -ForegroundColor Yellow
# Build the attribute condition with proper quoting for CEL expression
# Use cmd /c to preserve quotes that PowerShell would otherwise strip
$attributeCondition = "assertion.repository_owner==\`"$GITHUB_ORG\`""
$gcloudCmd = "gcloud iam workload-identity-pools providers create-oidc $PROVIDER_NAME --project=$PROJECT_ID --location=global --workload-identity-pool=$POOL_NAME --display-name=`"GitHub Provider`" --attribute-mapping=`"google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository`" --attribute-condition=`"$attributeCondition`" --issuer-uri=`"https://token.actions.githubusercontent.com`""
cmd /c $gcloudCmd

# Step 4: Get the provider identifier (this is what you need for WIF_PROVIDER)
$PROJECT_NUMBER = gcloud projects describe $PROJECT_ID --format="value(projectNumber)"
$WIF_PROVIDER = "projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/providers/$PROVIDER_NAME"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "WIF_PROVIDER value:" -ForegroundColor Cyan
Write-Host "$WIF_PROVIDER" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 5: Create Service Account (if it doesn't exist)
Write-Host "Creating service account: $SERVICE_ACCOUNT_NAME..." -ForegroundColor Yellow
gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME `
  --project=$PROJECT_ID `
  --display-name="GitHub Actions Deployer" `
  2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Service account may already exist, continuing..." -ForegroundColor Yellow
}

# Step 6: Grant necessary roles to the service account
Write-Host "Granting roles to service account..." -ForegroundColor Yellow
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" `
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" `
  --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" `
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" `
  --role="roles/secretmanager.secretAccessor"

# Step 7: Allow GitHub to impersonate the service account
Write-Host "Allowing GitHub Actions to impersonate service account..." -ForegroundColor Yellow
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL `
  --project=$PROJECT_ID `
  --role="roles/iam.workloadIdentityUser" `
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/attribute.repository/$GITHUB_REPO_API"

gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL `
  --project=$PROJECT_ID `
  --role="roles/iam.workloadIdentityUser" `
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/attribute.repository/$GITHUB_REPO_UI"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Add these to your GitHub repository secrets/variables:" -ForegroundColor Yellow
Write-Host ""
Write-Host "WIF_PROVIDER: $WIF_PROVIDER" -ForegroundColor White
Write-Host "WIF_SERVICE_ACCOUNT: $SERVICE_ACCOUNT_EMAIL" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Green
