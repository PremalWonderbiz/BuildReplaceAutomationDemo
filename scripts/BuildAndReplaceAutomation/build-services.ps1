#region ============================ Parameters & Environment ============================

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet('All', 'MfesOnly', 'ServicesOnly')]
    [string]$BuildTarget = 'All',

    [Parameter()]
    [switch]$ReplaceBinaries,

    [Parameter()]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version 1
$ErrorActionPreference = "Stop"

[string]$registryKey = "HKLM:\SOFTWARE\WOW6432Node\WonderBiz Technologies\WonderBiz Platform\01.00\Install"
# [string]$registryKey = "HKLM:\SOFTWARE\WOW6432Node\Schneider Electric\EcoStruxure Automation Expert Platform\01.00\Install"
[string]$appPathInMAF = ""

# Set default paths if not provided
# PSScriptRoot is in 'scripts' folder, so go up one level (..) to project root, then into 'src'
$projectRoot = Split-Path $PSScriptRoot -Parent
$ManifestPath = Join-Path (Join-Path $projectRoot "src") "app.manifest.json"
$WorkingDir = Join-Path $projectRoot "src"

#endregion

Import-Module "$PSScriptRoot\build.helpers.psm1" -Force
Import-Module "$PSScriptRoot\modules\mfe.build.psm1" -Force
Import-Module "$PSScriptRoot\modules\service.build.psm1" -Force

#region ============================ Help Function ============================

function Show-CliHelp {
    # Get the current script filename dynamically
    $scriptName = Split-Path -Leaf $PSCommandPath
    
    $helpText = @"
$scriptName - Build and replace MFE and .NET service binaries

Usage: .\$scriptName [options]
   or: .\$scriptName [-ManifestPath <path>] [-WorkingDir <path>] [-BuildTarget <target>] [-ReplaceBinaries]

Automates building of Micro Frontends (MFEs) and .NET services from app.manifest.json configuration.

Options: 
  -BuildTarget <target>      Specify which components to build
                             Values: All (default), MfesOnly, ServicesOnly
  
  -ReplaceBinaries           Copy built binaries to MAF installation after build
                             (requires MAF to be installed)
"@
    
    Write-Host $helpText
}

#endregion

#region ============================ Build Mfes Execution ============================

if ($Help) {
    Show-CliHelp
    exit 0
}

try {
    Write-Host "`n=== Script Execution Started ===" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta

    # Validate paths
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }

    if (-not (Test-Path $WorkingDir)) {
        throw "Working directory not found: $WorkingDir"
    }

    # Resolve to absolute paths
    $ManifestPath = (Resolve-Path $ManifestPath).Path
    $WorkingDir = (Resolve-Path $WorkingDir).Path

    Write-Info "Manifest: $ManifestPath"
    Write-Info "Working Directory: $WorkingDir"

    # Read and parse manifest
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    Write-Info "App: $($manifest.appLabel) v$($manifest.version)"

    #replace binaries validation and path retrieval
    if ($ReplaceBinaries) {
        Write-Info "Replace Binaries flag is set. Built binaries will be copied to MAF installation directory after build."
        
        # Get MAF installation path from registry
        if (-not (Test-Path $registryKey)) {
            throw "Registry not found: $registryKey" #change
        }

        try {
            $pathValue = Get-ItemProperty -Path $registryKey -Name "Path" -ErrorAction Stop
            $mafInstallPath = $pathValue.Path
            Write-Info "MAF Installation Path: $mafInstallPath"
            if (-not (Test-Path $mafInstallPath)) {
                throw "MAF installation path error: Please check if WonderBiz Platform is installed correctly."
            }
            $distRoot = Join-Path (Join-Path $mafInstallPath "MAF") "dist"

            $pattern = "$($manifest.appLabel)-$($manifest.version)-*"

            $appFolder = Get-ChildItem -Path $distRoot -Directory -Filter $pattern -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

            if (-not $appFolder) {
                throw "App is not installed in MAF: $($manifest.appLabel) v$($manifest.version)"
            }

            $appPathInMAF = $appFolder.FullName
            Write-Info "Target MAF App Dist Path: $appPathInMAF"
        }
        catch {
            throw "$_"
        }
    }

    $results = @{
        MfesTotal        = 0
        MfesSuccess      = 0
        MfesFailed       = 0
        ServicesTotal    = 0
        ServicesSuccess  = 0
        ServicesFailed   = 0
        MfesReplaced     = 0
        ServicesReplaced = 0
    }

    # Build Services
    if ($BuildTarget -in @('All', 'ServicesOnly') -and $manifest.services) {
        Write-Host "`n=== Building Services ($($manifest.services.Count)) ===" -ForegroundColor Blue
        Write-Host "`=== Total Services found in app manifest : ($($manifest.services.Count)) ===" -ForegroundColor Blue
        Write-Host "============================================" -ForegroundColor Blue

        foreach ($service in $manifest.services) {
            $results.ServicesTotal++
            $result = Build-Service -Service $service -BaseDir $WorkingDir -MafPath $(if ($ReplaceBinaries) { $appPathInMAF } else { "" })
            if ($result.BuildSuccess) {
                $results.ServicesSuccess++
                if ($result.CopySuccess) {
                    $results.ServicesReplaced++
                }
            }
            else {
                $results.ServicesFailed++
            }
            Write-Host ""
        }
    }

    # Summary
    Write-Host "`n=== Build Summary ===" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta

    if ($results.MfesTotal -gt 0) {
        Write-Host "  MFEs:     $($results.MfesSuccess)/$($results.MfesTotal) successful" `
            -ForegroundColor ($(if ($results.MfesFailed -eq 0) { "Green" } else { "Yellow" }))
    }

    if ($results.ServicesTotal -gt 0) {
        Write-Host "  Services: $($results.ServicesSuccess)/$($results.ServicesTotal) successful" `
            -ForegroundColor ($(if ($results.ServicesFailed -eq 0) { "Green" } else { "Yellow" }))
    }

    if ($ReplaceBinaries) {
        Write-Host "`n=== Replace Binaries Summary ===" -ForegroundColor Magenta
        Write-Host "============================================" -ForegroundColor Magenta
        
        if ($results.MfesTotal -gt 0) {
            Write-Host "  MFEs:     $($results.MfesReplaced)/$($results.MfesSuccess) binaries replaced" `
                -ForegroundColor ($(if ($results.MfesReplaced -eq $results.MfesSuccess) { "Green" } else { "Yellow" }))
        }
        
        if ($results.ServicesTotal -gt 0) {
            Write-Host "  Services: $($results.ServicesReplaced)/$($results.ServicesSuccess) binaries replaced" `
                -ForegroundColor ($(if ($results.ServicesReplaced -eq $results.ServicesSuccess) { "Green" } else { "Yellow" }))
        }
    }

    $totalFailed = $results.MfesFailed + $results.ServicesFailed

    if ($totalFailed -eq 0) {
        Write-Host "`n[SUCCESS] All builds completed successfully!" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "`n[WARN] Build completed with $totalFailed failure(s)" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Fail "Script failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion
