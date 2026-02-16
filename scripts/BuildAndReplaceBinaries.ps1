<#
.SYNOPSIS
    Builds Micro Frontends (MFEs) and .NET services from app.manifest.json configuration.

.DESCRIPTION
    This script automates the building of Micro Frontends (MFEs) and .NET services based on 
    the configuration defined in app.manifest.json. It supports building all components, only 
    MFEs, or only services.

    When the -ReplaceBinaries flag is used, built binaries are automatically copied to the MAF 
    (Micro Application Framework) installation directory after successful builds.

    DEFAULT BEHAVIOR:
    - Looks for app.manifest.json in ../src/
    - Uses ../src/ as the working directory
    - Builds all MFEs and services
    - Does not replace binaries unless -ReplaceBinaries is specified

    BUILD PROCESS:
    
    MFE Build Process:
    1. Detects package manager from lock files (pnpm/yarn/npm)
    2. Installs dependencies if node_modules is missing
    3. Runs build command
    4. Copies dist/ folder to MAF (if -ReplaceBinaries)
    
    Service Build Process:
    1. Locates .csproj file recursively
    2. Builds with dotnet CLI (Release configuration)
    3. Copies bin/Release/<framework>/ to MAF (if -ReplaceBinaries)

    REQUIREMENTS:
    - PowerShell 7.0 or higher
    - Node.js (for MFE builds)
    - .NET SDK (for service builds)
    - Package Manager: npm, pnpm, or yarn (auto-detected)
    - MAF installation (required only when using -ReplaceBinaries)

.PARAMETER ManifestPath
    Specifies the path to the app.manifest.json file.
    
    Default: ../src/app.manifest.json
    
    The manifest file contains the configuration for all MFEs and services to be built.

.PARAMETER WorkingDir
    Specifies the base directory containing mfes/ and services/ folders.
    
    Default: ../src
    
    This should be the root directory where your mfes/ and services/ subdirectories are located.

.PARAMETER BuildTarget
    Specifies which components to build.
    
    Valid Values: 
    - All (default)    - Build both MFEs and services
    - MfesOnly         - Build only Micro Frontends
    - ServicesOnly     - Build only .NET services
    
    Default: All

.PARAMETER ReplaceBinaries
    When specified, copies built binaries to the MAF installation directory after successful builds.
    
    This switch parameter requires:
    - MAF must be installed and registered in Windows Registry
    - Registry key is checked for MAF installation path
    - App must be installed in MAF (matching version from manifest)
    
    WARNING: This is a destructive operation. Existing binaries will be replaced without backup.

.PARAMETER Help
    Displays detailed, formatted help information and exits.
    
    This shows a more comprehensive help page with additional sections like troubleshooting,
    related links, and detailed examples.
    
    Alternative: Use Get-Help .\BuildAndReplaceBinaries.ps1 -Full for PowerShell native help.

.EXAMPLE
    .\BuildAndReplaceBinaries.ps1
    
    Builds all MFEs and services using default paths (../src/app.manifest.json and ../src/).

.EXAMPLE
    .\BuildAndReplaceBinaries.ps1 -BuildTarget MfesOnly
    
    Builds only the Micro Frontends, skipping all .NET services.

.EXAMPLE
    .\BuildAndReplaceBinaries.ps1 -BuildTarget ServicesOnly
    
    Builds only the .NET services, skipping all MFEs.

.EXAMPLE
    .\BuildAndReplaceBinaries.ps1 -ReplaceBinaries
    
    Builds all components and automatically copies the built binaries to the MAF installation directory.
    Requires MAF to be installed and the app to be registered in MAF.

.EXAMPLE
    .\BuildAndReplaceBinaries.ps1 -ManifestPath ".\config\custom.json"
    
    Uses a custom manifest file location instead of the default ../src/app.manifest.json.

.EXAMPLE
    .\BuildAndReplaceBinaries.ps1 -ManifestPath ".\config\app.json" -WorkingDir "C:\Projects\MyApp\src" -ReplaceBinaries
    
    Uses custom paths for both manifest and working directory, and replaces binaries in MAF installation.

