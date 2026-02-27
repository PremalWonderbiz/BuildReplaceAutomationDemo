# Build & Replace Scripts

PowerShell automation for building **Micro Frontends (MFEs)** and **.NET Services**, with optional binary replacement into a local MAF installation. Driven entirely by `app.manifest.json`.

---

## Scripts Overview

```
scripts/
├── dev.ps1                    ← Interactive entry point for developers
├── BuildReplaceAll.ps1        ← Builds MFEs + Services (orchestrator)
├── BuildReplaceMfes.ps1       ← Builds MFEs only
├── BuildReplaceServices.ps1   ← Builds Services only
└── Utils.ps1                  ← Shared helpers, dot-sourced by all three above
```

Each `BuildReplace*.ps1` script can be run standalone or called by `dev.ps1`. `Utils.ps1` contains only function definitions — no standalone execution logic.

---

## Requirements

| Tool                                                | Purpose                    |
| --------------------------------------------------- | -------------------------- |
| PowerShell Core (`pwsh`)                            | Running all scripts        |
| Node.js + package manager (`pnpm` / `yarn` / `npm`) | Building MFEs              |
| .NET SDK (`dotnet` CLI)                             | Building Services          |
| Windows Registry access                             | Replace Binaries mode only |
| MAF installed locally                               | Replace Binaries mode only |

---

## Project Structure Expected

```
project-root/
├── scripts/
│   ├── dev.ps1
│   ├── BuildReplaceAll.ps1
│   ├── BuildReplaceMfes.ps1
│   ├── BuildReplaceServices.ps1
│   ├── Utils.ps1
│   └── BuildReplace.config.json
└── src/
    ├── app.manifest.json
    ├── mfes/
    │   └── <mfe-label>/
    │       └── package.json
    └── services/
        └── **/<service-label>.csproj
```

---

## dev.ps1 — Interactive Entry Point

The primary way for developers to run builds. Presents an arrow-key menu covering all 6 modes and dispatches to the right script automatically.

### Usage

```powershell
# Interactive menu
.\dev.ps1

# Skip menu, run a specific mode directly
.\dev.ps1 -Mode 4

# Show help
.\dev.ps1 -Help
.\dev.ps1 -h
```

### Menu Modes

| Mode | Action                      |
| ---- | --------------------------- |
| 1    | Build All Projects          |
| 2    | Build MFEs Only             |
| 3    | Build Services Only         |
| 4    | Build Replace All Projects  |
| 5    | Build Replace MFEs Only     |
| 6    | Build Replace Services Only |

Modes 1–3 build only. Modes 4–6 build then replace binaries into MAF.

### How It Works

- Renders an interactive menu using `ReadKey` — navigate with Up/Down arrows, confirm with Enter
- A visual separator divides Build-only (1–3) from Build Replace (4–6) modes
- After selection, prints a confirmation of what is about to run before any build output
- `-Mode` param bypasses the menu entirely — useful for quick re-runs or scripting

---

## BuildReplaceAll.ps1 — Orchestrator

Builds both MFEs and Services in sequence. Dot-sources `BuildReplaceMfes.ps1` and `BuildReplaceServices.ps1` to reuse their build functions.

### Usage

```powershell
# Build everything
.\BuildReplaceAll.ps1

# Build everything and replace binaries in MAF
.\BuildReplaceAll.ps1 -ReplaceBinaries

# Show help
.\BuildReplaceAll.ps1 -Help
```

### Parameters

| Parameter          | Description                                                   |
| ------------------ | ------------------------------------------------------------- |
| `-ReplaceBinaries` | After building, copies output into the local MAF installation |
| `-Help`, `-h`      | Show help message                                             |

---

## BuildReplaceMfes.ps1 — MFEs Only

Builds all MFEs defined in `app.manifest.json`. Can run standalone or be dot-sourced by `BuildReplaceAll.ps1`.

### Usage

```powershell
# Build MFEs only
.\BuildReplaceMfes.ps1

# Build MFEs and replace binaries in MAF
.\BuildReplaceMfes.ps1 -ReplaceBinaries

# Show help
.\BuildReplaceMfes.ps1 -Help
```

### Parameters

| Parameter          | Description                                                            |
| ------------------ | ---------------------------------------------------------------------- |
| `-ReplaceBinaries` | After building, copies MFE dist output into the local MAF installation |
| `-Help`, `-h`      | Show help message                                                      |

### MFE Build Behavior

- Resolves MFE path from `src/mfes/<label>/`
- Auto-detects package manager via lock files:
  - `pnpm-lock.yaml` → `pnpm`
  - `yarn.lock` → `yarn`
  - `package-lock.json` → `npm`
  - Fallback → value from `BuildReplace.config.json`
- Installs dependencies if `node_modules` is missing
- Runs `<packageManager> run build`
- Uses exit code as source of truth for success/failure
- Parses output to surface Webpack and TypeScript sub-process failures

---

## BuildReplaceServices.ps1 — Services Only

Builds all .NET services defined in `app.manifest.json`. Can run standalone or be dot-sourced by `BuildReplaceAll.ps1`.

### Usage

```powershell
# Build services only
.\BuildReplaceServices.ps1

# Build services and replace binaries in MAF
.\BuildReplaceServices.ps1 -ReplaceBinaries

# Show help
.\BuildReplaceServices.ps1 -Help
```

### Parameters

| Parameter          | Description                                                               |
| ------------------ | ------------------------------------------------------------------------- |
| `-ReplaceBinaries` | After building, copies service bin output into the local MAF installation |
| `-Help`, `-h`      | Show help message                                                         |

