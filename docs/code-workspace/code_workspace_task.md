# VS Code Task Configuration

VS Code tasks are configured in `project.code-workspace` under the `tasks` key. They provide one-click or keyboard-shortcut access to the build automation scripts without needing to open a terminal manually.

---

## How It Works

All tasks invoke `dev.ps1` with a specific `-Mode` argument, bypassing the interactive menu and running the chosen build mode directly.

```json
{
  "label": "Build All Projects",
  "type": "shell",
  "command": "powershell",
  "args": [
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "${workspaceFolder}/scripts/dev.ps1",
    "-Mode",
    "1"
  ]
}
```

The equivalent terminal command for this task is:

```powershell
powershell -ExecutionPolicy Bypass -File ./scripts/dev.ps1 -Mode 1
```

---

## The 6 Configured Tasks

| Label                       | Mode | What It Runs                                |
| --------------------------- | ---- | ------------------------------------------- |
| Build All Projects          | 1    | `BuildReplaceAll.ps1`                       |
| Build MFEs Only             | 2    | `BuildReplaceMfes.ps1`                      |
| Build Services Only         | 3    | `BuildReplaceServices.ps1`                  |
| Build Replace All Projects  | 4    | `BuildReplaceAll.ps1 -ReplaceBinaries`      |
| Build Replace MFEs Only     | 5    | `BuildReplaceMfes.ps1 -ReplaceBinaries`     |
| Build Replace Services Only | 6    | `BuildReplaceServices.ps1 -ReplaceBinaries` |

---

## Running Tasks

**Via keyboard shortcut:**

- `Ctrl + Shift + B` — runs the default build task (Build All Projects)

**Via the Command Palette:**

- `Ctrl + Shift + P` → `Tasks: Run Task` → select from the list

---

## Task Configuration Options Explained

### `type: "shell"`

Runs the task as a shell command through the integrated terminal.

### `command: "powershell"`

Launches Windows PowerShell as the shell executable.

### `args`

Arguments passed to PowerShell:

- `-ExecutionPolicy Bypass` — temporarily disables PowerShell's script execution restrictions for this run, preventing _"script execution is disabled"_ errors
- `-File` — tells PowerShell the next argument is a script path to execute
- `${workspaceFolder}/scripts/dev.ps1` — resolves to the absolute path of `dev.ps1` in the project root
- `-Mode <n>` — skips `dev.ps1`'s interactive menu and runs the specified mode directly

### `problemMatcher: []`

Empty array — VS Code will not try to parse script output for errors. Build results are communicated via exit codes instead.

### `presentation`

```json
{
  "echo": true,
  "reveal": "always",
  "focus": false,
  "panel": "shared",
  "showReuseMessage": true,
  "clear": false
}
```

| Option             | Value      | Effect                                                                                 |
| ------------------ | ---------- | -------------------------------------------------------------------------------------- |
| `echo`             | `true`     | Prints the full command being run in the terminal                                      |
| `reveal`           | `"always"` | Always opens the terminal panel when the task starts                                   |
| `focus`            | `false`    | Terminal opens without stealing focus from the editor                                  |
| `panel`            | `"shared"` | All tasks reuse the same terminal panel                                                |
| `showReuseMessage` | `true`     | Shows `"Terminal will be reused by tasks, press any key to close it"` after completion |
| `clear`            | `false`    | Preserves previous terminal output — useful for comparing runs                         |

### `group`

```json
{
  "kind": "build",
  "isDefault": true
}
```

- `kind: "build"` — marks the task as a build task, making it accessible via `Ctrl + Shift + B`
- `isDefault: true` — only one task should have this; it determines which task `Ctrl + Shift + B` runs directly

---

## Example Terminal Output

```
> Executing task: powershell -ExecutionPolicy Bypass -File C:\...\scripts\dev.ps1 -Mode 1

  ============================================
    Build & Replace Automation
  ============================================

  [INFO] Selected : Build All Projects
  [INFO] Script   : BuildReplaceAll.ps1
  [INFO] Mode     : Build Only

=== Script Execution Started ===
[INFO] Manifest: C:\...\src\app.manifest.json
[INFO] Working Directory: C:\...\src
[INFO] App: my-app v1.0.0

=== Building MFEs ===
[INFO] Building MFE: mfe-1
  ...
[SUCCESS] MFE 'mfe-1' built successfully

=== Build Summary ===
  MFEs:     3/3 successful
  Services: 2/2 successful

[SUCCESS] All builds completed successfully!

Terminal will be reused by tasks, press any key to close it.
```
