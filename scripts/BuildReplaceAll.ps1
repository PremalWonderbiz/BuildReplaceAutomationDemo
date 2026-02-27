#!/usr/bin/env pwsh

#region ============================ Parameters & Environment ============================

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$ReplaceBinaries,

    [Parameter()]
    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version 1
$ErrorActionPreference = "Stop"

[string]$appPathInMAF = ""

#endregion

#region ============================ Imports ============================

# Load all shared utilities (console helpers, config validation, environment init, build loops, etc.)
. "$PSScriptRoot\Shared.ps1"

# Dot-source build scripts to load their functions into this script's scope.
# The standalone execution block inside each is automatically skipped when dot-sourced.
. "$PSScriptRoot\BuildReplaceMfes.ps1"
. "$PSScriptRoot\BuildReplaceServices.ps1"

#endregion

#region ============================ Help Function ============================

function Show-CliHelp {
    # Get the current script filename dynamically
    $scriptName = Split-Path -Leaf $PSCommandPath

    $helpText = @"
$scriptName - Build and replace MFE and .NET service binaries

Usage: .\$scriptName [options]
   or: .\$scriptName [-ReplaceBinaries]

Automates building of Micro Frontends (MFEs) and .NET services from app.manifest.json configuration.

Options:
  -ReplaceBinaries           Copy built binaries to MAF installation after build
                             (requires MAF to be installed)

  -Help, -h                  Show this help message
"@

    Show-ScriptHelp -HelpText $helpText
}

#endregion

#region ============================ Main Execution ============================

# Display help if requested
if ($Help) {
    Show-CliHelp
    exit 0
}


try {
    #region ============================ Environment Initialization ============================
    # Load config, validate paths, read manifest, and print startup banner
    $env = Initialize-BuildEnvironment -ScriptRoot $PSScriptRoot
    [string]$registryKey = $env.Config.registryKey
    [string]$defaultPackageManager = $env.Config.defaultPackageManager
    $manifest = $env.Manifest
    $WorkingDir = $env.WorkingDir
    #endregion

    #replace binaries validation and path retrieval
    if ($ReplaceBinaries) {
        $appPathInMAF = Resolve-MafAppPath -RegistryKey $registryKey `
            -AppLabel $manifest.appLabel `
            -Version $manifest.version
    }

    # Build MFEs
    $mfeResults = Invoke-MfeBuildLoop -Manifest $manifest -WorkingDir $WorkingDir `
        -DefaultPackageManager $defaultPackageManager `
        -MafPath $(if ($ReplaceBinaries) { $appPathInMAF } else { "" }) `
        -Version $manifest.version

    # Build Services
    $serviceResults = Invoke-ServiceBuildLoop -Manifest $manifest -WorkingDir $WorkingDir `
        -MafPath $(if ($ReplaceBinaries) { $appPathInMAF } else { "" })

    # Summary
    Write-BuildSummaryBanner
    Write-MfeBuildSummary -Results $mfeResults
    Write-ServiceBuildSummary -Results $serviceResults

    if ($ReplaceBinaries) {
        Write-Host "`n=== Replace Binaries Summary ===" -ForegroundColor Magenta
        Write-Host "============================================" -ForegroundColor Magenta
        Write-MfeReplaceSummary -Results $mfeResults
        Write-ServiceReplaceSummary -Results $serviceResults
    }

    Exit-WithBuildResult -FailedCount ($mfeResults.MfesFailed + $serviceResults.ServicesFailed) `
        -SuccessMessage "All builds completed successfully!" `
        -FailPrefix "Build completed"
}
catch {
    Write-Fail "Script failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion