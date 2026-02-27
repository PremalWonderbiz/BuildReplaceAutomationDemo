#!/usr/bin/env pwsh

# BuildReplaceServices.ps1
# Builds all .NET services defined in app.manifest.json
#
# Usage (standalone):  .\BuildReplaceServices.ps1
# Usage (dot-sourced): . "$PSScriptRoot\BuildReplaceServices.ps1"   <- used by BuildReplaceAll.ps1
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
$scriptName - Build all .NET services defined in app.manifest.json

Usage: .\$scriptName [options]

Automates building of all .NET services from app.manifest.json configuration.
Locates each service's .csproj automatically and builds in Release configuration.

Options:
  -ReplaceBinaries           Copy built binaries to MAF installation after build
                             (requires MAF to be installed)

  -Help, -h                  Show this help message
"@

    Show-ScriptHelp -HelpText $helpText
}

#endregion

#region ============================ File Copy Helpers ============================

function Copy-ServiceBuildFiles {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceLabel,

        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetBasePath,

        [Parameter(Mandatory = $true)]
        [string]$Framework
    )

    try {
        $servicesDir = Join-Path $TargetBasePath "services"
        
        # Find service folder matching pattern: service-label-*
        $serviceFolders = @(Get-ChildItem -Path $servicesDir -Directory -Filter "$ServiceLabel*" -ErrorAction SilentlyContinue)
        
        if ($serviceFolders.Count -eq 0) {
            Write-Warn "Service '$ServiceLabel' not installed in MAF. Skipping replace binaries for this service."
            return $false
        }

        $targetPath = $serviceFolders[0].FullName
        
        # Source bin folder (bin/Release/framework)
        $binPath = Join-Path $SourcePath "bin" | Join-Path -ChildPath "Release" | Join-Path -ChildPath $Framework
        
        if (-not (Test-Path $binPath)) {
            Write-Warn "Build output folder not found: $binPath"
            return $false
        }

        Write-Info "Replacing Service binaries in MAF..."
        Write-Host "  From: $binPath" -ForegroundColor Gray
        Write-Host "  To:   $targetPath" -ForegroundColor Gray

        # Copy files from bin to target
        if (-not (Test-Path $targetPath)) {
            Write-Warn "Target service folder not found in MAF: $targetPath. Skipping replace binaries for this service."
            return $false
        }
        Remove-Item "$targetPath\*" -Recurse -Force
        Copy-Item -Path (Join-Path $binPath "*") -Destination $targetPath -Recurse -Force -ErrorAction Stop
        
        Write-Success "Service '$ServiceLabel' binaries replaced successfully"
        return $true
    }
    catch {
        Write-Fail "Failed to replace Service binaries: $_"
        return $false
    }
}

#endregion

#region ============================ Service Build Logic ============================

function Build-Service {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Service,

        [Parameter(Mandatory = $true)]
        [string]$BaseDir,

        [Parameter(Mandatory = $false)]
        [string]$MafPath = ""
    )

    $label = $Service.microserviceLabel
    $servicesDir = Join-Path $BaseDir "services"

    # Find label.csproj file at any level under services directory
    $csprojFiles = @(Get-ChildItem -Path $servicesDir -Filter "$label.csproj" -Recurse -ErrorAction SilentlyContinue)

    if ($csprojFiles.Count -eq 0) {
        Write-Warn "Skipping service '$label': $label.csproj file not found under $servicesDir"
        return @{
            BuildSuccess = $false
            CopySuccess  = $false
        }
    }

    $csprojPath = $csprojFiles[0].FullName
    $servicePath = Split-Path $csprojPath -Parent

    Write-Info "Building Service: $label"
    Write-Host "  Path: $servicePath" -ForegroundColor Gray
    Write-Host "  Project: $($csprojFiles[0].Name)" -ForegroundColor Gray

    try {
        if (-not (Test-CommandExists "dotnet")) {
            throw "dotnet CLI is not installed or not in PATH"
        }

        $framework = $Service.framework
        $buildArgs = @("build", $csprojPath, "-c", "Release")

        if ($framework) {
            $buildArgs += @("-f", $framework)
            Write-Host "  Framework: $framework" -ForegroundColor Gray
        }

        & dotnet @buildArgs | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Build failed" }

        Write-Success "Service '$label' built successfully"
        
        # Copy build files to MAF if path is provided
        $copySuccess = $false
        if ($MafPath -and $framework) {
            $copySuccess = Copy-ServiceBuildFiles -ServiceLabel $label -SourcePath $servicePath -TargetBasePath $MafPath -Framework $framework
        }
        
        return @{
            BuildSuccess = $true
            CopySuccess  = $copySuccess
        }
    }
    catch {
        Write-Fail "Failed to build service '$label': $_"
        return @{
            BuildSuccess = $false
            CopySuccess  = $false
        }
    }
}

#endregion

#region ============================ Standalone Execution ============================

# This block runs ONLY when the script is invoked directly (e.g. .\BuildReplaceServices.ps1).
# When dot-sourced by BuildReplaceAll.ps1, InvocationName is '.' and this block is skipped —
# only the function definitions above are loaded into the caller's scope.
if ($MyInvocation.InvocationName -ne '.') {

    # Display help if requested (no param block by design — args checked manually)
    if ($args -contains '-Help' -or $args -contains '-h') {
        Show-CliHelp
        exit 0
    }

    # Parse -ReplaceBinaries from args (no param block by design — args checked manually)
    $replaceBinaries = $args -contains '-ReplaceBinaries'

    Invoke-StandaloneScript {
        $env = Initialize-BuildEnvironment -ScriptRoot $PSScriptRoot

        # Resolve MAF app path if ReplaceBinaries was requested
        $mafPath = ""
        if ($replaceBinaries) {
            $mafPath = Resolve-MafAppPath -RegistryKey $env.Config.registryKey `
                -AppLabel $env.Manifest.appLabel `
                -Version $env.Manifest.version
        }

        # Build Services
        $results = Invoke-ServiceBuildLoop -Manifest $env.Manifest -WorkingDir $env.WorkingDir `
            -MafPath $mafPath

        # Summary
        Write-BuildSummaryBanner
        Write-ServiceBuildSummary -Results $results

        if ($replaceBinaries) {
            Write-Host "`n=== Replace Binaries Summary ===" -ForegroundColor Magenta
            Write-Host "============================================" -ForegroundColor Magenta
            Write-ServiceReplaceSummary -Results $results
        }

        Exit-WithBuildResult -FailedCount $results.ServicesFailed `
            -SuccessMessage "All Service builds completed successfully!" `
            -FailPrefix "Service build completed"
    }
}

#endregion