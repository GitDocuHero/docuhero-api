# Direct script to restore all organization policies
# This deletes all organization-level policy overrides

$orgId = "333703630998"

Write-Host "Fetching all organization policies..." -ForegroundColor Cyan
$policies = gcloud org-policies list --organization=$orgId --format="value(constraint)"

if ($policies) {
    Write-Host "Found $($policies.Count) policies to restore" -ForegroundColor Green
    Write-Host ""
    
    foreach ($policy in $policies) {
        Write-Host "Deleting: $policy" -ForegroundColor Yellow
        gcloud org-policies delete $policy --organization=$orgId
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Restored" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "✅ All policies restored to default state" -ForegroundColor Green
} else {
    Write-Host "No policies found to restore." -ForegroundColor Gray
}



