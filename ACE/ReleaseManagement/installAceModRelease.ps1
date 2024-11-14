#requires -version 5
<#
.SYNOPSIS
    Perform installation tasks for the latest ACE mod release

.DESCRIPTION
    The installation of ACE consists out of a couple of steps that need to be performed
        1. Unzipping and installing the mod release
        2. Checking installation
        3. Updating mqsiprofile
        4. Installing User Defined Nodes
        5. Installing java.security
        6. Installing shared-classes
        7. Creating a custom event view

.PARAMETER fixVersion
    The version of the latest mod release that has been installed before running this script

.PARAMETER installBasePath
    The base binary installation path for aCE, the default windows installation path is C:\Program Files\IBM\ACE\

.PARAMETER logBasePath
    The directory to write the installation log to (in the file Ace_intall_$fixVersion.log)

.PARAMETER runtimeBasePath
    The directory where the ACE runtime is located, windows default is C:\ProgramData\IBM\MQSI

.OUTPUTS
    Logging is written to the console

.NOTES
    Version:        1.0
    Author:         Matthias Blomme
    Creation Date:  2022-12-29
    Purpose/Change: Initial script development

.EXAMPLE
    .\installAceModRelease.ps1 -fixVersion 12.0.12.8 -installBasePath "C:\Program Files\ibm\ACE" -logBasePath "C:\temp" -runtimeBasePath "C:\ProgramData\IBM\MQSI" -mode nonproductionfree

#>

#-------------------------------------------------[Parameters]------------------------------------------------
param(
    [parameter(Mandatory=$true)][String]$fixVersion,
    [parameter(Mandatory=$true)][String]$installBasePath,
    [parameter(Mandatory=$true)][String]$logBasePath,
    [parameter(Mandatory=$true)][String]$runtimeBasePath,
    [parameter(Mandatory=$true)][String]$mode
)
#-----------------------------------------------[Initialisations]----------------------------------------------
#Dot Source required Function Libraries
. "./AceLibrary.ps1"

#------------------------------------------------[Declarations]------------------------------------------------
#Script Version
$sScriptVersion = "1.0"

#-------------------------------------------------[Variables]--------------------------------------------------
$aceModDir = "12.0-ACE-WINX64-$fixVersion"
$installDir = "$installBasePath\$fixVersion"

#-------------------------------------------------[Execution]--------------------------------------------------
Write-Log("Begin installAceModRelease ...")
Unzip-ModRelease -fixVersion $fixVersion -aceModDir $aceModDir

Install-ModRelease -fixVersion $fixVersion -aceModDir $aceModDir -installDir $installDir -logBasePath $logBasePath

Set-Mqsimode -fixVersion $fixVersion -mode $mode

Update-Mqsiprofile -installDir $installDir -mqsiprofileAddition "set MQSI_FREE_MASTER_PARSERS=true"
Update-Mqsiprofile -installDir $installDir -mqsiprofileAddition "set MQSI_FILENODES_SOFT_DELETE_REMOTE_FILES=true"
Update-Mqsiprofile -installDir $installDir -mqsiprofileAddition "set MQSI_FILENODES_RETRY_ON_LOGIN_FAILURE=true"

Check-AceInstall -fixVersion $fixVersion -installDir $installDir

Install-UDN -installDir $installDir

Install-SharedClasses -runtimeBasePath $runtimeBasePath

Install-JavaSecurity -installDir $installDir
Write-Log("End installAceModRelease.")
