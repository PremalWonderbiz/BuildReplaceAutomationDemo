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

Export-ModuleMember -Function `
    Write-Info,
Write-Success,
Write-Warn,
Write-Fail,
Test-CommandExists,
Copy-MfeBuildFiles,
Copy-ServiceBuildFiles
