# Ace Mod Release

## Description
This project contains scripts and sources to install an ACE mod release and all related dependencies.

## Details
### General
When installing a new ACE mod release, there are a couple of dependencies that must also be taken along with the installation.

Theses dependencies include
 - User Defined Nodes
 - Java security file
 - Shared classes
 - ODBC driver
 - ACE scripts
 - Custom mqsiprofile updates

### Structure
The project consists of the following structure
```
+ACE_ReleaseInstallation
    + security
        - java.security
    + shared-classes
        - *.jar
    + udn
        + runtime
            - *.jar
        + toolkit
            - *.jar
    - <mod release zip file>
    - AceLibrary.ps1
    - installAceModRelease.ps1
    - postInstallAceModdRelease.ps1
    - rollbackAceInstall.ps1
```

### Contents
#### security
The security folder contains 1 file, the java.security file. Curently there is only 1 change compared to the default 
java.security file:


`networkaddress.cache.ttl=300`

This file is copied to %MQSI_BASE_FILEPATH%\common\jdk\jre\lib\security after successful installation of the new mod 
release.

#### shared-classes
The shared-classes folder contains libraries that are required for certain integrations, connectors, UDN's, ... 
Currently there are 3 libraries present
 - bcpg-jdk15to18-170.jar
 - bcprov-ext-jdk15to18-170.jar
 - bcprov-jdk15to18-170.jar

_bcpg-jdk15to18-170.jar_ <br />
Bouncy Castle OpenPGP API. The Bouncy Castle Java API for handling the OpenPGP protocol. This jar contains the OpenPGP 
API for JDK 1.5 to JDK 1.8. 
The APIs can be used in conjunction with a JCE/JCA provider such as the one provided with the Bouncy Castle Cryptography 
APIs.

_bcprov-ext-jdk15to18-170.jar_<br />
Bouncy Castle Provider. The Bouncy Castle Crypto package is a Java implementation of cryptographic algorithms. This jar 
contains JCE provider and lightweight API for the Bouncy Castle Cryptography APIs for JDK 1.8 and up. Note: this package 
includes the NTRU encryption algorithms.

_bcprov-jdk15to18-170.jar_<br />
Bouncy Castle Provider. The Bouncy Castle Crypto package is a Java implementation of cryptographic algorithms. This jar 
contains JCE provider and lightweight API for the Bouncy Castle Cryptography APIs for JDK 1.5 to JDK 1.8.

#### udn
The udn (User Defined Node)folder contains 2 subfolders: runtime and toolkit. As the names suggest, these contain the runtime and toolkit
files required to use the udn's.

Files from the runtime folder are copied to %MQSI_FILEPATH%\jplugin during installation, and files from the toolkit 
folder are copied to %TOOLS_FILEPATH%\plugins.

#### Mod release zip file
A file that needs to be supplied on the server (but is not committed to source control due to the nature of the file)
is the mod release zip file. The file follows the following naming convention: 12.0-ACE-WINX64-12.0.X.0.zip with X being
the version of the mod release. At the time of writing the latest release is 12.0-ACE-WINX64-12.0.7.0.zip.

#### AceLibrary.ps1
The PowerShell library that contains all functions to manage and install the mod release and the dependencies.
 - Update-Script
 - Update--EventViewer
 - Update-ODBC
 - Start-Ace
 - Stop-Ace
 - Unzip-ModRelease
 - Install-ModRelease
 - Update-Mqsiprofile
 - Check-AceInstall
 - Install-UDN
 - Install-SharedClasses
 - Install-JavaSecurity

#### installAceModRelease.ps1
The PowerShell script that handles the ace mod release installation, mqsiprofile update, UDN installation, 
shared-classes installation and java.security installation. All tasks without impact on the current running environment.

#### postInstallAceModRelease.ps1
The PowerShell script that handles post-install steps with impact and downtime of the running environment: update scripts,
update ODBC drivers and switch the runtime (stop & start).

#### rollbackAceInstall.ps1
The PowerShell script that handles a rollback to the old version with impact and downtime, should there be an issue with 
the new mod release. It updates scripts and switches the runtime back (stop & start)

## Usage
The entire project should be copied to a temporary folder on the server that needs to be installed, e.g 
`D:\temp\ACE_ReleaseInstallation`. 
Additionally, the latest mod release (currently 12.0-ACE-WINX64-12.0.7.0) needs to be downloaded from IBM Support 
and placed in this folder according to the structure defined above.

Installing the mod release (without impact or downtime) can be done by running the installAceModRelease.ps1 script from 
the ACEE_ReleaseInstallation folder.

`.\installAceModRelease.ps1 -fixVersion 12.0.7.0 -installBasePath "C:\Program Files\IBM\ACE\" -logBasePath D:\Temp\ACE_ReleaseInstallation -runtimeBasePath C:\ProgramData\IBM\MQSI`

Activating the mod release (with impact and downtime) can be done by running the postInstallAceModRelease.ps1 script from
the ACEE_ReleaseInstallation folder.

`.\postInstallAceModRelease.ps1 -fixVersion 12.0.7.0 -oldVersion 12.0.5.0 -installBasePath "C:\Program Files\IBM\ACE\" -nodeName TEST`

Rolling back to the original version (with impact and downtime) in case there are some issues after the postInstall can 
be done by running rollbackAceInstall.ps1.

`.\rollbackAceInstall.ps1 -fixVersion 12.0.7.0 -oldVersion 12.0.5.0 -installBasePath "C:\Program Files\IBM\ACE\" -nodeName TEST`

## History

| Revision | Date       | Author          |
|----------|------------|-----------------|
| 1.0      | 04-01-2023 | Matthias Blomme |