### Service Build Behavior

- Locates `.csproj` by recursively searching under `src/services/` for `<microserviceLabel>.csproj`
- Runs `dotnet build <csproj> -c Release [-f <framework>]`
- Framework is read from `app.manifest.json` per service (`framework` field)
- Uses exit code as source of truth for success/failure

---

## Utils.ps1 — Shared Utilities

Contains all shared functions used across the three build scripts. Always loaded via dot-source — never run directly.

Provides:

- `Write-Info`, `Write-Success`, `Write-Warn`, `Write-Fail` — color-coded console output
- `Initialize-BuildEnvironment` — loads config, reads manifest, prints startup banner
- `Read-AndValidateBuildConfig` — validates `BuildReplace.config.json`
- `Resolve-MafAppPath` — reads Windows Registry, finds installed MAF app folder
- `Invoke-MfeBuildLoop` / `Invoke-ServiceBuildLoop` — iterates manifest entries, calls per-item build functions, tracks results
- `Write-MfeBuildSummary` / `Write-ServiceBuildSummary` — prints build result counts
- `Write-MfeReplaceSummary` / `Write-ServiceReplaceSummary` — prints replace result counts
- `Write-BuildSummaryBanner`, `Exit-WithBuildResult`, `Invoke-StandaloneScript` — execution helpers
- `Show-ScriptHelp`, `Test-CommandExists` — utility functions

---

## Replace Binaries Mode

When `-ReplaceBinaries` is passed to any script, it reads the MAF installation path from the Windows Registry:

```
HKLM:\SOFTWARE\WOW6432Node\WonderBiz Technologies\WonderBiz Platform\01.00\Install
```

Then resolves the installed app folder using the pattern:

```
<MAF install path>\MAF\dist\<appLabel>-<version>-*
```

For each **MFE**, it copies `dist/*` into:

```
<app folder>\mfes\<mfe-label>-*\<version>\
```

For each **Service**, it copies `bin\Release\<framework>\*` into:

```
<app folder>\services\<service-label>-*\
```

Before copying, the target folder is fully cleared to ensure no stale files remain.

> **Note:** Replace Binaries mode is Windows-only and requires MAF to be installed locally. Build-only mode works cross-platform (Windows, macOS, Linux, CI).

---

## Configuration — BuildReplace.config.json

Located at `scripts/BuildReplace.config.json`. Required fields:

| Field                   | Type   | Description                                                                  |
| ----------------------- | ------ | ---------------------------------------------------------------------------- |
| `registryKey`           | string | Windows Registry path to MAF installation (used by Replace Binaries mode)    |
| `defaultPackageManager` | string | Fallback package manager if no lock file is found (`npm`, `pnpm`, or `yarn`) |

---

## Error Handling

- `Set-StrictMode -Version 1` and `$ErrorActionPreference = "Stop"` enforced in all scripts
- Per-project failures are isolated — one failing MFE or service does not stop the rest
- Final summary counts determine the overall exit code

| Exit Code | Meaning                                              |
| --------- | ---------------------------------------------------- |
| `0`       | All builds (and replacements) completed successfully |
| `1`       | One or more failures occurred                        |

---

## Logging

All scripts use structured, color-coded console output:

| Level   | Color  | Prefix      |
| ------- | ------ | ----------- |
| Info    | Cyan   | `[INFO]`    |
| Success | Green  | `[SUCCESS]` |
| Warning | Yellow | `[WARN]`    |
| Error   | Red    | `[ERROR]`   |

Each run prints a startup banner, per-project progress, and a final summary separated into build results and (if applicable) replace results.

---

## Execution Flow

```
dev.ps1  (interactive menu)
    │
    ├── Mode 1 → BuildReplaceAll.ps1
    ├── Mode 2 → BuildReplaceMfes.ps1
    ├── Mode 3 → BuildReplaceServices.ps1
    ├── Mode 4 → BuildReplaceAll.ps1 -ReplaceBinaries
    ├── Mode 5 → BuildReplaceMfes.ps1 -ReplaceBinaries
    └── Mode 6 → BuildReplaceServices.ps1 -ReplaceBinaries


BuildReplaceAll.ps1
    │
    ├── dot-source Utils.ps1
    ├── dot-source BuildReplaceMfes.ps1     (loads functions only)
    ├── dot-source BuildReplaceServices.ps1 (loads functions only)
    │
    ├── Initialize-BuildEnvironment
    │     ├── Read & validate BuildReplace.config.json
    │     ├── Resolve src/ and app.manifest.json paths
    │     └── Print startup banner
    │
    ├── [if -ReplaceBinaries] Resolve-MafAppPath
    │     ├── Read Registry
    │     ├── Find MAF install path
    │     └── Find app folder by pattern
    │
    ├── Invoke-MfeBuildLoop
    │     └── per MFE:
    │           ├── Detect package manager
    │           ├── Install deps if needed
    │           ├── Run build
    │           └── [if -ReplaceBinaries] Copy dist → MAF mfes folder
    │
    ├── Invoke-ServiceBuildLoop
    │     └── per Service:
    │           ├── Find .csproj
    │           ├── dotnet build -c Release
    │           └── [if -ReplaceBinaries] Copy bin → MAF services folder
    │
    ├── Print Build Summary
    ├── [if -ReplaceBinaries] Print Replace Summary
    └── Exit 0 (all success) or Exit 1 (any failure)
```
