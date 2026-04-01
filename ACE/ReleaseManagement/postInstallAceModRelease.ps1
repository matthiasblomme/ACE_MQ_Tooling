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

.PARAMETER scriptPath
    Path to a script file that hardcodes the ACE version and needs to be updated (e.g. a backup .cmd)

.PARAMETER driverName
    Name of the ODBC data source to update with the new ACE version driver

.OUTPUTS
    Logging is written to the console

.NOTES
    Version:        1.0
    Author:         Matthias Blomme
    Creation Date:  2022-12-29
    Purpose/Change: Initial script development

.EXAMPLE
    .\postInstallAceModRelease.ps1 -fixVersion 12.0.7.0 -oldVersion 12.0.5.0 -installBasePath "C:\Program Files\ibm\ACE" -nodeName TEST -hostName localhost -scriptPath "C:\scripts\backup.cmd" -driverName DRIVER1
#>

#-------------------------------------------------[Parameters]------------------------------------------------
param(
    [parameter(Mandatory=$true)][String]$fixVersion,
    [parameter(Mandatory=$true)][String]$oldVersion,
    [parameter(Mandatory=$true)][String]$installBasePath,
    [parameter(Mandatory=$true)][String]$nodeName,
    [parameter(Mandatory=$false)][String]$hostName,
    [parameter(Mandatory=$false)][String]$scriptPath,
    [parameter(Mandatory=$false)][String]$driverName
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

if ($scriptPath -ne '') {
    Update-Script -scriptPath $scriptPath -fixVersion $fixVersion -oldVersion $oldVersion
}

Stop-Ace -oldVersion $oldVersion -installBasePath $installBasePath -nodeName $nodeName

if ($driverName -ne '') {
    Update-ODBC -fixVersion $fixVersion -driverName $driverName
}

Start-Sleep -Seconds 5

Start-Ace -fixVersion $fixVersion -installBasePath $installBasePath -nodeName $nodeName

if ($hostName -ne '') {
    Check-httpHealth -hostName $host
    Check-httpsHealth -hostName $host
}

Write-Log("End postInstallAceModRelease.")