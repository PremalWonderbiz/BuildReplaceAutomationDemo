#!/usr/bin/env pwsh

# dev.ps1
# Interactive entry point for build & replace automation.
#
# Usage (interactive): .\dev.ps1
# Usage (direct):      .\dev.ps1 -Mode 4
# Usage (help):        .\dev.ps1 -Help

#region ============================ Parameters ============================

param (
    [ValidateRange(1, 6)]
    [int]$Mode = 0,

    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version 1
$ErrorActionPreference = "Stop"

#endregion

#region ============================ Help ============================

function Show-CliHelp {
    $scriptName = Split-Path -Leaf $PSCommandPath
    Write-Host @"

$scriptName - Interactive entry point for build & replace automation

Usage: .\$scriptName [options]

Presents an interactive menu to select a build mode and dispatches
to the appropriate script (BuildReplaceAll, BuildReplaceMfes, BuildReplaceServices).

Options:
  -Mode <1-6>    Skip the menu and run a specific mode directly
                   1 - Build All Projects
                   2 - Build MFEs Only
                   3 - Build Services Only
                   4 - Build Replace All Projects
                   5 - Build Replace MFEs Only
                   6 - Build Replace Services Only

  -Help, -h      Show this help message

"@
}

#endregion

#region ============================ Menu ============================

$menuOptions = @(
    "Build All Projects",
    "Build MFEs Only",
    "Build Services Only",
    "Build Replace All Projects",
    "Build Replace MFEs Only",
    "Build Replace Services Only"
)

function Show-ConsoleMenu {
    param (
        [string]$Title,
        [string[]]$Options,
        [int]$SeparatorBeforeIndex = -1
    )

    $selected = 0

    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Magenta
        Write-Host "    $Title" -ForegroundColor Magenta
        Write-Host "  ============================================" -ForegroundColor Magenta
        Write-Host ""

        for ($i = 0; $i -lt $Options.Length; $i++) {
            if ($i -eq $SeparatorBeforeIndex) {
                Write-Host "  --------------------------------------------" -ForegroundColor DarkGray
            }
            if ($i -eq $selected) {
                Write-Host "  > $($Options[$i])" -ForegroundColor Green
            }
            else {
                Write-Host "    $($Options[$i])" -ForegroundColor Gray
            }
        }

        Write-Host ""
        Write-Host "  [ Up / Down ] Navigate   [ Enter ] Confirm   [ Ctrl+C ] Exit" -ForegroundColor DarkGray
        Write-Host ""

        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { if ($selected -gt 0) { $selected-- } }
            40 { if ($selected -lt ($Options.Length - 1)) { $selected++ } }
            13 { return $selected + 1 }
        }
    }
}

#endregion

#region ============================ Dispatch Map ============================

$dispatch = @{
    1 = @{ Script = "BuildReplaceAll.ps1"; ReplaceBinaries = $false }
    2 = @{ Script = "BuildReplaceMfes.ps1"; ReplaceBinaries = $false }
    3 = @{ Script = "BuildReplaceServices.ps1"; ReplaceBinaries = $false }
    4 = @{ Script = "BuildReplaceAll.ps1"; ReplaceBinaries = $true }
    5 = @{ Script = "BuildReplaceMfes.ps1"; ReplaceBinaries = $true }
    6 = @{ Script = "BuildReplaceServices.ps1"; ReplaceBinaries = $true }
}

#endregion

#region ============================ Main Execution ============================

if ($Help) {
    Show-CliHelp
    exit 0
}

try {
    $selectedMode = if ($Mode -gt 0) {
        $Mode
    }
    else {
        Show-ConsoleMenu `
            -Title "Build & Replace Automation" `
            -Options $menuOptions `
            -SeparatorBeforeIndex 3
    }

    $target = $dispatch[$selectedMode]
    $scriptPath = Join-Path $PSScriptRoot $target.Script

    Clear-Host
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Magenta
    Write-Host "    Build & Replace Automation" -ForegroundColor Magenta
    Write-Host "  ============================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  [INFO] Selected : $($menuOptions[$selectedMode - 1])" -ForegroundColor Cyan
    Write-Host "  [INFO] Script   : $($target.Script)" -ForegroundColor Cyan

    if ($target.ReplaceBinaries) {
        Write-Host "  [INFO] Mode     : Build + Replace Binaries" -ForegroundColor Cyan
        Write-Host ""
        & $scriptPath -ReplaceBinaries
    }
    else {
        Write-Host "  [INFO] Mode     : Build Only" -ForegroundColor Cyan
        Write-Host ""
        & $scriptPath
    }
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion