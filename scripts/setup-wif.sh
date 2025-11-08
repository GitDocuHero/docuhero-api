#!/bin/bash
# Script to set up Workload Identity Federation for GitHub Actions
# Run this script to create the WIF pool, provider, and service account

# Set your variables
PROJECT_ID="docuhero-583a5"
POOL_NAME="github-actions-pool"
PROVIDER_NAME="github-provider"
SERVICE_ACCOUNT_NAME="github-actions"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
GITHUB_ORG="YOUR_GITHUB_ORG"  # Replace with your GitHub org/username
GITHUB_REPO_API="YOUR_GITHUB_ORG/hero-api"  # Replace with your actual repo
GITHUB_REPO_UI="YOUR_GITHUB_ORG/hero-ui"    # Replace with your actual repo

echo "Setting up Workload Identity Federation for project: ${PROJECT_ID}"

# Step 1: Enable required APIs
echo "Enabling required APIs..."
gcloud services enable \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  --project=${PROJECT_ID}

# Step 2: Create Workload Identity Pool
echo "Creating Workload Identity Pool: ${POOL_NAME}..."
gcloud iam workload-identity-pools create ${POOL_NAME} \
  --project=${PROJECT_ID} \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Step 3: Create Workload Identity Provider for GitHub
echo "Creating Workload Identity Provider: ${PROVIDER_NAME}..."
gcloud iam workload-identity-pools providers create-oidc ${PROVIDER_NAME} \
  --project=${PROJECT_ID} \
  --location="global" \
  --workload-identity-pool=${POOL_NAME} \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository_owner==\"${GITHUB_ORG}\"" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Step 4: Get the provider identifier (this is what you need for WIF_PROVIDER)
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"

echo ""
echo "=========================================="
echo "WIF_PROVIDER value:"
echo "${WIF_PROVIDER}"
echo "=========================================="
echo ""

# Step 5: Create Service Account (if it doesn't exist)
echo "Creating service account: ${SERVICE_ACCOUNT_NAME}..."
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
  --project=${PROJECT_ID} \
  --display-name="GitHub Actions Deployer" \
  || echo "Service account may already exist, continuing..."

# Step 6: Grant necessary roles to the service account
echo "Granting roles to service account..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/cloudbuild.builds.builder"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

# Step 7: Allow GitHub to impersonate the service account
echo "Allowing GitHub Actions to impersonate service account..."
gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT_EMAIL} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_REPO_API}"

gcloud iam service-accounts add-iam-policy-binding ${SERVICE_ACCOUNT_EMAIL} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_REPO_UI}"

echo ""
echo "=========================================="
echo "Setup complete!"
echo ""
echo "Add these to your GitHub repository secrets/variables:"
echo ""
echo "WIF_PROVIDER: ${WIF_PROVIDER}"
echo "WIF_SERVICE_ACCOUNT: ${SERVICE_ACCOUNT_EMAIL}"
echo "=========================================="
