Import-Module "$PSScriptRoot\build.helpers.psm1" -Force

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

Export-ModuleMember -Function Build-MFE
