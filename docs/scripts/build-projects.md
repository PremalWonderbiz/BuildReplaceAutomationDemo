# Build Projects Script (`build-projects.ps1`)

A cross-platform PowerShell (`pwsh`) build orchestrator for **Micro Frontends (MFEs)** and **.NET services**, driven by `app.manifest.json`.

Designed for local development and CI usage with clear logging and predictable behavior.

---

## What This Script Does

- Reads `app.manifest.json`
- Builds **MFEs** (Node-based) and **Services** (.NET)
- Automatically detects:
  - Package manager (`pnpm | yarn | npm`)
  - `.csproj` files for services
- Produes a clear success/failure summary
- Works on **Windows, macOS, and Linux**

---

## Requirements

### Runtime

- **PowerShell Core (`pwsh`)**
- **Node.js** (for MFEs)
- **.NET SDK** (for services)

### Tools

- One of: `npm`, `yarn`, or `pnpm`
- `dotnet` CLI available in `PATH`

---

## Project Structure Assumption

```

project-root/
├── scripts/
│ └── build-projects.ps1
└── src/
├── app.manifest.json
├── mfes/
│ └── <mfe-label>/
│ └── package.json
└── services/
└── <service-label>/
└── \*.csproj

```

---

## Usage

### Default (build everything)

```powershell
./build-projects.ps1
```

### Custom manifest path

```powershell
./build-projects.ps1 -ManifestPath "./custom-manifest.json"
```

### Skip MFEs

```powershell
./build-projects.ps1 -SkipMfes
```

### Skip Services

```powershell
./build-projects.ps1 -SkipServices
```

---

## Parameters

| Parameter      | Description                                       |
| -------------- | ------------------------------------------------- |
| `ManifestPath` | Path to `app.manifest.json`                       |
| `WorkingDir`   | Base directory containing `mfes/` and `services/` |
| `SkipMfes`     | Skips building MFEs                               |
| `SkipServices` | Skips building services                           |

Defaults are resolved automatically based on script location.

---

## Build Behavior

### MFEs

- Detects package manager via lock files
- Installs dependencies if `node_modules` is missing
- Runs `npm|yarn|pnpm run build`
- Uses **exit code** as the source of truth
- Logs warnings (e.g. Node deprecations) without failing the build

### Services

- Locates `.csproj` files
- Runs `dotnet build -c Release`
- Optional framework support via manifest

---

## Error Handling Philosophy

- **Warnings ≠ Failures**
- Only **non-zero exit codes** fail a build
- Script uses `Set-StrictMode -Version Latest` for correctness
- Failures are isolated per project; summary reflects final status

---

## Output

- Color-coded logs for readability
- Clear section separation
- Final summary:
  - MFEs built vs total
  - Services built vs total

- Exit codes:
  - `0` → all builds successful
  - `1` → one or more failures

---

## Cross-Platform Notes

- No OS-specific shell commands
- Uses native PowerShell execution (`&`)
- Safe for:
  - Windows
  - macOS
  - Linux
  - CI runners

---

## Summary

This script provides a **reliable, predictable, and extensible** way to build a mixed MFE + .NET codebase using a single manifest-driven workflow.

---
