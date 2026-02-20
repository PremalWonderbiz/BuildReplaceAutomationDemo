#!/usr/bin/env pwsh

# Shared.ps1
# Shared utilities used by BuildAndReplaceBinaries.ps1, BuildMfes.ps1 and BuildServices.ps1
# This file contains only function definitions — no execution logic.
# It is always loaded via dot-source:  . "$PSScriptRoot\Shared.ps1"

#region ============================ Console Output Helpers ============================

function Write-Info { Write-Host "[INFO] $args"    -ForegroundColor Cyan }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args"    -ForegroundColor Yellow }
function Write-Fail { Write-Host "[ERROR] $args"   -ForegroundColor Red }

#endregion

#region ============================ Utility Functions ============================

function Test-CommandExists {
    param ([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Read-AndValidateBuildConfig {
    param ([string]$ConfigPath)

    # File existence
    if (-not (Test-Path $ConfigPath)) {
        throw "Script config file not found: $ConfigPath"
    }

    # Valid JSON
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Script config is not valid JSON: $_"
    }

    # Required fields
    $requiredFields = @("registryKey", "defaultPackageManager")
    foreach ($field in $requiredFields) {
        if (-not $config.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace($config.$field)) {
            if ($field -eq "registrykey" -and !$ReplaceBinaries) {
                continue
            }
            throw "Script config is missing required field: '$field'"
        }
    }

    # Value validation

    $validPMs = @("npm", "pnpm", "yarn")
    if ($config.defaultPackageManager -notin $validPMs) {
        throw "Script config 'defaultPackageManager' must be one of: $($validPMs -join ', '). Got: '$($config.defaultPackageManager)'"
    }

    return $config
}

#endregion

#region ============================ Environment Initialization ============================

function Initialize-BuildEnvironment {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptRoot
    )

    # Load and validate config
    $configPath = Join-Path $ScriptRoot "BuildAndReplace.config.json"
    $buildConfig = Read-AndValidateBuildConfig -ConfigPath $configPath

    # Derive paths
    # ScriptRoot is in 'scripts' folder, so go up one level (..) to project root, then into 'src'
    $projectRoot = Split-Path $ScriptRoot -Parent
    $manifestPath = Join-Path (Join-Path $projectRoot "src") "app.manifest.json"
    $workingDir = Join-Path $projectRoot "src"

    # Validate paths
    if (-not (Test-Path $manifestPath)) {
        throw "Manifest file not found: $manifestPath"
    }

    if (-not (Test-Path $workingDir)) {
        throw "Working directory not found: $workingDir"
    }

    # Resolve to absolute paths
    $manifestPath = (Resolve-Path $manifestPath).Path
    $workingDir = (Resolve-Path $workingDir).Path

    # Read and parse manifest
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    # Startup banner
    Write-Host "`n=== Script Execution Started ===" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
    Write-Info "Manifest: $manifestPath"
    Write-Info "Working Directory: $workingDir"
    Write-Info "App: $($manifest.appLabel) v$($manifest.version)"

    return @{
        Config       = $buildConfig
        ManifestPath = $manifestPath
        WorkingDir   = $workingDir
        Manifest     = $manifest
    }
}

#endregion

#region ============================ MFE Build Loop & Summary ============================

function Invoke-MfeBuildLoop {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDir,

        [Parameter(Mandatory = $true)]
        [string]$DefaultPackageManager,

        [Parameter(Mandatory = $false)]
        [string]$MafPath = "",

        [Parameter(Mandatory = $false)]
        [string]$Version = ""
    )

    $results = @{
        MfesTotal    = 0
        MfesSuccess  = 0
        MfesFailed   = 0
        MfesReplaced = 0
    }

    if (-not $Manifest.mfes) { return $results }

    Write-Host "`n=== Building MFEs ===" -ForegroundColor Blue
    Write-Host "`=== Total MFEs found in app manifest : ($($Manifest.mfes.Count)) ===" -ForegroundColor Blue
    Write-Host "============================================" -ForegroundColor Blue

    foreach ($mfe in $Manifest.mfes) {
        $results.MfesTotal++
        # Set $defaultPackageManager in this scope so Build-MFE can resolve it via dynamic scoping
        $defaultPackageManager = $DefaultPackageManager
        $result = Build-MFE -Mfe $mfe -BaseDir $WorkingDir -MafPath $MafPath -Version $Version
        if ($result.BuildSuccess) {
            $results.MfesSuccess++
            if ($result.CopySuccess) { $results.MfesReplaced++ }
        }
        else {
            $results.MfesFailed++
        }
        Write-Host ""
    }

    return $results
}

