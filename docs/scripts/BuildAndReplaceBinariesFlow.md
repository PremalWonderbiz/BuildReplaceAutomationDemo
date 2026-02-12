# 1️⃣ Primary Diagram: Detailed Flowchart

## 🔷 Flow Structure

```
Start
  ↓
Load Parameters
  ↓
Resolve Default Paths
  ↓
Validate Manifest + WorkingDir
  ↓
Read Manifest JSON
  ↓
Is ReplaceBinaries enabled?
    ├─ Yes → Read Registry → Resolve MAF Path → Validate
    └─ No  → Continue
  ↓
BuildTarget == MfesOnly or All?
    ├─ Yes → Loop MFEs
    │         ├─ Path Exists?
    │         ├─ Install deps
    │         ├─ Run build
    │         ├─ Success?
    │         ├─ Replace if enabled
    │         └─ Update counters
    └─ No
  ↓
BuildTarget == ServicesOnly or All?
    ├─ Yes → Loop Services
    │         ├─ Find csproj
    │         ├─ dotnet build
    │         ├─ Success?
    │         ├─ Replace if enabled
    │         └─ Update counters
    └─ No
  ↓
Print Summary
  ↓
Any Failures?
    ├─ Yes → Exit 1
    └─ No  → Exit 0
```

---

# 2️⃣ Secondary Diagram: High-Level Architecture Diagram

This shows how your script interacts with the environment.

```
PowerShell Script
   │
   ├── Reads → app.manifest.json
   │
   ├── Builds → MFEs (npm/pnpm/yarn)
   │
   ├── Builds → Services (.NET CLI)
   │
   └── Replaces → MAF Install Directory (via Registry)
```

This is good for documentation / presentation.

---
