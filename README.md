# ACE and MQ Tooling

A collection of tools, scripts, and configurations designed to simplify and enhance the management of IBM App Connect Enterprise (ACE) and IBM MQ environments. This repository provides utilities for administration, diagnostics, release management, and runtime operations.

---

## 📂 Repository Structure

### ACE/

Tools and utilities for managing IBM App Connect Enterprise.

#### `ACE/Administration/`
| Script | Language | Description |
|--------|----------|-------------|
| `listStandalone.pl` | Perl | Lists all running standalone integration servers by scanning active processes |
| `mqsirestart.cmd` | Batch | Restarts ACE integration nodes or servers; strips stop-only flags and preserves connection parameters |

#### `ACE/Diagnostic/`
Three parallel implementations (Perl, PowerShell, Python) of the same diagnostic pipeline for extracting and summarizing BIP codes from binary ACE dump files.

| Script | Language | Description |
|--------|----------|-------------|
| `eyeCatchers.pl` | Perl | Extracts BIP message codes from a binary dump file |
| `eyeCatchers.ps1` | PowerShell | Same as above — Windows-native, no Perl dependency |
| `eyeCatchers.py` | Python 3 | Same as above — chunked reading for large dumps (`--input-file`, `--output-file`, `--chunk-size`) |
| `eyeCatchersSummary.pl` | Perl | Aggregates eyecatcher output and counts occurrences per BIP code |
| `eyeCatchersSummary.ps1` | PowerShell | Same as above |
| `eyeCatchersSummary.py` | Python 3 | Same as above |

#### `ACE/ReleaseManagement/`
Full lifecycle management for ACE mod release upgrades: install, validate, activate, and rollback.

| Script | Description |
|--------|-------------|
| `AceLibrary.ps1` | Core PowerShell library dot-sourced by all release management scripts. Contains functions for logging, service checks, node start/stop, install, UDN/shared-class/security install, ODBC updates, health checks, and mode setting |
| `persistAceMqEnv.ps1` | Library providing `Persist-AceMqEnv`: persists ACE/MQ environment variables to Machine scope by running mqsiprofile in an isolated environment, cleaning old version references, and writing the result to the registry |
| `installAceModRelease.ps1` | **No-impact install**: unzips and installs a new ACE mod release, validates it, updates mqsiprofile, installs UDNs, shared classes, java.security, and persists the Machine environment |
| `postInstallAceModRelease.ps1` | **Downtime required**: activates the newly installed release — stops the old node, updates ODBC drivers, starts the node under the new version, and runs health checks |
| `rollbackAceInstall.ps1` | Emergency rollback: reverses an activation by stopping the new version and restarting the previous one |
| `installAceInterimFix.ps1` | Installs ACE interim fixes (patches). ⚠️ Marked as work-in-progress |
| `test.ps1` | Basic smoke test for library functions |

Supporting assets:
- `eventviewer/ACE_custom_view_template.xml` — Windows Event Viewer custom view template for ACE event filtering
- `security/java.security` — Custom IBM Java 8 security configuration (DNS cache TTL override)
- `udn/runtime/`, `udn/toolkit/` — Drop-in directories for User Defined Node JARs (runtime and toolkit)
- `shared-classes/` — Drop-in directory for shared JAR libraries

#### `ACE/Runtime/Windows/`
Operational utilities for day-to-day ACE management.

| Script | Description |
|--------|-------------|
| `checkPortInUse.ps1` | Identifies which process is using a given TCP port |
| `deployedInfo.ps1` | Parses `mqsilist` output to extract flow/application status, deployment timestamp, and BAR file path |
| `findJavaAndVersion.ps1` | Recursively discovers all `java.exe` instances on the system, captures their versions, and exports results to CSV |
| `persistAceMqEnv.ps1` | Standalone script version of the Machine-level ACE/MQ environment switch (see `ReleaseManagement/persistAceMqEnv.ps1` for the library version) |
| `persistAceMqEnv-once.ps1` | Simplified one-time variant of the environment persistence script |

---

### MQ/

Tools and scripts for managing IBM MQ queue managers.

