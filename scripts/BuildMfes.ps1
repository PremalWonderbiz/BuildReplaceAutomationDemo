#!/usr/bin/env pwsh

# BuildMfes.ps1
# Builds all MFEs defined in app.manifest.json
#
# Usage (standalone):  .\BuildMfes.ps1
# Usage (dot-sourced): . "$PSScriptRoot\BuildMfes.ps1"   <- used by BuildAndReplaceBinaries.ps1
#
# When dot-sourced: only function definitions are loaded into the caller's scope.
# When run directly: full standalone execution (config load, manifest read, build loop, summary).

#region ============================ Imports ============================

# Load all shared utilities (console helpers, config validation, environment init, build loops, etc.)
. "$PSScriptRoot\Shared.ps1"

#endregion

#region ============================ Help Function ============================

function Show-CliHelp {
    # Get the current script filename dynamically
    $scriptName = Split-Path -Leaf $PSCommandPath

    $helpText = @"
$scriptName - Build all MFEs defined in app.manifest.json

Usage: .\$scriptName [options]

Automates building of all Micro Frontends (MFEs) from app.manifest.json configuration.
Detects the package manager automatically (pnpm, yarn, npm) per MFE.

Options:
  -Help, -h                  Show this help message
"@

    Show-ScriptHelp -HelpText $helpText
}

#endregion

#region ============================ File Copy Helpers ============================

function Copy-MfeBuildFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string]$MfeLabel,

        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetBasePath,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    try {
        $mfesDir = Join-Path $TargetBasePath "mfes"
        
        # Find MFE folder matching pattern: mfe-label-version-*
        $mfeFolders = @(Get-ChildItem -Path $mfesDir -Directory -Filter "$MfeLabel*" -ErrorAction SilentlyContinue)
        
        if ($mfeFolders.Count -eq 0) {
            Write-Warn "MFE '$MfeLabel' not installed in MAF. Skipping replace binaries for this MFE."
            return $false
        }

        $mfeFolder = $mfeFolders[0].FullName
        
        # Find version folder inside MFE folder
        $versionFolders = @(Get-ChildItem -Path $mfeFolder -Directory -Filter "$Version*" -ErrorAction SilentlyContinue)
        
        if ($versionFolders.Count -eq 0) {
            Write-Warn "Version folder not found for '$MfeLabel' in MAF. Skipping replace binaries for this MFE."
            return $false
        }

        $targetPath = $versionFolders[0].FullName
        
        # Source dist folder
        $distPath = Join-Path $SourcePath "dist"
        
        if (-not (Test-Path $distPath)) {
            Write-Warn "Build output folder not found: $distPath"
            return $false
        }

        Write-Info "Replacing MFE binaries in MAF..."
        Write-Host "  From: $distPath" -ForegroundColor Gray
        Write-Host "  To:   $targetPath" -ForegroundColor Gray

        # Copy files from dist to target
        if (-not (Test-Path $targetPath)) {
            Write-Warn "Target mfe folder not found in MAF: $targetPath. Skipping replace binaries for this service."
            return $false
        }
        Remove-Item "$targetPath\*" -Recurse -Force
        Copy-Item -Path (Join-Path $distPath "*") -Destination $targetPath -Recurse -Force -ErrorAction Stop
        
        Write-Success "MFE '$MfeLabel' binaries replaced successfully"
        return $true
    }
    catch {
        Write-Fail "Failed to replace MFE binaries: $_"
        return $false
    }
}

#endregion

#region ============================ MFE Build Logic ============================

