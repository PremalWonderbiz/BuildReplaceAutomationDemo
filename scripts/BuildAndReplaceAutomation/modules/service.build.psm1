Import-Module "$PSScriptRoot\build.helpers.psm1" -Force

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

Export-ModuleMember -Function Build-Service