#### `MQ/Runtime/Linux/`
| Script | Language | Description |
|--------|----------|-------------|
| `forAllQueues.sh` | Bash | Template for applying bulk MQSC operations across all queues (e.g. set MAXDEPTH, set custom properties on BACKOUT queues) |

#### `MQ/Runtime/Windows/`
| Script | Description |
|--------|-------------|
| `forAllQueues.ps1` | Generates and optionally applies ALTER QL commands across all queues in a queue manager. Parameters: `-qmgrName`, `-alterString` |
| `duplicateSubscriptions.ps1` | Detects pub/sub subscriptions that share the same TOPICSTR and DEST (duplicates). Parameter: `-queueManagerName` |
| `listUnusedQueues.ps1` | Lists all queue data files not written to in the last month and exports the results to CSV. Parameter: `-directoryPath` (path to the queue manager's `queues` directory) |
| `orphanedBackoutQueues.ps1` | Finds backout queues (`.BACKOUT` / `_BACKOUT` suffix) whose corresponding input queue no longer exists. Parameter: `-queueManagerName` |
| `orphanedSubscriptions.ps1` | Finds subscriptions whose destination queue no longer exists. Parameter: `-queueManagerName` |
| `restoreFromBackoutQueue.ps1` | Generates JSON mapping files (`inQ`/`outQ`) for all backout queues with messages, for use with a message restore tool. Supports an exception list for custom queue mappings. Parameter: `-outputDirectory` |

---

## 🛠 Features

- Comprehensive ACE and MQ administrative tools
- Diagnostic utilities for efficient troubleshooting (Perl, PowerShell, and Python implementations)
- Automated scripts for patch and release management with no-impact install and rollback support
- Machine-level environment variable management to prevent version contamination during upgrades
- Cross-platform queue management scripts (Windows PowerShell and Linux Bash)
- MQ data quality tools for detecting orphaned and duplicate objects

---

## 🚀 Getting Started

### Prerequisites
- IBM App Connect Enterprise 12.0+
- IBM MQ 9.2.0+
- PowerShell 5.1+ (for `.ps1` scripts on Windows)
- Bash (for `.sh` scripts on Linux)
- Python 3.x (for `.py` diagnostic scripts, optional)
- Perl (for `.pl` scripts, optional)

### Installation
1. Clone this repository:
   ```
   git clone https://github.com/matthiasblomme/ACE_MQ_Tooling.git
   ```
2. Navigate to the directory relevant to your use case (`ACE/` or `MQ/`).

---

## 📘 Usage

### ACE: Install a new mod release (no downtime)
```powershell
cd ACE/ReleaseManagement
.\installAceModRelease.ps1 -fixVersion 12.0.12.0 -oldVersion 12.0.11.0 `
    -installBasePath "C:\Program Files\IBM\ACE" `
    -logBasePath "C:\temp" `
    -runtimeBasePath "C:\ProgramData\IBM\MQSI"
```

### ACE: Activate the new release (downtime window)
```powershell
.\postInstallAceModRelease.ps1 -fixVersion 12.0.12.0 -oldVersion 12.0.11.0 `
    -installBasePath "C:\Program Files\IBM\ACE" `
    -nodeName MYNODE -hostName localhost `
    -scriptPath "C:\scripts\backup.cmd" -driverName MYDSN
```

### ACE: Rollback to previous release
```powershell
.\rollbackAceInstall.ps1 -fixVersion 12.0.12.0 -oldVersion 12.0.11.0 `
    -installBasePath "C:\Program Files\IBM\ACE" -nodeName MYNODE
```

### MQ: Find orphaned backout queues
```powershell
cd MQ/Runtime/Windows
.\orphanedBackoutQueues.ps1 -queueManagerName MYQMGR
```

### MQ: Bulk-alter all queues
```powershell
.\forAllQueues.ps1 -qmgrName MYQMGR -alterString "MAXDEPTH(5000)"
```

---

## 🤝 Contributions

Contributions are welcome! If you'd like to improve the tools or add new ones:
1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request with a detailed description of your changes.

---

## 📜 License

This repository is licensed under the **GNU General Public License v3.0**. See the [LICENSE](./LICENSE) file for details.

---

## 📝 Authors

- **Matthias Blomme**  
  Creator and maintainer of this repository.

For questions or support, feel free to reach out via GitHub Issues.
