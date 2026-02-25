# ACE and MQ Tooling

A collection of tools, scripts, and configurations designed to simplify and enhance the management of IBM App Connect Enterprise (ACE) and IBM MQ environments. This repository provides utilities for administration, diagnostics, release management, and runtime operations.

---

## 📂 Repository Structure

### ACE/
Tools and utilities for managing IBM App Connect Enterprise, divided into the following subfolders:

- **`Administration/`**
    - `listStandalone.pl`: Script to list standalone integration servers or components.

- **`Diagnostic/`**
    - `eyeCatchers.pl`: Script for extracting diagnostic information.
    - `eyeCatchersSummary.pl`: Summary script for analyzing diagnostic outputs.

- **`ReleaseManagement/`**
    - `eventviewer/`: Contains tools or templates for managing release-related event logs.
    - `ACE_custom_view_template.xml`: Template file for customizing ACE views.

- **`security/`**
    - `java.security`: Configuration for managing ACE's Java security settings.

- **`shared-classes/`**
    - `bcpg-jdk18on-177.jar`: Shared Java library for extended functionality.

- **`udn/`**
  PowerShell scripts for ACE release and patch management:
    - `AceLibrary.ps1`: Core library for ACE-specific PowerShell scripts.
    - `installAceInterimFix.ps1`: Script to install interim fixes.
    - `installAceModRelease.ps1`: Script to apply ACE module releases.
    - `postInstallAceModRelease.ps1`: Post-installation steps for ACE releases.
    - `rollbackAceInstall.ps1`: Rollback script for ACE installations.
    - `test.ps1`: Test script for verifying ACE installations.

- **`Runtime/Windows/`**
    - `checkPortInUse.ps1`: Checks for ports currently in use by ACE.
    - `deployedInfo.ps1`: Retrieves deployment information.
    - `persistAceMqEnv.ps1`: Persists ACE and MQ environment settings.

---

### MQ/Runtime/
Scripts and tools for managing IBM MQ runtimes:

- **`Linux/`**
    - `forAllQueues.sh`: Script to apply actions across all queues.

- **`Windows/`**
    - `forAllQueues.ps1`: Script for queue operations on Windows.
    - `restoreFromBackoutQueue.ps1`: Script for restoring messages from backout queues.

---

## 🛠 Features

- Comprehensive ACE and MQ administrative tools.
- Diagnostic utilities for efficient troubleshooting.
- Automated scripts for patch and release management.
- Cross-platform runtime scripts for queue management.

---

## 🚀 Getting Started

### Prerequisites
- IBM App Connect Enterprise 12.0+
- IBM MQ 9.2.0+
- PowerShell 5.0+ (for `.ps1` scripts on Windows)
- Bash (for `.sh` scripts on Linux)

### Installation
1. Clone this repository:
   ```
   git clone https://github.com/matthiasblomme/ACE_MQ_Tooling.git
   ```
2. Navigate to the directory relevant to your use case (`ACE/` or `MQ/Runtime/`).

---

## 📘 Usage

### Example: ACE Installation Rollback
1. Navigate to the `ACE/udn/` folder.
2. Run the rollback script:
   ```
   ./rollbackAceInstall.ps1
   ```

### Example: MQ Queue Management
1. Navigate to the `MQ/Runtime/Windows/` folder.
2. Run the queue operations script:
   ```
   ./forAllQueues.ps1
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
