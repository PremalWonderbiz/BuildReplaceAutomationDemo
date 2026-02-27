# Hardcoded Items in Build Scripts

A reference of all values currently hardcoded across `BuildReplaceAll.ps1`, `BuildReplaceMfes.ps1`, `BuildReplaceServices.ps1`, and `Utils.ps1` — along with their priority for being made configurable.

---

## Hardcoded Items

### 1. Registry Key

```powershell
"HKLM:\SOFTWARE\WOW6432Node\WonderBiz Technologies\WonderBiz Platform\01.00\Install"
```

Location: `Utils.ps1` → `Resolve-MafAppPath`

**Issue:** Company-specific registry path hardcoded. Different environments (e.g. Schneider Electric) require a different key.

---

### 2. MAF Folder Structure

```powershell
$distRoot = Join-Path (Join-Path $mafInstallPath "MAF") "dist"
$pattern  = "$AppLabel-$Version-*"
```

Location: `Utils.ps1` → `Resolve-MafAppPath`

**Issue:** The `MAF` and `dist` subfolder names and the app folder naming pattern are hardcoded. Any change to the MAF installation structure would break path resolution.

---

### 3. Source Folder Names

```powershell
Join-Path $projectRoot "src"          # working directory
Join-Path $workingDir "mfes"          # MFE root
Join-Path $workingDir "services"      # Services root
```

Location: `Utils.ps1` → `Initialize-BuildEnvironment`, `BuildReplaceMfes.ps1`, `BuildReplaceServices.ps1`

**Issue:** The `src`, `mfes`, and `services` folder names are hardcoded. Projects with a different directory layout cannot use these scripts without code changes.

---

### 4. Manifest Filename

```powershell
"app.manifest.json"
```

Location: `Utils.ps1` → `Initialize-BuildEnvironment`

**Issue:** The manifest filename is hardcoded. It cannot be changed without editing the script.

---

### 5. MFE Build Output Folder

```powershell
$distPath = Join-Path $SourcePath "dist"
```

Location: `BuildReplaceMfes.ps1` → `Copy-MfeBuildFiles`

**Issue:** MFE build output is assumed to always be in a `dist` subfolder. Projects with a different output directory would fail.

---

### 6. MAF MFE Target Pattern

```powershell
Get-ChildItem -Filter "$MfeLabel*"     # MFE folder match
Get-ChildItem -Filter "$Version*"      # version subfolder match
```

Location: `BuildReplaceMfes.ps1` → `Copy-MfeBuildFiles`

**Issue:** The folder matching pattern inside the MAF mfes directory is hardcoded. A change in MAF's folder naming convention would break binary replacement for MFEs.

---

### 7. Service Build Configuration

```powershell
$buildArgs = @("build", $csprojPath, "-c", "Release")
```

Location: `BuildReplaceServices.ps1` → `Build-Service`

**Issue:** The .NET build configuration is hardcoded to `Release`. There is no way to build in `Debug` without editing the script.

---

### 8. Service Build Output Path

```powershell
Join-Path $SourcePath "bin" | Join-Path -ChildPath "Release" | Join-Path -ChildPath $Framework
```

Location: `BuildReplaceServices.ps1` → `Copy-ServiceBuildFiles`

**Issue:** The `bin\Release\<framework>` output path is hardcoded to match the `Release` configuration. Tied to item 7 above.

---

### 9. Service Project File Extension

```powershell
Get-ChildItem -Filter "$label.csproj"
```

Location: `BuildReplaceServices.ps1` → `Build-Service`

**Issue:** Only `.csproj` project files are supported. Other project types (e.g. `.fsproj`) are not detected.

---

### 10. MAF Service Target Pattern

```powershell
Get-ChildItem -Filter "$ServiceLabel*"
```

Location: `BuildReplaceServices.ps1` → `Copy-ServiceBuildFiles`

**Issue:** The service folder matching pattern inside the MAF services directory is hardcoded.

---

### 11. Package Manager Lock Files

```powershell
if (Test-Path "pnpm-lock.yaml") { "pnpm" }
elseif (Test-Path "yarn.lock")  { "yarn" }
elseif (Test-Path "package-lock.json") { "npm" }
else { $defaultPackageManager }
```

Location: `BuildReplaceMfes.ps1` → `Build-MFE`

**Issue:** Detection is based on specific lock filenames. A project using Bun or another package manager would not be detected and would fall back to the config default.

---

### 12. Node Modules Folder Name

```powershell
if (-not (Test-Path "node_modules")) { ... }
```

Location: `BuildReplaceMfes.ps1` → `Build-MFE`

**Issue:** Dependency presence check assumes the standard `node_modules` folder name.

---

### 13. MFE Build Script Name

```powershell
<packageManager> run build
```

Location: `BuildReplaceMfes.ps1` → `Build-MFE`

**Issue:** The npm script name `build` is hardcoded. MFE projects using a different script name (e.g. `build:prod`) would not build correctly.

---

### 14. MFE Output Parsing Patterns

```powershell
if ($outputStr -match 'npm run build:webpack exited with code (\d+)')
if ($outputStr -match 'npm run build:types exited with code (\d+)')
```

Location: `BuildReplaceMfes.ps1` → `Build-MFE`

**Issue:** The regex patterns for detecting sub-process failures are hardcoded to specific npm script names (`build:webpack`, `build:types`). These would not match if MFE projects use different build step names.

---

### 15. Console Colors and Log Prefixes

```powershell
function Write-Info    { Write-Host "[INFO] $args"    -ForegroundColor Cyan }
function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
function Write-Warn    { Write-Host "[WARN] $args"    -ForegroundColor Yellow }
function Write-Fail    { Write-Host "[ERROR] $args"   -ForegroundColor Red }
```

Location: `Utils.ps1`

**Issue:** Colors and log prefixes are hardcoded. Low priority — these are generally acceptable as fixed values.

---

### 16. Exit Codes

```powershell
exit 0   # success
exit 1   # failure
```

Location: All build scripts

**Issue:** Standard practice — acceptable as hardcoded.

---

## Priority Summary

| Priority                                  | Items                                                                                                                                        |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **High** — should be configurable         | Registry key, MAF folder structure, source folder names (`src`, `mfes`, `services`), manifest filename, .NET build configuration             |
| **Medium** — consider making configurable | MFE build script name, output folder names (`dist`, `bin/Release`), MAF target folder patterns, lock file detection, output parsing patterns |
| **Low** — acceptable as hardcoded         | Console colors, log prefixes, exit codes, `.csproj` extension, `node_modules` folder name                                                    |
