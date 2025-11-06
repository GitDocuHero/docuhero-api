# Installing Cloud SQL Proxy on Windows

## Option 1: Using Chocolatey (Recommended)
If you have Chocolatey installed:
```powershell
choco install cloud-sql-proxy
```

## Option 2: Manual Installation

1. Download the Windows 64-bit version:
   - Go to: https://github.com/GoogleCloudPlatform/cloud-sql-proxy/releases/latest
   - Download: `cloud-sql-proxy-x64.exe` (or `cloud-sql-proxy-x86.exe` for 32-bit)

2. Rename and move to a location in your PATH:
   ```powershell
   # Create a bin directory (if it doesn't exist)
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\bin"
   
   # Move the downloaded file
   Move-Item -Path ".\cloud-sql-proxy-x64.exe" -Destination "$env:USERPROFILE\bin\cloud-sql-proxy.exe"
   
   # Add to PATH (add this to your PowerShell profile)
   $env:Path += ";$env:USERPROFILE\bin"
   ```

3. Verify installation:
   ```powershell
   cloud-sql-proxy --version
   ```

## Option 3: Using Go (if you have Go installed)
```powershell
go install github.com/GoogleCloudPlatform/cloud-sql-proxy/v2/cmd/cloud-sql-proxy@latest
```