function Build-MFE {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Mfe,

        [Parameter(Mandatory = $true)]
        [string]$BaseDir,

        [Parameter(Mandatory = $false)]
        [string]$MafPath = "",

        [Parameter(Mandatory = $false)]
        [string]$Version = ""
    )

    $label = $Mfe.label
    $mfePath = Join-Path (Join-Path $BaseDir "mfes") $label
    
    # check $mfePath exists
    if (-not (Test-Path $mfePath)) {
        Write-Warn "Skipping MFE '$label': Path not found ($mfePath)"
        return @{
            BuildSuccess = $false
            CopySuccess  = $false
        }
    }

    Write-Info "Building MFE: $label"
    Write-Host "  Path: $mfePath" -ForegroundColor Gray

    Push-Location $mfePath
    try {
        # Check for package manager
        $packageManager =
        if (Test-Path "pnpm-lock.yaml") { "pnpm" }
        elseif (Test-Path "yarn.lock") { "yarn" }
        elseif (Test-Path "package-lock.json") { "npm" }
        else { $defaultPackageManager }

        if (-not (Test-CommandExists $packageManager)) {
            throw "$packageManager is not installed or not in PATH"
        }

        Write-Host "  Using: $packageManager" -ForegroundColor Gray

        # Install dependencies if node_modules doesn't exist
        if (-not (Test-Path "node_modules")) {
            Write-Host "  Command: $packageManager install" -ForegroundColor Gray
            Write-Info "Installing dependencies..."
            $output = switch ($packageManager) {
                "npm" { npm install }
                "pnpm" { pnpm install }
                "yarn" { yarn install }
                default { throw "Unsupported package manager: $packageManager" }
            }

            $outputStr = $output -join "`n" 
            Write-Host "$outputStr" -ForegroundColor Gray

            if ($LASTEXITCODE -ne 0) {
                throw "Dependency installation failed with exit code $LASTEXITCODE"
            }
        }

        # Build
        Write-Host "  Command: $packageManager run build" -ForegroundColor Gray
        Write-Info "Running build..."

        $output = ""
        $output = switch ($packageManager) {
            "npm" { npm run build }
            "pnpm" { pnpm run build }
            "yarn" { yarn run build }
            default { throw "Unsupported package manager: $packageManager" }
        }
        
        $outputStr = $output -join "`n" 
        Write-Host "$outputStr" -ForegroundColor Gray
        # Write-Host "  Build Exit Code: $buildExitCode" -ForegroundColor Gray

        $buildExitCode = $LASTEXITCODE

        if ($buildExitCode -ne 0) {
            throw "Build failed with exit code $buildExitCode"
        }

        Write-Success "MFE '$label' built successfully"
        
        # Copy build files to MAF if path is provided
        $copySuccess = $false
        if ($MafPath -and $Version) {
            $copySuccess = Copy-MfeBuildFiles -MfeLabel $label -SourcePath $mfePath -TargetBasePath $MafPath -Version $Version
        }
        
        return @{
            BuildSuccess = $true
            CopySuccess  = $copySuccess
        }
    }
    catch {
        Write-Fail "Failed to build MFE '$label': $_"
        return @{
            BuildSuccess = $false
            CopySuccess  = $false
        }
    }
    finally {
        Pop-Location
    }
}

#endregion

#region ============================ Standalone Execution ============================

# This block runs ONLY when the script is invoked directly (e.g. .\BuildMfes.ps1).
# When dot-sourced by BuildAndReplaceBinaries.ps1, InvocationName is '.' and this block is skipped —
# only the function definitions above are loaded into the caller's scope.
if ($MyInvocation.InvocationName -ne '.') {

    # Display help if requested (no param block by design — args checked manually)
    if ($args -contains '-Help' -or $args -contains '-h') {
        Show-CliHelp
        exit 0
    }

    Invoke-StandaloneScript {
        $env = Initialize-BuildEnvironment -ScriptRoot $PSScriptRoot

        # Build MFEs
        $results = Invoke-MfeBuildLoop -Manifest $env.Manifest -WorkingDir $env.WorkingDir `
            -DefaultPackageManager $env.Config.defaultPackageManager

        # Summary
        Write-BuildSummaryBanner
        Write-MfeBuildSummary -Results $results

        Exit-WithBuildResult -FailedCount $results.MfesFailed `
            -SuccessMessage "All MFE builds completed successfully!" `
            -FailPrefix "MFE build completed"
    }
}

#endregion