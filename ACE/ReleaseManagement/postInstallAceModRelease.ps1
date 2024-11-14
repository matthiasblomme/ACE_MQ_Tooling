#requires -version 5
<#
.SYNOPSIS
    Perform tasks after the installation of the latest ACE mod release

.DESCRIPTION
    After the installation of a new mod release there are some actions that need to run to set that
    release active and to allow for the cleanup of the older releases.
    These actions include
        1. Updating scripts that use commands/tools from the older release
        2. Update odbc data sources
        3. Stop ACE under the original version
        4. Start ACE under the newest installed version

.PARAMETER fixVersion
    The version of the latest mod release that has been installed before running this script

.PARAMETER oldVersion
    The original (current) running version of ACE

.PARAMETER installBasePath
    The base installation path where ACE is running, the default windows installation path is C:\Program Files\IBM\ACE\

.PARAMETER nodeName
    The name of the integration node that is running and needs to switch to the latest mod release

.OUTPUTS
    Logging is written to the console

.NOTES
    Version:        1.0
    Author:         Matthias Blomme
    Creation Date:  2022-12-29
    Purpose/Change: Initial script development

.EXAMPLE
    .\postInstallAceModRelease.ps1 -fixVersion 12.0.7.0 -oldVersion 12.0.5.0 -installBasePath "C:\Program Files\ibm\ACE" -nodeName TEST -hostName localhost
#>

#-------------------------------------------------[Parameters]------------------------------------------------
param(
    [parameter(Mandatory=$true)][String]$fixVersion,
    [parameter(Mandatory=$true)][String]$oldVersion,
    [parameter(Mandatory=$true)][String]$installBasePath,
    [parameter(Mandatory=$true)][String]$nodeName,
    [parameter(Mandatory=$false)][String]$hostName
)

#-----------------------------------------------[Initialisations]----------------------------------------------
#Dot Source required Function Libraries
. "./AceLibrary.ps1"

#------------------------------------------------[Declarations]------------------------------------------------
#Script Version
$sScriptVersion = "1.0"

#-------------------------------------------------[Functions]--------------------------------------------------

#-------------------------------------------------[Execution]--------------------------------------------------
Write-Log("Begin postInstallAceModRelease...")
Update-Script -scriptPath C:\temp\backup.cmd -fixVersion $fixVersion -oldVersion $oldVersion

Stop-Ace -oldVersion $oldVersion -installBasePath $installBasePath -nodeName $nodeName

Update-ODBC -fixVersion $fixVersion -driverName DRIVER1

Start-Sleep -Seconds 5

Start-Ace -fixVersion $fixVersion -installBasePath $installBasePath -nodeName $nodeName

if ($hostName -ne '') {
    Check-httpHealth -hostName $host
    Check-httpsHealth -hostName $host
}

Write-Log("End postInstallAceModRelease.")