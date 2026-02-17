## 📋 Complete List of Hardcoded Items

### 1. **Registry Keys** (Lines 32-33)

```powershell
Line 32: [string]$registryKey = "HKLM:\SOFTWARE\WOW6432Node\WonderBiz Technologies\WonderBiz Platform\01.00\Install"
Line 33: # [string]$registryKey = "HKLM:\SOFTWARE\WOW6432Node\Schneider Electric\EcoStruxure Automation Expert Platform\01.00\Install"
```

**Issue**: Company-specific registry paths hardcoded

---

### 2. **Folder Names** (Multiple locations)

```powershell
Line 106: $mfesDir = Join-Path $TargetBasePath "mfes"
Line 162: $servicesDir = Join-Path $TargetBasePath "services"
Line 248: $mfePath = Join-Path (Join-Path $BaseDir "mfes") $label
Line 327: $servicesDir = Join-Path $BaseDir "services"
```

**Issue**: Folder structure ("mfes", "services") is hardcoded

---

### 3. **File/Folder Patterns** (Multiple locations)

```powershell
Line 109: $mfeFolders = @(Get-ChildItem -Path $mfesDir -Directory -Filter "$MfeLabel-*" -ErrorAction SilentlyContinue)
Line 120: $versionFolders = @(Get-ChildItem -Path $mfeFolder -Directory -Filter "$Version*" -ErrorAction SilentlyContinue)
Line 130: $distPath = Join-Path $SourcePath "dist"
Line 165: $serviceFolders = @(Get-ChildItem -Path $servicesDir -Directory -Filter "$ServiceLabel*" -ErrorAction SilentlyContinue)
Line 175: $binPath = Join-Path $SourcePath "bin" | Join-Path -ChildPath "Release" | Join-Path -ChildPath $Framework
```

**Issue**: Build output folder names and patterns hardcoded

---

### 4. **Lock File Names** (Lines 264-267)

```powershell
Line 264: if (Test-Path "pnpm-lock.yaml") { "pnpm" }
Line 265: elseif (Test-Path "yarn.lock") { "yarn" }
Line 266: elseif (Test-Path "package-lock.json") { "npm" }
Line 267: else { "npm" }
```

**Issue**: Package manager detection based on specific filenames

---

### 5. **Node Modules Folder** (Line 274)

```powershell
Line 274: if (-not (Test-Path "node_modules")) {
```

**Issue**: Node.js dependency folder name hardcoded

---

### 6. **Build Commands** (Lines 283-287)

```powershell
Line 283: $output = switch ($packageManager) {
Line 284:     "npm" { npm run build }
Line 285:     "pnpm" { pnpm run build }
Line 286:     "yarn" { yarn run build }
```

**Issue**: "build" script name is hardcoded

---

### 7. **Build Configuration** (Line 350)

```powershell
Line 350: $buildArgs = @("build", $csprojPath, "-c", "Release")
```

**Issue**: .NET build configuration "Release" is hardcoded

---

### 8. **File Extensions** (Line 330)

```powersharp
Line 330: $csprojFiles = @(Get-ChildItem -Path $servicesDir -Filter "$label.csproj" -Recurse -ErrorAction SilentlyContinue)
```

**Issue**: ".csproj" file extension hardcoded

---

### 9. **Default Paths** (Lines 380-389)

```powershell
Line 383: $ManifestPath = Join-Path (Join-Path $projectRoot "src") "app.manifest.json"
Line 388: $WorkingDir = Join-Path $projectRoot "src"
```

**Issue**:

- "src" folder name hardcoded
- "app.manifest.json" filename hardcoded

---

### 10. **MAF Path Structure** (Lines 415-417)

```powershell
Line 415: $distRoot = Join-Path (Join-Path $mafInstallPath "MAF") "dist"
Line 417: $pattern = "$($manifest.appLabel)-$($manifest.version)-*"
```

**Issue**:

- "MAF" and "dist" folder names hardcoded
- App folder naming pattern hardcoded

---

### 11. **Build Target Values** (Line 21)

```powershell
Line 21: [ValidateSet('All', 'MfesOnly', 'ServicesOnly')]
```

**Issue**: Build target options hardcoded in parameter validation

---

### 12. **Console Colors** (Lines 37-40)

