# Build & Replace Script (`BuildAndReplaceBinaries.ps1`)

A cross-platform PowerShell (`pwsh`) build orchestrator for **Micro Frontends (MFEs)** and **.NET services**, driven by `app.manifest.json`.

Supports optional **binary replacement into MAF installation directory** after successful builds.

Designed for local development, automation, and CI usage with predictable behavior and structured logging.

---

## What This Script Does

- Reads `app.manifest.json`
- Builds:
  - **MFEs** (Node-based projects)
  - **.NET Services**

- Automatically detects:
  - Package manager (`pnpm | yarn | npm`)
  - `.csproj` location for services

- Optionally replaces built binaries inside installed **MAF distribution**
- Produces a clear success/failure summary
- Returns CI-friendly exit codes
- Works on:
  - Windows
  - macOS
  - Linux

---

## Requirements

### Runtime

- **PowerShell Core (`pwsh`)**
- **Node.js** (for MFEs)
- **.NET SDK** (for services)

### Tools

- One of: `pnpm`, `yarn`, or `npm`
- `dotnet` CLI available in `PATH`

---

## Project Structure Assumption

```
project-root/
├── scripts/
│   └── BuildAndReplaceBinaries.ps1
└── src/
    ├── app.manifest.json
    ├── mfes/
    │   └── <mfe-label>/
    │       └── package.json
    └── services/
        └── <service-label>/
            └── *.csproj
```

---

## Usage

### Build Everything (Default)

```powershell
./BuildAndReplaceBinaries.ps1
```

### Build Only MFEs

```powershell
./BuildAndReplaceBinaries.ps1 -BuildTarget MfesOnly
```

### Build Only Services

```powershell
./BuildAndReplaceBinaries.ps1 -BuildTarget ServicesOnly
```

### Custom Manifest Path

```powershell
./BuildAndReplaceBinaries.ps1 -ManifestPath "./custom-manifest.json"
```

### Replace Binaries in Installed MAF

```powershell
./BuildAndReplaceBinaries.ps1 -ReplaceBinaries
```

You can combine parameters:

```powershell
./BuildAndReplaceBinaries.ps1 -BuildTarget ServicesOnly -ReplaceBinaries
```

---

## Parameters

| Parameter         | Description                                       |
| ----------------- | ------------------------------------------------- |
| `ManifestPath`    | Path to `app.manifest.json`                       |
| `WorkingDir`      | Base directory containing `mfes/` and `services/` |
| `BuildTarget`     | `All` (default), `MfesOnly`, or `ServicesOnly`    |
| `ReplaceBinaries` | If set, replaces binaries inside installed MAF    |

Defaults are automatically resolved based on script location.

---

## Build Behavior

### MFEs

- Detects package manager via lock files:
  - `pnpm-lock.yaml`
  - `yarn.lock`
  - `package-lock.json`

- Installs dependencies if `node_modules` is missing
- Runs `npm|yarn|pnpm run build`
- Uses **exit code as source of truth**
- Parses output to detect:
  - Webpack failures
  - TypeScript failures

---

### Services

- Locates `.csproj` by service label
- Runs:

```
dotnet build -c Release [-f framework]
```

- Uses exit code for success/failure detection
- Framework is optionally provided via manifest

---

## Replace Binaries Mode

When `-ReplaceBinaries` is enabled:

1. Script reads MAF installation path from Windows Registry:

   ```
   HKLM:\SOFTWARE\WOW6432Node\WonderBiz Technologies\WonderBiz Platform\01.00\Install
   ```

2. Dynamically detects installed app folder using pattern:

```
<appLabel>-<version>-*
```

3. Cleans target directory before deployment:

```powershell
Remove-Item <target>\* -Recurse -Force
```

4. Copies fresh build output:

```powershell
Copy-Item <buildOutput>\* -Recurse -Force -ErrorAction Stop
```

This ensures:

- No stale binaries
- No leftover files
- Clean deployment behavior

---

## Error Handling Philosophy

- Uses `Set-StrictMode -Version Latest`
- Uses `$ErrorActionPreference = "Stop"`
- Build success determined strictly by exit codes
- Each project failure is isolated
- Final summary determines overall script exit code

Exit codes:

| Code | Meaning               |
| ---- | --------------------- |
| `0`  | All builds successful |
| `1`  | One or more failures  |

---

## Logging

- Structured sections
- Color-coded logs:
  - INFO (Cyan)
  - SUCCESS (Green)
  - WARN (Yellow)
  - ERROR (Red)

- Clear build summary
- Clear replace summary (if enabled)

---

## Cross-Platform Notes

Build mode works on:

- Windows
- macOS
- Linux
- CI runners

⚠️ `-ReplaceBinaries` currently requires:

- Windows
- Installed MAF
- Registry access

---

## Design Principles

- Manifest-driven workflow
- Deterministic builds
- Clear separation of concerns
- Safe deployment replacement
- CI-friendly exit codes
- Consistent return contract from functions

---
