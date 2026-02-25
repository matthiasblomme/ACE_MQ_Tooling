#requires -version 5
<#
.SYNOPSIS
    Reactivate an older version of ACE

.DESCRIPTION
    Should an issue occure after upgrading your environment and activating the new version, you can rollback this
    version by running the rollBackAceInstall script with the same parameters as you wouldd run the postInstallAceModRelease.ps1 script.
    The script updates any files that have been changed by the release and stop the selected node under the new version
    and restarts it under the old runtime.

.PARAMETER fixVersion
    The version of the latest mod release that needs to be rolled back

.PARAMETER oldVersion
    The original version of ACE that needs to be reactivated

.PARAMETER installBasePath
    The base installation path where ACE is running, the default windows installation path is C:\Program Files\IBM\ACE\

.PARAMETER nodeName
    The name of the integration node that is running and needs to switch to the previous mod releasee

.OUTPUTS
    Logging is written to the console

.NOTES
    Version:        1.0
    Author:         Matthias Blomme
    Creation Date:  2022-12-29
    Purpose/Change: Initial script development

.EXAMPLE
    .\rollbackAceInstall.ps1 -fixVersion 12.0.7.0 -oldVersion 12.0.5.0 -installBasePath "C:\Program Files\ibm\ACE" -nodeName TEST
#>

#-------------------------------------------------[Parameters]------------------------------------------------
param(
    [parameter(Mandatory=$true)][String]$fixVersion,
    [parameter(Mandatory=$true)][String]$oldVersion,
    [parameter(Mandatory=$true)][String]$installBasePath,
    [parameter(Mandatory=$true)][String]$nodeName
)

#-----------------------------------------------[Initialisations]----------------------------------------------
#Dot Source required Function Libraries
. "./AceLibrary.ps1"

#------------------------------------------------[Declarations]------------------------------------------------
#Script Version
$sScriptVersion = "1.0"

#-------------------------------------------------[Functions]--------------------------------------------------

#-------------------------------------------------[Execution]--------------------------------------------------
Write-Log("Begin rollbackAceInstall...")
Update-Script -scriptPath C:\temp\backup.cmd -fixVersion $oldVersion -oldVersion $fixVersion
Stop-Ace -oldVersion $fixVersion -installBasePath $installBasePath -nodeName $nodeName
Start-Sleep -Seconds 5
Start-Ace -fixVersion $oldVersion -installBasePath $installBasePath -nodeName $nodeName
Write-Log("End rollbackAceInstall.")