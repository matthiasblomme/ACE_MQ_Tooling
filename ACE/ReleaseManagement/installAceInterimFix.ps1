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
    .\installAceInterimFix.ps1 -fixVersion 12.0.7.0 -fixName TFIT42022 -installBasePath "C:\Program Files\ibm\ACE" -logBasePath "C:\temp" -runtimeBasePath "C:\ProgramData\IBM\MQSI"
    .\installAceInterimFix.ps1 -fixVersion 12.0.7.0 -ixName TFIT42022 -installBasePath "D:\IBM\ACE" -logBasePath "C:\temp" -runtimeBasePath "D:\IBM\MQSI\Nodes"

#>

#-------------------------------------------------[Parameters]------------------------------------------------
param(
    [parameter(Mandatory=$true)][String]$fixVersion,
    [parameter(Mandatory=$true)][String]$fixName,
    [parameter(Mandatory=$true)][String]$installBasePath,
    [parameter(Mandatory=$true)][String]$logBasePath,
    [parameter(Mandatory=$true)][String]$runtimeBasePath
)
#-----------------------------------------------[Initialisations]----------------------------------------------
#Dot Source required Function Libraries
. "./AceLibrary.ps1"

#------------------------------------------------[Declarations]------------------------------------------------
#Script Version
$sScriptVersion = "1.0"

#-------------------------------------------------[Functions]--------------------------------------------------

#-------------------------------------------------[Execution]--------------------------------------------------
Write-Log("Begin installAceInterimFix ...")

#run from C:\Users\ADM-BLMM_M\modrelease
$installDir = "$installBasePath\$fixVersion"
$fullFixName = "$fixVersion-ACE-WinX64-$fixName"
Unzip-InterimFix -fixName $fullFixName

TestInstall-InterimFix -aceVersion $fixVersion -fixName $fullFixName  -installDir $installDir -logBasePath $logBasePath
Install-InterimFix -aceVersion $fixVersion -fixName $fullFixName  -installDir $installDir

Check-AceInstall -fixVersion $fixVersion -installDir $installDir
Check-MqsiService -fixVersion $fixVersion -installDir $installDir -searchString $fixName

Write-Log("End installAceInterimFix. Don't forget to restart!")