```powershell
Line 37: function Write-Info { Write-Host "[INFO] $args"    -ForegroundColor Cyan }
Line 38: function Write-Success { Write-Host "[SUCCESS] $args" -ForegroundColor Green }
Line 39: function Write-Warn { Write-Host "[WARN] $args"    -ForegroundColor Yellow }
Line 40: function Write-Fail { Write-Host "[ERROR] $args"   -ForegroundColor Red }
```

**Issue**: Console output colors hardcoded

---

### 13. **Log Prefixes** (Lines 37-40)

```powershell
Line 37: "[INFO]"
Line 38: "[SUCCESS]"
Line 39: "[WARN]"
Line 40: "[ERROR]"
```

**Issue**: Log message prefixes hardcoded

---

### 14. **Error Messages** (Multiple locations)

```powershell
Line 111: Write-Warn "MFE '$MfeLabel' not installed in MAF. Skipping replace binaries for this MFE."
Line 122: Write-Warn "Version folder not found for '$MfeLabel' in MAF. Skipping replace binaries for this MFE."
Line 134: Write-Warn "Build output folder not found: $distPath"
Line 143: Write-Warn "Target mfe folder not found in MAF: $targetPath. Skipping replace binaries for this service."
Line 167: Write-Warn "Service '$ServiceLabel' not installed in MAF. Skipping replace binaries for this service."
Line 177: Write-Warn "Build output folder not found: $binPath"
Line 186: Write-Warn "Target service folder not found in MAF: $targetPath. Skipping replace binaries for this service."
Line 252: Write-Warn "Skipping MFE '$label': Path not found ($mfePath)"
Line 272: throw "$packageManager is not installed or not in PATH"
Line 334: Write-Warn "Skipping service '$label': $label.csproj file not found under $servicesDir"
Line 348: throw "dotnet CLI is not installed or not in PATH"
Line 398: throw "Manifest file not found: $ManifestPath"
Line 402: throw "Working directory not found: $WorkingDir"
Line 412: throw "Registry not found: $registryKey"
Line 419: throw "MAF installation path error: Please check if WonderBiz Platform is installed correctly."
Line 426: throw "App is not installed in MAF: $($manifest.appLabel) v$($manifest.version)"
```

**Issue**: All error/warning messages are hardcoded strings

---

### 15. **Build Error Parsing Patterns** (Lines 300-301)

```powershell
Line 300: if ($outputStr -match 'npm run build:webpack exited with code (\d+)') {
Line 305: if ($outputStr -match 'npm run build:types exited with code (\d+)') {
```

**Issue**: npm build script names ("build:webpack", "build:types") hardcoded in regex

---

### 16. **Exit Codes** (Lines 484, 489, 495)

```powershell
Line 484: exit 0
Line 489: exit 1
Line 495: exit 1
```

**Issue**: Exit codes hardcoded (though this is standard practice)

---

## 📊 Summary Table

| Category            | Count | Lines                   |
| ------------------- | ----- | ----------------------- |
| **Registry Keys**   | 2     | 32-33                   |
| **Folder Names**    | 6     | 106, 162, 248, 327, 415 |
| **File Patterns**   | 5     | 109, 120, 130, 165, 175 |
| **Lock Files**      | 3     | 264-267                 |
| **Build Commands**  | 4     | 283-287, 350            |
| **File Extensions** | 1     | 330                     |
| **Default Paths**   | 2     | 383, 388                |
| **Error Messages**  | 16    | Multiple                |
| **Console Colors**  | 4     | 37-40                   |
| **Build Targets**   | 3     | 21                      |
| **Exit Codes**      | 3     | 484, 489, 495           |

## 💡 Recommendations

### High Priority (Should Be Configurable)

1. **Registry keys** - Use config file or environment variables
2. **Folder structure** (mfes, services, dist, bin) - Config file
3. **Build configuration** (Release) - Parameter
4. **Default paths** (src, app.manifest.json) - Config file

### Medium Priority (Consider Making Configurable)

5. **Build commands** (npm run build) - Config file for custom scripts
6. **File patterns** - Config file for custom naming conventions
7. **Package manager detection** - Allow override via parameter

### Low Priority (Generally OK as Hardcoded)

8. **Error messages** - Can stay hardcoded
9. **Console colors** - Can stay hardcoded
10. **Exit codes** - Standard practice to hardcode
