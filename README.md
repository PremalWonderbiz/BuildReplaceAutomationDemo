# BuildReplace Automation

PowerShell automation for building **Micro Frontends (MFEs)** and **.NET Services** defined in `app.manifest.json`, with optional binary replacement into a local MAF installation.

---

## Prerequisites

| Tool | Purpose |
|---|---|
| PowerShell Core (`pwsh`) | Running all scripts |
| Node.js | Building MFEs |
| `pnpm` / `yarn` / `npm` | MFE package management (auto-detected per project) |
| .NET SDK | Building Services |
| MAF installed locally | Replace Binaries mode only |

---

## Quick Start

```powershell
cd scripts
.\dev.ps1
```

This opens an interactive menu. Use arrow keys to select a mode and press Enter.

---

## The 6 Build Modes

| Mode | What It Does |
|---|---|
| **Build All Projects** | Builds all MFEs and Services |
| **Build MFEs Only** | Builds MFEs only |
| **Build Services Only** | Builds Services only |
| **Build Replace All Projects** | Builds all MFEs and Services, then copies output into MAF |
| **Build Replace MFEs Only** | Builds MFEs only, then copies output into MAF |
| **Build Replace Services Only** | Builds Services only, then copies output into MAF |

> **Build Replace** modes require MAF to be installed locally and accessible via the Windows Registry. See [MAF Setup](#maf-setup).

---

## Project Structure

```
project-root/
├── scripts/
│   ├── dev.ps1                    ← Run this
│   ├── BuildReplaceAll.ps1
│   ├── BuildReplaceMfes.ps1
│   ├── BuildReplaceServices.ps1
│   ├── Utils.ps1
│   └── BuildReplace.config.json
├── src/
│   ├── app.manifest.json          ← Defines which MFEs and Services to build
│   ├── mfes/
│   └── services/
└── docs/
```

---

## Configuration

### `app.manifest.json`

Defines the app and all MFEs and Services to build. Located at `src/app.manifest.json`.

```json
{
  "appLabel": "my-app",
  "version": "1.0.0",
  "mfes": [
    { "label": "mfe-1", "name": "mfe-1", "version": "1.0.0" }
  ],
  "services": [
    { "microserviceLabel": "my-service", "framework": "net8.0" }
  ]
}
```

### `BuildReplace.config.json`

Script configuration. Located at `scripts/BuildReplace.config.json`.

```json
{
  "registryKey": "HKLM:\\SOFTWARE\\WOW6432Node\\WonderBiz Technologies\\WonderBiz Platform\\01.00\\Install",
  "defaultPackageManager": "npm"
}
```

| Field | Description |
|---|---|
| `registryKey` | Windows Registry path to the MAF installation (used by Replace Binaries mode) |
| `defaultPackageManager` | Fallback package manager if no lock file is detected (`npm`, `pnpm`, or `yarn`) |

---

## MAF Setup

For **Build Replace** modes to work, MAF must be installed and the folder structure inside the installation must match the expected layout.

---

## VS Code Tasks

All 6 modes are available as VS Code tasks via `Ctrl + Shift + P` → `Tasks: Run Task`.  
`Ctrl + Shift + B` runs **Build All Projects** by default.

See [`docs/code-workspace/code_workspace_task.md`](docs/code-workspace/code_workspace_task.md) for full task configuration details.

---

## Documentation

| Doc | Description |
|---|---|
| [`docs/scripts/scripts.md`](docs/scripts/scripts.md) | Full reference for all scripts — parameters, behavior, execution flow |
| [`docs/scripts/hardcoded.md`](docs/scripts/hardcoded.md) | All hardcoded values in the scripts and their priority for being made configurable |
| [`docs/code-workspace/code_workspace_task.md`](docs/code-workspace/code_workspace_task.md) | VS Code task configuration explained |
| [`support docs/registry setup flow.txt`](support%20docs/registry%20setup%20flow.txt) | MAF registry and folder setup steps |
