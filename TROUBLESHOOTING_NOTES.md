# Cloud Build Troubleshooting Notes

## Date: 2025-11-18

## Problem Statement
- Cloud Build deployments fail in `docuhero-583a5` project with PERMISSION_DENIED errors
- Manual trigger, gcloud builds submit, and automatic triggers all fail
- GitHub Actions workflow also fails with same error

## Key Discovery: DocuHeroCopy vs docuhero-583a5

### DocuHeroCopy Project (888522084120) - **WORKS** ✅

**Test Command:**
```bash
gcloud builds submit --config=cloudbuild.yaml --substitutions=COMMIT_SHA=test789 --project=docuherocopy
```

**Result:** SUCCESS (builds submit and run)

**Evidence from build logs (build ID: 497ce34e-c163-4ffc-a638-6657a232fa37):**
1. ✅ Build submission accepted
2. ✅ Source tarball uploaded to gs://docuherocopy_cloudbuild/
3. ✅ Build started and ran
4. ✅ Docker image `node:20` pulled successfully
5. ✅ `npm install` completed successfully (added 34 packages)
6. ✅ `npx prisma generate` completed successfully
7. ✅ DATABASE_URL secret accessed successfully
8. ✅ `npx prisma migrate deploy` attempted to run
9. ❌ Failed only at database connection (expected - no real database)

**Error:** `Error: P1001: Can't reach database server at localhost:5432`

**This proves:**
- All GCP APIs are accessible
- `serviceusage.services.use` permission is working
- Secret Manager access works
- Build execution works
- Failure only at application level (database connection)

### docuhero-583a5 Project (1027156300345) - **FAILS** ❌

**Test Command:**
```bash
gcloud builds submit --config=cloudbuild.yaml --substitutions=COMMIT_SHA=test123 --project=docuhero-583a5
```

**Result:** PERMISSION_DENIED at submission

**Error Message:**
```
ERROR: (gcloud.builds.submit) PERMISSION_DENIED: The caller does not have permission.
This command is authenticated as elliot@docuhero.io which is the active account
specified by the [core/account] property
```

**This proves:**
- The build never starts
- Failure occurs at API submission stage
- Not a secrets issue, not a build execution issue
- Something specific to docuhero-583a5 project is blocking API access

## IAM Permissions Granted (Should be identical in both projects)

### Organization Level (333703630998)
- user:elliot@docuhero.io
  - roles/serviceusage.serviceUsageAdmin ✅
  - roles/editor ✅

- serviceAccount:1027156300345-compute@developer.gserviceaccount.com (docuhero-583a5)
  - roles/serviceusage.serviceUsageAdmin ✅
  - roles/serviceusage.serviceUsageConsumer ✅
  - roles/editor ✅
  - roles/storage.admin (project-level) ✅

- serviceAccount:888522084120-compute@developer.gserviceaccount.com (docuherocopy)
  - roles/storage.admin (project-level) ✅
  - roles/editor (project-level) ✅

### Project Level
Both elliot@docuhero.io and service accounts have extensive permissions including:
- roles/cloudbuild.builds.builder
- roles/cloudbuild.builds.editor
- roles/serviceusage.serviceUsageAdmin
- roles/editor

## Organization Policies - ALL DELETED ✅

Previously had conflicting policies, now deleted:
- constraints/cloudbuild.disableCreateDefaultServiceAccount - DELETED
- constraints/cloudbuild.useBuildServiceAccount - DELETED
- constraints/cloudbuild.useComputeServiceAccount - DELETED

## Code Changes Made

### cloudbuild.yaml
Changed hardcoded project ID to variable:
```yaml
# Before:
availableSecrets:
  secretManager:
    - versionName: projects/docuhero-583a5/secrets/DATABASE_URL/versions/latest
      env: 'DATABASE_URL'

# After:
availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/DATABASE_URL/versions/latest
      env: 'DATABASE_URL'
```

This allows cloudbuild.yaml to work in any project.

## What We Ruled Out

