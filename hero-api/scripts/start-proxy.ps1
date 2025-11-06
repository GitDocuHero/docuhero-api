# Start Cloud SQL Proxy for Local Development
# This script starts the Cloud SQL Proxy to connect to your private Cloud SQL instance

param(
    [string]$ProjectId = "",
    [string]$InstanceName = "docuhero-db",
    [string]$Region = "us-east1",
    [int]$Port = 5433
)

# Check if cloud-sql-proxy is installed
if (-not (Get-Command cloud-sql-proxy -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: cloud-sql-proxy is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install it first. See scripts/install-cloud-sql-proxy.md" -ForegroundColor Yellow
    exit 1
}

# Check if ProjectId is provided
if ([string]::IsNullOrEmpty($ProjectId)) {
    # Try to get from gcloud config
    $ProjectId = gcloud config get-value project 2>$null
    if ([string]::IsNullOrEmpty($ProjectId)) {
        Write-Host "ERROR: Project ID not found. Please provide it:" -ForegroundColor Red
        Write-Host "  .\scripts\start-proxy.ps1 -ProjectId YOUR_PROJECT_ID" -ForegroundColor Yellow
        exit 1
    }
}

$ConnectionName = "${ProjectId}:${Region}:${InstanceName}"

Write-Host "Starting Cloud SQL Proxy..." -ForegroundColor Green
Write-Host "  Project: $ProjectId" -ForegroundColor Cyan
Write-Host "  Instance: $InstanceName" -ForegroundColor Cyan
Write-Host "  Region: $Region" -ForegroundColor Cyan
Write-Host "  Local Port: $Port" -ForegroundColor Cyan
Write-Host "  Connection: $ConnectionName" -ForegroundColor Cyan
Write-Host ""
Write-Host "Connecting to: localhost:$Port" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the proxy" -ForegroundColor Yellow
Write-Host ""

# Start the proxy with private IP (required for instances without public IP)
cloud-sql-proxy --port $Port --private-ip $ConnectionName

