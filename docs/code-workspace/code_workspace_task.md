# Explanation of the VS Code Task Configuration (Build project task)

This task configuration defines a **build task** in VS Code that runs a PowerShell script to build all projects in the workspace.

---

## 🔹 Basic Configuration

### `label`

```json
"label": "Build All Projects"
```

- The name shown in VS Code’s task list
- Visible when you run **`Ctrl + Shift + P` → Run Task**

---

### `type`

```json
"type": "shell"
```

- Runs the task as a shell command
- Common options:
  - `shell` – run via terminal (used here)
  - `process` – direct process execution

---

### `command`

```json
"command": "powershell"
```

- Specifies the executable to run
- In this case, the task launches **PowerShell**

---

## 🔹 Arguments

### `args`

```json
"args": [
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  "${workspaceFolder}/scripts/build-projects.ps1"
]
```

These arguments are passed directly to PowerShell.

Equivalent command:

```powershell
powershell -ExecutionPolicy Bypass -File path/to/build-projects.ps1
```

#### Argument Breakdown

1. **`-ExecutionPolicy Bypass`**
   - PowerShell restricts script execution by default
   - `Bypass` temporarily disables restrictions for this execution
   - Prevents _“script execution is disabled”_ errors

2. **`-File`**
   - Indicates that the next argument is a script file to execute

3. **`${workspaceFolder}/scripts/build-projects.ps1`**
   - Path to the PowerShell script
   - `${workspaceFolder}` automatically resolves to the project root
   - Example:

     ```
     C:\Users\You\project-structure\scripts\build-projects.ps1
     ```

---

## 🔹 Problem Matcher

### `problemMatcher`

```json
"problemMatcher": []
```

- Controls how VS Code detects errors and warnings
- Empty array means **no output parsing**
- Optional matchers:
  - `$tsc` – TypeScript errors
  - `$msCompile` – C# / MSBuild errors

---

## 🔹 Presentation (Terminal Behavior)

### `presentation`

```json
"presentation": {
  "echo": true,
  "reveal": "always",
  "focus": false,
  "panel": "shared",
  "showReuseMessage": true,
  "clear": false
}
```

#### Options Explained

- **`echo: true`**
  - Displays the executed command in the terminal

- **`reveal: "always"`**
  - Always shows the terminal when the task runs
  - Alternatives:
    - `never`
    - `silent` (only on errors)

- **`focus: false`**
  - Keeps focus in the editor
  - Terminal opens without stealing cursor focus

- **`panel: "shared"`**
  - Reuses the same terminal for all tasks
  - Options:
    - `shared`
    - `dedicated`
    - `new`

- **`showReuseMessage: true`**
  - Displays:

    ```
    Terminal will be reused by tasks, press any key to close it
    ```

- **`clear: false`**
  - Preserves previous output
  - Useful for comparing multiple build runs

---

## 🔹 Group (Task Organization)

### `group`

```json
"group": {
  "kind": "build",
  "isDefault": true
}
```

- **`kind: "build"`**
  - Marks this as a build task
  - Enables shortcut **`Ctrl + Shift + B`**

- **`isDefault: true`**
  - Makes this the **default build task**
  - Runs automatically when using the build shortcut

---

## 🔹 What Happens When You Run the Task

1. Press **`Ctrl + Shift + B`** or run the task manually
2. VS Code opens the terminal (without focusing it)
3. The executed command is echoed:

   ```text
   Executing task: powershell -ExecutionPolicy Bypass -File C:\...\build-projects.ps1
   ```

4. PowerShell executes the script
5. Script output (logs, colors, errors) appears in the terminal
6. Reuse message is shown after completion
7. Exit code determines success (✓) or failure (✗)

---

## 🔹 Real-World Example Output

```text
> Executing task: powershell -ExecutionPolicy Bypass -File c:\project-structure\scripts\build-projects.ps1

=== Build Script Started ===
[INFO] Manifest: C:\...\app.manifest.json
[INFO] Building MFE: mfe-1
...
[SUCCESS] All builds completed successfully!

Terminal will be reused by tasks, press any key to close it.
```