.EXAMPLE
    .\BuildAndReplaceBinaries.ps1 -Help
    
    Displays detailed, formatted help information with troubleshooting guide.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    Exit Codes:
    0 - Success (all builds completed successfully)
    1 - Failure (one or more builds failed)
    
    Console Output:
    - Build progress for each MFE and service
    - Success/failure status for each component
    - Summary statistics at completion
    - Binary replacement status (if -ReplaceBinaries used)

.NOTES
    File Name      : BuildAndReplaceBinaries.ps1
    Author         : Build Automation Team
    Prerequisite   : PowerShell 7.0+, Node.js, .NET SDK
    Copyright      : (c) 2026. All rights reserved.
    Version        : 1.0.0
    
    Exit Codes:
    0 = Success (all builds completed successfully)
    1 = Failure (one or more builds failed)
    
    Package Manager Detection:
    The script automatically detects the package manager based on lock files:
    - pnpm-lock.yaml → uses pnpm
    - yarn.lock      → uses yarn
    - package-lock.json → uses npm
    - None found     → defaults to npm
    
    Binary Replacement:
    - Only occurs when -ReplaceBinaries flag is used
    - Requires MAF to be installed
    - Verifies installation via Windows Registry
    - Matches version from app.manifest.json
    - No backup is created (destructive operation)
    
    Troubleshooting:
    For common issues and solutions, run: .\BuildAndReplaceBinaries.ps1 -Help

.LINK
    https://docs.microsoft.com/powershell

.LINK
    https://nodejs.org

.LINK
    https://dotnet.microsoft.com
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

#endregion

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
  -ManifestPath <path>       Path to app.manifest.json file
                             (default: ../src/app.manifest.json)
  
  -WorkingDir <path>         Base directory containing mfes/ and services/ folders
                             (default: ../src)
  
  -BuildTarget <target>      Specify which components to build
                             Values: All (default), MfesOnly, ServicesOnly
  
  -ReplaceBinaries           Copy built binaries to MAF installation after build
                             (requires MAF to be installed)
  
  -Help, -h                  Display this help and exit

Examples:
  .\$scriptName
      Build all MFEs and services with default settings
  
  .\$scriptName -BuildTarget MfesOnly
      Build only Micro Frontends, skip .NET services
  
  .\$scriptName -BuildTarget ServicesOnly
      Build only .NET services, skip MFEs
  
  .\$scriptName -ReplaceBinaries
      Build all components and copy binaries to MAF installation
  
  .\$scriptName -ManifestPath ".\custom.json" -ReplaceBinaries
      Use custom manifest and replace MAF binaries

Environment:
  NODE_PATH                  Additional module search paths for Node.js builds
  DOTNET_CLI_HOME           .NET CLI home directory
  PSModulePath              PowerShell module search paths

Build Process:
  MFE Build:
    1. Auto-detect package manager (pnpm/yarn/npm from lock files)
    2. Install dependencies if node_modules missing
    3. Run build command
    4. Copy dist/ to MAF if -ReplaceBinaries specified
  
  Service Build:
    1. Locate .csproj file recursively
    2. Build with dotnet CLI (Release configuration)
    3. Copy bin/Release/<framework>/ to MAF if -ReplaceBinaries specified

Requirements:
  - PowerShell 7.0 or higher
  - Node.js (for MFE builds)
  - .NET SDK (for service builds)
  - npm, pnpm, or yarn (auto-detected)
  - MAF installation (required only with -ReplaceBinaries)

Exit Codes:
  0                          All builds completed successfully
  1                          One or more builds failed

Documentation: https://docs.microsoft.com/powershell
Report issues to: Build Automation Team

Version: 1.0.0
Script: $PSCommandPath
"@
    
    Write-Host $helpText
}

#endregion

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
        else { "npm" }

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

#region ============================ Main Execution ============================

# Display help if requested
if ($Help) {
    Show-CliHelp
    exit 0
}

try {
    Write-Host "`n=== Script Execution Started ===" -ForegroundColor Magenta
    Write-Host "============================================" -ForegroundColor Magenta

    # Set default paths if not provided
    # PSScriptRoot is in 'scripts' folder, so go up one level (..) to project root, then into 'src'
    if (-not $ManifestPath) {
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $ManifestPath = Join-Path (Join-Path $projectRoot "src") "app.manifest.json"
    }

    if (-not $WorkingDir) {
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $WorkingDir = Join-Path $projectRoot "src"
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