#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds MFEs and services based on app.manifest.json configuration.

.DESCRIPTION
    Reads app.manifest.json, iterates through MFEs and services, and builds each project
    if the required configuration file exists (package.json for MFEs, .csproj for services).

.PARAMETER ManifestPath
    Path to the app.manifest.json file. Defaults to ../src/app.manifest.json

.PARAMETER WorkingDir
    Base working directory. Defaults to ../src

.PARAMETER BuildTarget
    Specifies what to build: 'All' (default), 'MfesOnly', or 'ServicesOnly'

.PARAMETER ReplaceBinaries
    If set, copies built binaries to MAF installation directory after successful build

.EXAMPLE
    .\build-projects.ps1
    .\build-projects.ps1 -ManifestPath "./custom-manifest.json"
    .\build-projects.ps1 -BuildTarget MfesOnly
    .\build-projects.ps1 -BuildTarget ServicesOnly
    .\build-projects.ps1 -ReplaceBinaries
#>

#region ============================ Parameters & Environment ============================

[CmdletBinding()]
param (
    [Parameter()]
    [string]$ManifestPath,

    [Parameter()]
    [string]$WorkingDir,

    [Parameter()]
    [ValidateSet('All', 'MfesOnly', 'ServicesOnly')]
    [string]$BuildTarget = 'All',

    [Parameter()]
    [switch]$ReplaceBinaries
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

[string]$registryKey = "HKLM:\SOFTWARE\WOW6432Node\WonderBiz Technologies\WonderBiz Platform\01.00\Install"
[string]$appPathInMAF = ""

#endregion

#region ============================ Console Output Helpers ============================

function Write-Info    { Write-Host "[INFO] $args"    -ForegroundColor Cyan }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-Warn    { Write-Host "[WARN] $args"    -ForegroundColor Yellow }
function Write-Fail    { Write-Host "[ERROR] $args"   -ForegroundColor Red }

#endregion

#region ============================ Utility Functions ============================

function Test-CommandExists {
    param ([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
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
        $mfeFolders = @(Get-ChildItem -Path $mfesDir -Directory -Filter "$MfeLabel-*" -ErrorAction SilentlyContinue)
        
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
        $serviceFolders = @(Get-ChildItem -Path $servicesDir -Directory -Filter "$ServiceLabel-*" -ErrorAction SilentlyContinue)
        
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

    $label           = $Mfe.label
    $mfePath         = Join-Path (Join-Path $BaseDir "mfes") $label
    
    # check $mfePath exists
    if (-not (Test-Path $mfePath)) {
        Write-Warn "Skipping MFE '$label': Path not found ($mfePath)"
        return $false
    }

    Write-Info "Building MFE: $label"
    Write-Host "  Path: $mfePath" -ForegroundColor Gray

    Push-Location $mfePath
    try {
        # Check for package manager
        $packageManager =
            if (Test-Path "pnpm-lock.yaml") { "pnpm" }
            elseif (Test-Path "yarn.lock")  { "yarn" }
            elseif (Test-Path "package-lock.json") { "npm" }
            else { "npm" }

        if (-not (Test-CommandExists $packageManager)) {
            throw "$packageManager is not installed or not in PATH"
        }

        Write-Host "  Using: $packageManager" -ForegroundColor Gray

        # Install dependencies if node_modules doesn't exist
        if (-not (Test-Path "node_modules")) {
            Write-Info "Installing dependencies..."
            & $packageManager install | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Dependency installation failed with exit code $LASTEXITCODE"
            }
        }

        # Build
        Write-Info "Running build..."
        Write-Host "  Command: $packageManager run build" -ForegroundColor Gray

        # Capture output to parse for specific failures
        $output = & $packageManager run build
        $buildExitCode = $LASTEXITCODE

        # $output | ForEach-Object { Write-Host $_ } # Uncomment to see full output
        # Write-Host "  Build Exit Code: $buildExitCode" -ForegroundColor Gray

        if ($buildExitCode -ne 0) {
            # Parse output to find which build failed
            $outputStr = $output -join "`n"

            if ($outputStr -match 'npm run build:webpack exited with code (\d+)') {
                if ($matches[1] -ne '0') {
                    Write-Fail "Webpack build failed (exit code $($matches[1]))"
                }
            }

            if ($outputStr -match 'npm run build:types exited with code (\d+)') {
                if ($matches[1] -ne '0') {
                    Write-Fail "TypeScript build failed (exit code $($matches[1]))"
                }
            }

            throw "Build failed (exit code $buildExitCode)"
        }

        Write-Success "MFE '$label' built successfully"
        
        # Copy build files to MAF if path is provided
        $copySuccess = $false
        if ($MafPath -and $Version) {
            $copySuccess = Copy-MfeBuildFiles -MfeLabel $label -SourcePath $mfePath -TargetBasePath $MafPath -Version $Version
        }
        
        return @{
            BuildSuccess = $true
            CopySuccess = $copySuccess
        }
    }
    catch {
        Write-Fail "Failed to build MFE '$label': $_"
        return @{
            BuildSuccess = $false
            CopySuccess = $false
        }
    }
    finally {
        Pop-Location
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

    $label       = $Service.microserviceLabel
    $servicesDir = Join-Path $BaseDir "services"

    # Find label.csproj file at any level under services directory
    $csprojFiles = @(Get-ChildItem -Path $servicesDir -Filter "$label.csproj" -Recurse -ErrorAction SilentlyContinue)

    if ($csprojFiles.Count -eq 0) {
        Write-Warn "Skipping service '$label': $label.csproj file not found under $servicesDir"
        return @{
            BuildSuccess = $false
            CopySuccess = $false
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
            CopySuccess = $copySuccess
        }
    }
    catch {
        Write-Fail "Failed to build service '$label': $_"
        return @{
            BuildSuccess = $false
            CopySuccess = $false
        }
    }
}

#endregion

#region ============================ Main Execution ============================

try {
    Write-Host "`n=== Script Execution Started ===" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta

    # Set default paths if not provided
    # PSScriptRoot is in 'scripts' folder, so go up one level (..) to project root, then into 'src'
    if (-not $ManifestPath) {
        $projectRoot  = Split-Path $PSScriptRoot -Parent
        $ManifestPath = Join-Path (Join-Path $projectRoot "src") "app.manifest.json"
    }

    if (-not $WorkingDir) {
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $WorkingDir  = Join-Path $projectRoot "src"
    }

    # Validate paths
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }

    if (-not (Test-Path $WorkingDir)) {
        throw "Working directory not found: $WorkingDir"
    }

    # Resolve to absolute paths
    $ManifestPath = (Resolve-Path $ManifestPath).Path
    $WorkingDir   = (Resolve-Path $WorkingDir).Path

    Write-Info "Manifest: $ManifestPath"
    Write-Info "Working Directory: $WorkingDir"

    # Read and parse manifest
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    Write-Info "App: $($manifest.appLabel) v$($manifest.version)"

    #replace binaries validation and path retrieval
    if($ReplaceBinaries) {
        Write-Info "Replace Binaries flag is set. Built binaries will be copied to MAF installation directory after build."
        
        # Get MAF installation path from registry
        if (-not (Test-Path $registryKey)) {
            throw "Registry not found: $registryKey"
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
        MfesTotal       = 0
        MfesSuccess     = 0
        MfesFailed      = 0
        ServicesTotal   = 0
        ServicesSuccess = 0
        ServicesFailed  = 0
        MfesReplaced    = 0
        ServicesReplaced = 0
    }

    # Build MFEs
    if ($BuildTarget -in @('All', 'MfesOnly') -and $manifest.mfes) {
        Write-Host "`n=== Building MFEs ===" -ForegroundColor Blue
        Write-Host "`=== Total MFEs found in app manifest : ($($manifest.mfes.Count)) ===" -ForegroundColor Blue
        Write-Host "============================================" -ForegroundColor Blue

        foreach ($mfe in $manifest.mfes) {
            $results.MfesTotal++
            $result = Build-MFE -Mfe $mfe -BaseDir $WorkingDir -MafPath $(if ($ReplaceBinaries) { $appPathInMAF } else { "" }) -Version $manifest.version
            if ($result.BuildSuccess) {
                $results.MfesSuccess++
                if ($result.CopySuccess) {
                    $results.MfesReplaced++
                }
            }
            else {
                $results.MfesFailed++
            }
            Write-Host ""
        }
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