function Write-MfeBuildSummary {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Results
    )

    if ($Results.MfesTotal -gt 0) {
        Write-Host "  MFEs:     $($Results.MfesSuccess)/$($Results.MfesTotal) successful" `
            -ForegroundColor ($(if ($Results.MfesFailed -eq 0) { "Green" } else { "Yellow" }))
    }
}

function Write-MfeReplaceSummary {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Results
    )

    if ($Results.MfesTotal -gt 0) {
        Write-Host "  MFEs:     $($Results.MfesReplaced)/$($Results.MfesSuccess) binaries replaced" `
            -ForegroundColor ($(if ($Results.MfesReplaced -eq $Results.MfesSuccess) { "Green" } else { "Yellow" }))
    }
}

#endregion

#region ============================ Service Build Loop & Summary ============================

function Invoke-ServiceBuildLoop {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDir,

        [Parameter(Mandatory = $false)]
        [string]$MafPath = ""
    )

    $results = @{
        ServicesTotal    = 0
        ServicesSuccess  = 0
        ServicesFailed   = 0
        ServicesReplaced = 0
    }

    if (-not $Manifest.services) { return $results }

    Write-Host "`n=== Building Services ($($Manifest.services.Count)) ===" -ForegroundColor Blue
    Write-Host "`=== Total Services found in app manifest : ($($Manifest.services.Count)) ===" -ForegroundColor Blue
    Write-Host "============================================" -ForegroundColor Blue

    foreach ($service in $Manifest.services) {
        $results.ServicesTotal++
        $result = Build-Service -Service $service -BaseDir $WorkingDir -MafPath $MafPath
        if ($result.BuildSuccess) {
            $results.ServicesSuccess++
            if ($result.CopySuccess) { $results.ServicesReplaced++ }
        }
        else {
            $results.ServicesFailed++
        }
        Write-Host ""
    }

    return $results
}

function Write-ServiceBuildSummary {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Results
    )

    if ($Results.ServicesTotal -gt 0) {
        Write-Host "  Services: $($Results.ServicesSuccess)/$($Results.ServicesTotal) successful" `
            -ForegroundColor ($(if ($Results.ServicesFailed -eq 0) { "Green" } else { "Yellow" }))
    }
}

function Write-ServiceReplaceSummary {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Results
    )

    if ($Results.ServicesTotal -gt 0) {
        Write-Host "  Services: $($Results.ServicesReplaced)/$($Results.ServicesSuccess) binaries replaced" `
            -ForegroundColor ($(if ($Results.ServicesReplaced -eq $Results.ServicesSuccess) { "Green" } else { "Yellow" }))
    }
}

#endregion

#region ============================ MAF Path Resolution ============================

function Resolve-MafAppPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RegistryKey,

        [Parameter(Mandatory = $true)]
        [string]$AppLabel,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    Write-Info "Replace Binaries flag is set. Built binaries will be copied to MAF installation directory after build."

    # Get MAF installation path from registry
    if (-not (Test-Path $RegistryKey)) {
        throw "Registry not found: $RegistryKey"
    }

    try {
        $pathValue = Get-ItemProperty -Path $RegistryKey -Name "Path" -ErrorAction Stop
        $mafInstallPath = $pathValue.Path
        Write-Info "MAF Installation Path: $mafInstallPath"

        if (-not (Test-Path $mafInstallPath)) {
            throw "MAF installation path error: Please check if WonderBiz Platform is installed correctly."
        }

        $distRoot = Join-Path (Join-Path $mafInstallPath "MAF") "dist"
        $pattern = "$AppLabel-$Version-*"

        $appFolder = Get-ChildItem -Path $distRoot -Directory -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

        if (-not $appFolder) {
            throw "App is not installed in MAF: $AppLabel v$Version"
        }

        Write-Info "Target MAF App Dist Path: $($appFolder.FullName)"
        return $appFolder.FullName
    }
    catch {
        throw "$_"
    }
}

#endregion

#region ============================ Script Execution Helpers ============================

function Show-ScriptHelp {
    param (
        [Parameter(Mandatory = $true)]
        [string]$HelpText
    )

    Write-Host $HelpText
}

function Write-BuildSummaryBanner {
    Write-Host "`n=== Build Summary ===" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta
}

function Exit-WithBuildResult {
    param (
        [Parameter(Mandatory = $true)]
        [int]$FailedCount,

        [Parameter(Mandatory = $true)]
        [string]$SuccessMessage,

        [Parameter(Mandatory = $true)]
        [string]$FailPrefix
    )

    if ($FailedCount -eq 0) {
        Write-Host "`n[SUCCESS] $SuccessMessage" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "`n[WARN] $FailPrefix with $FailedCount failure(s)" -ForegroundColor Yellow
        exit 1
    }
}

function Invoke-StandaloneScript {
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]$Body
    )

    Set-StrictMode -Version 1
    $ErrorActionPreference = "Stop"

    try {
        & $Body
    }
    catch {
        Write-Fail "Script failed: $_"
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
}

#endregion