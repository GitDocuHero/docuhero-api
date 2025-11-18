# Script to restore all organization policies to default state
# This deletes organization-level policy overrides, restoring defaults
# Usage: .\scripts\restore-org-policies.ps1 [-OrganizationId "333703630998"] [-WhatIf]

param(
    [Parameter(Mandatory=$false)]
    [string]$OrganizationId = "333703630998",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

Write-Host "=== Restoring Organization Policies to Default ===" -ForegroundColor Cyan
Write-Host "Organization: $OrganizationId" -ForegroundColor Yellow
if ($WhatIf) {
    Write-Host "MODE: What-If (no changes will be made)" -ForegroundColor Yellow
} else {
    Write-Host "⚠️  WARNING: This will delete ALL organization policy overrides!" -ForegroundColor Red
    Write-Host "Policies will revert to their default/inherited state." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to cancel, or wait 5 seconds to continue..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}
Write-Host ""

# Get all policies
Write-Host "Fetching all organization policies..." -ForegroundColor Cyan
$allPolicies = gcloud org-policies list --organization=$OrganizationId --format="json" | ConvertFrom-Json

if ($allPolicies.Count -eq 0) {
    Write-Host "No policies found." -ForegroundColor Gray
    exit 0
}

Write-Host "Found $($allPolicies.Count) policies to restore" -ForegroundColor Green
Write-Host ""

$successCount = 0
$skipCount = 0
$errorCount = 0
$results = @()

foreach ($policy in $allPolicies) {
    $constraint = $policy.constraint
    
    Write-Host "Processing: $constraint" -ForegroundColor Yellow
    
    if ($WhatIf) {
        Write-Host "  [WHAT-IF] Would delete this policy override" -ForegroundColor Cyan
        $results += @{
            Name = $constraint
            Status = "Would_Delete"
            Success = $true
        }
    } else {
        try {
            Write-Host "  Deleting policy override..." -ForegroundColor Cyan
            gcloud org-policies delete $constraint --organization=$OrganizationId 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ Policy restored to default!" -ForegroundColor Green
                $successCount++
                $results += @{
                    Name = $constraint
                    Status = "Restored"
                    Success = $true
                }
            } else {
                Write-Host "  ❌ Failed to delete policy" -ForegroundColor Red
                $errorCount++
                $results += @{
                    Name = $constraint
                    Status = "Failed"
                    Success = $false
                }
            }
        } catch {
            Write-Host "  ❌ Error: $_" -ForegroundColor Red
            $errorCount++
            $results += @{
                Name = $constraint
                Status = "Error"
                Success = $false
            }
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "Would restore: $($results.Count) policies" -ForegroundColor Yellow
} else {
    Write-Host "✅ Successfully restored: $successCount policies" -ForegroundColor Green
    Write-Host "⏭️  Skipped: $skipCount policies" -ForegroundColor Gray
    Write-Host "❌ Errors: $errorCount policies" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Gray" })
}

Write-Host ""
Write-Host "ℹ️  Note: Policy deletions take effect immediately" -ForegroundColor Cyan
Write-Host "   Policies are now restored to their default/inherited state." -ForegroundColor Gray