1. ❌ IAM permissions - Same permissions in both projects
2. ❌ Organization policies - All deleted
3. ❌ Service account issues - Same service accounts granted same roles
4. ❌ cloudbuild.yaml syntax - Fixed and works in DocuHeroCopy
5. ❌ Secret Manager access - Works in DocuHeroCopy
6. ❌ Cloud Build API enabled - Both projects have it enabled
7. ❌ Service Usage API enabled - Both projects have it enabled

## What Still Needs Investigation

### Project-Specific Differences to Check:

1. **VPC Service Controls**
   - Could docuhero-583a5 be inside a VPC Service Control perimeter?
   - Command: `gcloud access-context-manager perimeters list --organization=333703630998`

2. **Project-Level Organization Policy Overrides**
   - Are there project-specific policies in docuhero-583a5?
   - Command: `gcloud resource-manager org-policies list --project=docuhero-583a5`

3. **Access Context Manager**
   - Access levels or access policies blocking API calls
   - Check: https://console.cloud.google.com/security/access-context-manager

4. **Audit Logs**
   - What exact permission is being denied?
   - Command: `gcloud logging read 'protoPayload.authenticationInfo.principalEmail="elliot@docuhero.io" AND protoPayload.status.code=7' --project=docuhero-583a5 --limit=5`

5. **API Restrictions**
   - Are there API key restrictions or IP allowlists?
   - Check: https://console.cloud.google.com/apis/credentials?project=docuhero-583a5

6. **Project Metadata/Labels**
   - Any project-level metadata causing issues?
   - Command: `gcloud projects describe docuhero-583a5`

7. **Quota/Rate Limiting**
   - Is docuhero-583a5 hitting quota limits?
   - Check: https://console.cloud.google.com/iam-admin/quotas?project=docuhero-583a5

8. **Billing Account Differences**
   - Different billing accounts between projects?
   - Command: `gcloud beta billing projects describe docuhero-583a5`

9. **Enabled APIs Comparison**
   - Are the same APIs enabled in both projects?
   ```bash
   gcloud services list --enabled --project=docuhero-583a5 > /tmp/docuhero-apis.txt
   gcloud services list --enabled --project=docuherocopy > /tmp/docuherocopy-apis.txt
   diff /tmp/docuhero-apis.txt /tmp/docuherocopy-apis.txt
   ```

10. **Resource Constraints**
    - Organization constraints specific to docuhero-583a5?
    - Command: `gcloud resource-manager org-policies list --project=docuhero-583a5`

## Next Steps

1. **Immediate**: Compare enabled APIs between both projects
2. **High Priority**: Check for VPC Service Controls
3. **High Priority**: Review audit logs for exact permission being denied
4. **Medium Priority**: Check project metadata and labels
5. **Medium Priority**: Verify billing and quotas

## Hypothesis

The fact that DocuHeroCopy works with identical IAM permissions suggests:
- **NOT an IAM/permissions issue**
- **NOT an organization policy issue** (policies apply org-wide)
- **Likely a project-specific security control** (VPC SC, access context, or API restriction)

## Workaround Options if docuhero-583a5 Cannot Be Fixed

1. **Migrate to DocuHeroCopy**: Move production deployment to DocuHeroCopy project
2. **Create New Project**: Set up fresh project without restrictions
3. **Use DocuHeroCopy temporarily**: Deploy from DocuHeroCopy while troubleshooting docuhero-583a5

## Build Status

### DocuHeroCopy
- Last successful build: 497ce34e-c163-4ffc-a638-6657a232fa37
- Build URL: https://console.cloud.google.com/cloud-build/builds/497ce34e-c163-4ffc-a638-6657a232fa37?project=888522084120

### docuhero-583a5
- Cannot submit builds
- No recent successful builds

## Contact/Escalation

If issue persists after checking all project-specific differences:
- Consider opening Google Cloud Support ticket
- Provide this troubleshooting document
- Include build IDs from DocuHeroCopy showing it works elsewhere
