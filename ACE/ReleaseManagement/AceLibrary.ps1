#requires -version 5
<#

 #TODO: update documentation

 .SYNOPSIS
    Library with functions related to ACE installation and management

.DESCRIPTION
    AceLibray contains functions to handle and interface with ACE. There are functions that can be used to manage ACE
        1. Start a node
        2. Stop a node

    And there are functions more related to installation task
        1. Updating scripts that use commands/tools from the older release
        2. Update odbc data sources
        3. Unzip mod release distributions
        4. Install mod releases
        5. Check if the install was succesfull
        6. Update mqsiprofile with user additions
        7. Install custom user defined nodes
        8. Install libraries in the shared-classes
        9. Update the java.security file
        10. ...

.OUTPUTS
    Logging is written to the console

.NOTES
    Version:        1.0
    Author:         Matthias Blomme
    Creation Date:  2022-12-29
    Purpose/Change: Initial script development
#>

#------------------------------------------------[Declarations]------------------------------------------------
#Library Version
$LibraryVersion = "1.1"

#-------------------------------------------------[Functions]--------------------------------------------------
function Write-Log {
    <#
    .SYNOPSIS
        Console log writer

    .DESCRIPTION
        Write-Log writes to the console and prepends the date and time in the "yyyy-MM-dd HH:mm:ss.fff" format
        to each loch line

    .PARAMETER entry
        The log line to write

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Write-Log "Begin run ..."
    #>

    param (
        [Parameter(Mandatory=$False, Position=0)][String]$entry
    )
    Begin{}

    Process{
        if ($entry -eq '') {
            $entry = " "
        }
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $entry"
    }

    End{}

}

function Check-Service {
    <#
    .SYNOPSIS
        Check if a service exists and capture the error if it doesn't

    .DESCRIPTION
        Check-Service is a function that checks if a service exists and return the name of the service if it does.
        If the service doesn't exist an empty string is returned.

    .PARAMETER serviceName
        The name of the service to check

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Check-Service -serviceName "bthserv"

    #>

    param (
        [Parameter(Mandatory=$True, Position=0)][String]$serviceName
    )
    Begin{}

    Process{
        $service = Get-Service -Name $serviceName -Erroraction 'silentlycontinue'
        return $service
    }

    End{}
}

function Update-Script {
    <#
    .SYNOPSIS
        Update scripts/files that hardcode the mod release

    .DESCRIPTION
        Update-Script is a function that reads a script/tool/file and replaces any occurence of the old mod release
        with the newest fix version

    .PARAMETER fixVersion
        The version of the latest mod release that has been installed before running this script

    .PARAMETER oldVersion
        The original (current) running version of ACE

    .PARAMETER scriptPath
        The full path to the script/file that needs to be updated

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Update-Script -scriptPath "C:\temp\backup.cmd" -fixVersion 12.0.7.0 -oldVersion 12.0.6.0

    #>

    param (
        [Parameter(Mandatory=$True)][String]$scriptPath,
        [Parameter(Mandatory=$True)][String]$fixVersion,
        [Parameter(Mandatory=$True)][String]$oldVersion
    )

    Begin{
        Write-Log "Begin updating $scriptPath ..."
    }

    Process{
        Try{
            if (-Not (Test-Path -Path $scriptPath)) {
                Write-Log "$scriptPath doesn't exists, skipping."
            } else {
                $scriptContent = Get-Content -Path "$scriptPath" -Raw
                $scriptContent = $scriptContent -replace $oldVersion, $fixVersion
                Set-Content -Path "$scriptPath" -Value $scriptContent
            }
        }

        Catch{
            Write-Log "An exception occured updating $scriptPath to $fixVersion $error"
            return
        }
    }

    End{
        If($?){
            Write-Log "Updating $scriptPath to $fixVersion succesfull."
        } else {
            Write-Log "Updating $scriptPath to $fixVersion failed."
        }
    }
}

function Create-EventViewer {
    <#
    .SYNOPSIS
        Create a new EventViewer custom view for the latest ACE mod release

    .DESCRIPTION
        Create-Eventviewer is a function that creates a new custom view in the system event viewer just for the
        latest mod release of ACE

    .PARAMETER fixVersion
        The version of the latest mod release that has been installed before running this script

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Create-EventViewer -fixVersion 12.0.7.0

    #>
    param(
        [Parameter(Mandatory=$True)][String]$fixVersion
    )

    Begin {
        $pwd = [string](Get-Location)
        $templateFile = "$pwd\eventviewer\ACE_custom_view_template.xml"
        $targetFile = "$pwd\eventviewer\ACE_custom_view_$fixVersion.xml"
    }

    Process {
        Try {
            $viewVersion = $fixVersion.replace('.','')
            if (-Not (Test-Path -Path $templateFile)) {
                Write-Log "$templateFile doesn't exists, skipping."
            } else {
                $scriptContent = Get-Content -Path "$templateFile" -Raw
                $scriptContent = $scriptContent -replace "##viewVersion##", $viewVersion
                New-Item -Path "$targetFile" -Force | Out-Null
                Set-Content -Path "$targetFile" -Value $scriptContent
                Write-Log "Created $targetFile"
                & eventvwr.exe /v:$targetFile
            }
        }

        Catch {
            Write-Log "An exception occured creating the event viewer for $fixVersion"
            return
        }
    }

    End {
        If($?){
            Write-Log "Creating EventViewer custom log succesfull, please delete any old views present."
        } else {
            Write-Log "Creating EventViewer custom logfailed."
        }
    }
}

function Update-ODBC {
    <#
    .SYNOPSIS
        Update ODBC entries with drivers from the new fixpack

    .DESCRIPTION
        Update-ODBC is a function that updates the driver for an existing ODCB connection to the driver from the
        latest fixpack

    .PARAMETER fixVersion
        The version of the latest mod release that has been installed before running this script

    .PARAMETER driverName
        The name of the ODBC driver to update

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Update-ODBC -fixVersion 12.0.7.0 -driverName DRIVER1
    #>

    param(
        [Parameter(Mandatory=$True)][String]$fixVersion,
        [Parameter(Mandatory=$True)][String]$driverName
    )

    Begin{
        Write-Log "Begin updating $driverName ..."
    }

    Process{
        Try{
            $output = & odbcconf CONFIGSYSDSN "IBM App Connect Enterprise $fixVersion - DataDirect Technologies 64-BIT Oracle Wire Protocol" "DSN=$driverName"
            Write-Log $output
        }

        Catch{
            Write-Log "An exception occured updating $driverName to $fixVersion"
            return
        }
    }

    End{
        If($?){
            Write-Log "Updating ODBC entry $driverName to $fixVersion succesfull."
        } else {
            Write-Log "Updating ODBC entry $driverName to $fixVersion failed."
        }
    }
}

function Start-Ace{
    <#
    .SYNOPSIS
        Start a node from the new mod release

    .DESCRIPTION
        Start-Ace is a function that starts the specified node from the new mod release environment

    .PARAMETER fixVersion
        The version of the latest mod release that has been installed before running this script

    .PARAMETER installBasePath
        The path to the ACE runtimes (without the version), the default windows installation path is C:\Program Files\IBM\ACE\

    .PARAMETER nodeName
        The name of the integration node to start

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Start-Ace -fixVersion 12.0.7.0 -installBasePath "C:\Program Files\IBM\ACE\" -nodeName TestNode
    #>

    param(
        [Parameter(Mandatory=$True)][String]$fixVersion,
        [Parameter(Mandatory=$True)][String]$installBasePath,
        [Parameter(Mandatory=$True)][String]$nodeName
    )

    Begin{
        Write-Log "Begin start $nodeName ..."
        $installDir = "$installBasePath\$fixVersion"
        $pwd = [string](Get-Location)
        $checkScriptPath =  "$pwd\startAce.bat"
    }

    Process{
        Try{
            Write-Log "Creating temporary file $checkScriptPath"
            $null = New-Item -Path $checkScriptPath -Force
            Add-Content -Path $checkScriptPath -value "call `"$installDir\server\bin\mqsiprofile.cmd`""
            Add-Content -Path $checkScriptPath -value "call `"ibmint`" start node $nodeName"
            Add-Content -Path $checkScriptPath -value "call `"mqsilist`" $nodeName"
            $output = & $checkScriptPath

            Remove-Item -Path $checkScriptPath -Force

            $selection = $output | Select-String "BIP8096I"
            if ($selection -like "*BIP8096I*") {
                Write-Log "$nodeName started."
            } else {
                Write-Log "Failed to verify $nodeName started, please check."
                exit 1
            }
        }

        Catch{
            Write-Log "An exception occured trying to start $nodeName"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Starting $nodeName succesfull."
        } else {
            Write-Log "Starting $nodeName failed."
        }
    }
}

function Stop-Ace {
    <#
    .SYNOPSIS
        Stop a node from the old (current) release version

    .DESCRIPTION
        Stop-Ace is a function that stops the specified node from the original environment

    .PARAMETER oldVersion
        The version of the current mod release where the node is running on

    .PARAMETER installBasePath
        The path to the ACE runtimes (without the version), the default windows installation path is C:\Program Files\IBM\ACE\

    .PARAMETER nodeName
        The name of the integration node to stop

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Stop-Ace -fixVersion 12.0.5.0 -installBasePath "C:\Program Files\IBM\ACE\" -nodeName TestNode
    #>

    param(
        [Parameter(Mandatory=$True)][String]$oldVersion,
        [Parameter(Mandatory=$True)][String]$installBasePath,
        [Parameter(Mandatory=$True)][String]$nodeName
    )

    Begin{
        Write-Log "Begin stop $nodeName ..."
        $installDir = "$installBasePath\$oldVersion"
        $pwd = [string](Get-Location)
        $checkScriptPath =  "$pwd\stopAce.bat"
    }

    Process{
        Try{
            Write-Log "Creating temporary file $checkScriptPath"
            $null = New-Item -Path $checkScriptPath -Force
            Add-Content -Path $checkScriptPath -value "call `"$installDir\server\bin\mqsiprofile.cmd`""
            Add-Content -Path $checkScriptPath -value "call `"ibmint`" stop node $nodeName"
            Add-Content -Path $checkScriptPath -value "call `"mqsilist`" $nodeName"
            $output = & $checkScriptPath

            Remove-Item -Path $checkScriptPath -Force

            $selection = $output | Select-String "BIP8019E"
            if ($selection -like "*BIP8019E*") {
                Write-Log "$nodeName stopped."
            } else {
                Write-Log "Failed to verify $nodeName is stopped, please check."
                exit 1
            }
        }

        Catch{
            Write-Log "An exception occured trying to stop $nodeName"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Stopping $nodeName succesfull."
        } else {
            Write-Log "Stopping $nodeName failed."
        }
    }
}

function Extract-7Zip {
    <#
    .SYNOPSIS
        Interface with 7-zip to unzip

    .DESCRIPTION
        Extract-7Zip is a function that extracts an archive to a target directory

    .PARAMETER ArchivePath
        The path to the archive file to extract

    .PARAMETER DestinationPath
        The path to extract the archive to

     .PARAMETER 7ZipPath
        Optional path to the 7zip executable, defaults to 'C:\Program Files\7-Zip\7z.exe'

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2023-09-27
        Purpose/Change: Initial script development

    .EXAMPLE
        Extract-7Zip -ArchivePath "C:\path\to\your\archive.zip" -DestinationPath "C:\path\to\extract\to"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ArchivePath,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$DestinationPath,

        [string]$7ZipPath = "C:\Program Files\7-Zip\7z.exe" # Default path to 7z.exe;
    )

    begin {
        # Check if 7zip executable exists
        if (-not (Test-Path $7ZipPath)) {
            Write-Error "7zip executable not found at path: $7ZipPath"
            return
        }
    }

    process {
        # Check if the archive file exists for the current pipeline item
        if (-not (Test-Path $ArchivePath)) {
            Write-Error "Archive file not found at path: $ArchivePath"
            return
        }

        # Create the destination directory if it doesn't exist
        if (-not (Test-Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory | Out-Null
        }

        # Call 7zip to extract the archive for the current pipeline item
        $command = "`"$7ZipPath`" x `"$ArchivePath`" -o`"$DestinationPath`" -y"
        write-host $command
        cmd /c $command

        if ($LASTEXITCODE -ne 0) {
            Write-Error "7zip extraction failed with exit code: $LASTEXITCODE"
        } else {
            Write-Output "Extraction of $ArchivePath completed successfully."
        }
    }

    end {
        Write-Output "Extraction process completed."
    }
}


function Unzip-ModRelease {
    <#
    .SYNOPSIS
        Unzip a mod release deliverable to a local directory

    .DESCRIPTION
        Unzip-Modrelease is a function that extracts the contents of a mod release deliverable zip to a local directory

    .PARAMETER fixVersion
        The version of the mod release to install

    .PARAMETER aceModDir
        The name of the directoy to unzip the mod release to

    .PARAMETER use7Zip
        Use 7zip or the default Expand archive from powershell

    .PARAMETER path7Zip
        The path to the 7zip installation location

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Unzip-ModRelease -fixVersion 12.0.7.0 -aceModDir 12.0-ACE-WINX64-12.0.7.0
        Unzip-ModRelease -fixVersion 12.0.7.0 -aceModDir 12.0-ACE-WINX64-12.0.7.0 -use7Zip $true
        Unzip-ModRelease -fixVersion 12.0.7.0 -aceModDir 12.0-ACE-WINX64-12.0.7.0 -use7Zip $true -path7Zip "C:\Program Files\7-Zip\7z.exe"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [String]$fixVersion,

        [Parameter(Mandatory=$True)]
        [String]$aceModDir,

        [Parameter(Mandatory=$False)]
        [Bool]$use7Zip = $false,

        [Parameter(Mandatory=$False)]
        [String]$path7Zip = ""
    )

    Begin{
        $aceZip = "$aceModDir.zip"
        $dir = [string](Get-Location)
        Write-Log "Begin unzip $aceZip to $dir\$aceModDir ..."
    }

    Process{
        Try{
            if ($use7Zip){
                if ($path7Zip -eq "") {
                    Extract-7Zip -ArchivePath $aceZip -DestinationPath $aceModDir
                } else {
                    Extract-7Zip -ArchivePath $aceZip -DestinationPath $aceModDir -7ZipPath $path7Zip
                }
            } else {
                Expand-Archive $aceZip -DestinationPath $aceModDir -Force
            }
        }

        Catch
        {
            Write-Log "An exception occured unzip $aceZip to $dir\$aceModDir"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Unzip $aceZip to $dir\$aceModDir succesfull."
        } else {
            Write-Log "Unzip $aceZip to $dir\$aceModDir failed."
        }
    }
}

function Unzip-InterimFix {
    <#
    .SYNOPSIS
        Unzip an interim fix deliverable to a local directory

    .DESCRIPTION
        Unzip-InterimFix is a function that extracts the contents of an interim fix deliverable zip to a local directory

    .PARAMETER fixName
        The name of the interim fix to install

     .PARAMETER use7Zip
        Use 7zip or the default Expand archive from powershell

     .PARAMETER path7Zip
        The path to the 7zip installation location

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Unzip-InterimFix -fixName 12.0.7.0-ACE-WinX64-LAIT42906
        Unzip-InterimFix -fixName 12.0.7.0-ACE-WinX64-LAIT42906 -use7Zip $True
        Unzip-InterimFix -fixName 12.0.7.0-ACE-WinX64-LAIT42906 -use7Zip $True -path7Zip "C:\Program Files\7-Zip\7z.exe"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [String]$fixName,

        [Parameter(Mandatory=$false)]
        [Bool]$use7Zip = $false,

        [Parameter(Mandatory=$False)]
        [String]$path7Zip = ""
    )

    Begin{
        $aceZip = "$fixName.zip"
        $dir = [string](Get-Location)
        Write-Log "Begin unzip $aceZip to $dir\$fixName ..."
    }

    Process{
        Try{
            if ($use7Zip){
                if ($path7Zip -eq "") {
                    Extract-7Zip -ArchivePath $aceZip -DestinationPath $dir\$fixName
                } else {
                    Extract-7Zip -ArchivePath $aceZip -DestinationPath $dir\$fixName -7ZipPath $path7Zip
                }
            } else {
                Expand-Archive $aceZip -DestinationPath $dir\$fixName -Force
            }
        }

        Catch
        {
            Write-Log "An exception occured unzip $aceZip to $dir\$fixName"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Unzip $aceZip to $dir\$fixName succesfull."
        } else {
            Write-Log "Unzip $aceZip to $dir\$fixName failed."
        }
    }
}

function Install-ModRelease {
    <#
    .SYNOPSIS
        Install an ACE mod release

    .DESCRIPTION
        Install-ModRelease installs an ACE mod release onto the system

    .PARAMETER fixVersion
        The version of the mod release to install

    .PARAMETER aceModDir
        The name of the directoy to install from

    .PARAMETER installDir
        The directory to install the binaries to, windows default is C:\Program Files\IBM\ACE\<version>

    .PARAMETER logBasePath
        The directory to write the installation log to (in the file Ace_intall_$fixVersion.log)

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Install-ModRelease -fixVersion 12.0.7.0 -aceModDir 12.0-ACE-WINX64-12.0.7.0 -installDir "C:\Program Files\IBM\ACE\12.0.7.0" -logBasePath "c:\temp\"
    #>
    param (
        [Parameter(Mandatory=$True)][String]$fixVersion,
        [Parameter(Mandatory=$True)][String]$aceModDir,
        [Parameter(Mandatory=$True)][String]$installDir,
        [Parameter(Mandatory=$True)][String]$logBasePath
    )

    Begin{
        $aceExe = "ACESetup$fixVersion.exe"
        $logFile = "$logBasePath\Ace_intall_$fixVersion.log"
        $aceInstallCommand = $aceExe + " /install /quiet LICENSE_ACCEPTED=TRUE InstallFolder=`"" + $installDir + "`" /log " + $logFile
        Write-Log "Begin install of $fixVersion ..."
        Write-Log "(this may take some time) ..."
    }

    Process{
        Try{
            $serviceName = "AppConnectEnterpriseMasterService$fixVersion"
            $service = Check-Service -serviceName $serviceName
            if($service.Length -gt 0)
            {
                Write-Log "Service $serviceName already exists, skipping re-installation."
                return
            }

            Set-Location $aceModDir
            Write-Log "Going to run $aceInstallCommand"
            $output = (& cmd /c $aceInstallCommand)
            Write-Log $output
            if($LASTEXITCODE -eq 0)
            {
                Write-Log "The installation succeeded, continuing ..."
            }
            else
            {
                Write-Log "The installation failed, please check $logFile"
                Write-log "code: $LASTEXITCODE"
                exit 1;
            }
            Set-Location ../
            Write-Log "Removing unzipped mod release"
            Remove-Item -Path $aceModDir -Recurse -Force
        }

        Catch
        {
            Write-Log "An exception occured installing $fixVersion"
            Write-Log $_.Exception.getType().FullName
            Write-Log $_.Exception.Message
            Break
        }
    }

    End{
        If($?){
            Write-Log "Installation of $fixVersion succesfull."
        } else {
            Write-Log "Installation of $fixVersion failed: $?"
            exit 1
        }
    }
}

#TODO: test for interim fix
function Install-InterimFix {
    <#
    .SYNOPSIS
        Install an ACE intermin fix

    .DESCRIPTION
        Install-InterimFix installs an ACE interim fix onto the system

    .PARAMETER aceVersion
        The version of runtime to install to

    .PARAMETER fixName
        The name of the fix to install

    .PARAMETER installDir
        The directory to install the binaries to, windows default is C:\Program Files\IBM\ACE\<version>

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Install-ModRelease -aceVersion 12.0.7.0 -fixName 12.0.7.0-ACE-WinX64-LAIT42906 -installDir "C:\Program Files\IBM\ACE\12.0.7.0"
    #>
    param (
        [Parameter(Mandatory=$True)][String]$aceVersion,
        [Parameter(Mandatory=$True)][String]$fixName,
        [Parameter(Mandatory=$True)][String]$installDir
    )

    Begin{
        $aceExe = "mqsifixinst.cmd"
        $aceInstallCommand = $aceExe + " `"" + $installDir + "`" install " + $fixName
        Write-Log "Begin install of $fixName ..."
        Write-Log "(this may take some time) ..."
    }

    Process{
        Try{
            $dir = [string](Get-Location)
            $aceFixDir = "$dir/$fixName"
            Set-Location $aceFixDir
            Write-Log "Going to run $aceInstallCommand"
            cmd /c $aceInstallCommand
            if($LASTEXITCODE -eq 0)
            {
                Write-Log "The installation succeeded, continuing ..."
            }
            else
            {
                Write-Log "The installation failed, please check $logFile"
                exit 1;
            }
            Set-Location ../
            Write-Log "Removing unzipped mod release"
            Remove-Item -Path $aceFixDir -Recurse -Force
        }

        Catch
        {
            Write-Log "An exception occured installing $fixName"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Installation of $fixName succesfull."
        } else {
            Write-Log "Installation of $fixName failed."
            exit 1
        }
    }
}

#TODO: test  for interim fix
function TestInstall-InterimFix {
    <#
    .SYNOPSIS
        TestInstall an ACE intermin fix

    .DESCRIPTION
        TestInstall-InterimFix testinstalls an ACE interim fix onto the system

    .PARAMETER aceVersion
        The version of runtime to testinstall to

    .PARAMETER fixName
        The name of the fix to testinstall

    .PARAMETER installDir
        The directory to testinstall the binaries to, windows default is C:\Program Files\IBM\ACE\<version>

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Install-ModRelease -aceVersion 12.0.7.0 -fixName 12.0.7.0-ACE-WinX64-LAIT42906 -installDir "C:\Program Files\IBM\ACE\12.0.7.0"
    #>
    param (
        [Parameter(Mandatory=$True)][String]$aceVersion,
        [Parameter(Mandatory=$True)][String]$fixName,
        [Parameter(Mandatory=$True)][String]$installDir,
        [Parameter(Mandatory=$True)][String]$logBasePath
    )

    Begin{
        $aceExe = "mqsifixinst.cmd"
        $aceInstallCommand = ".\" + $aceExe + " `"" + $installDir + "`" testinstall " + $fixName
        Write-Log "Begin test install of $fixName ..."
        Write-Log "(this may take some time) ..."
    }

    Process{
        Try{
            $dir = [string](Get-Location)
            $aceFixDir = "$dir/$fixName"
            Set-Location $aceFixDir
            Write-Log "Going to run $aceInstallCommand"
            cmd /c $aceInstallCommand
            Write-Log $output
            if($LASTEXITCODE -eq 0)
            {
                Write-Log "The test installation succeeded, continuing ..."
            }
            else
            {
                Write-Log "The test installation failed, please check $logFile"
                exit 1;
            }
            Set-Location ../
        }

        Catch
        {
            Write-Log "An exception occured test installing $fixName"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Test installation of $fixName succesfull."
        } else {
            Write-Log "Test installation of $fixName failed."
            exit 1
        }
    }
}

function Update-Mqsiprofile {
    <#
    .SYNOPSIS
        Update the mqsiprofile file with custom environment variables

    .DESCRIPTION
        Update-Mqsiprofile is a function that appends custom code to the mqsirprofile.cmd file of the ACE installation

    .PARAMETER installDir
        The directory where the binaries are installed, windows default is C:\Program Files\IBM\ACE\<version>

    .PARAMETER mqsiprofileAddition
        The custom code (usually environmentvariables) to append to the mqsiprofile.cmd file

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Update-Mqsiprofile -installDir "C:\Program Files\IBM\ACE\12.0.7.0" -mqsiprofileAddition "set MQSI_FREE_MASTER_PARSERS=true"
    #>
    param (
        [Parameter(Mandatory=$True)][String]$installDir,
        [Parameter(Mandatory=$True)][String]$mqsiprofileAddition
    )

    Begin{
        $mqsiprofilePath = "$installDir\server\bin\mqsiprofile.cmd"
        Write-Log "Begin update $mqsiprofilePath ..."
    }

    Process{
        Try{
            if (Test-Path -Path $mqsiprofilePath) {
                $fileContent = Get-Content $mqsiprofilePath -Raw
                $found = $fileContent | Select-String $mqsiprofileAddition -AllMatches | Foreach {$_.Matches} | Foreach {$_.Value}
                if ($found -ne $null)
                {
                    Write-Log "$mqsiprofileAddition already present, skipping"
                }
                else
                {
                    Write-Log "Adding content to $mqsiprofilePath"
                    $mqsiprofileWrite = "

rem  Custom profile addition  [
$mqsiprofileAddition
rem ]
"
                    Add-Content -Path $mqsiprofilePath -value $mqsiprofileWrite
                }
            } else {
                Write-Log "Can't locate $mqsiprofilePath, skipping"
                return
            }
        }

        Catch
        {
            Write-Log "An exception occured updating $mqsiprofilePath"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Update $mqsiprofilePath succesfull."
        } else {
            Write-Log "Update $mqsiprofilePath failed."
        }
    }
}

function Check-AceInstall {
    <#
    .SYNOPSIS
        Check if ACE is properly installed

    .DESCRIPTION
        Check-AceInstall is a function that verifies if ACE is properly installed by checking the service is running
        and by verifying that the command environment works

    .PARAMETER fixVersion
        The version of ACE to verify

    .PARAMETER installDir
       The directory where the binaries are installed, windows default is C:\Program Files\IBM\ACE\<version>

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Check-AceInstall -fixVersion 12.0.7.0 -installDir "C:\Program Files\ibm\ACE\12.0.7.0"
    #>
    param(
        [Parameter(Mandatory=$True)][String]$fixVersion,
        [Parameter(Mandatory=$True)][String]$installDir
    )

    Begin{
        Write-Log "Begin installation check ..."
    }

    Process{
        Try{
            $serviceName = "AppConnectEnterpriseMasterService$fixVersion"
            $service = Check-Service -serviceName $serviceName
            if($service.Length -gt 0)
            {
                Write-Log "$fixVersion appears to be properly installed, continuing ..."
            }
            else
            {
                Write-Log "Failed to verify $fixVersion installation (service $serviceName not found), check the installation"
                exit 1
            }

            #check mqsiprofile
            $pwd = [string](Get-Location)
            $checkScriptPath =  "$pwd\checkAceVersion.bat"
            Write-Log "Creating temporary file $checkScriptPath"
            $null = New-Item -Path ./checkAceVersion.bat -Force
            Add-Content -Path $checkScriptPath -value "call `"$installDir\server\bin\mqsiprofile.cmd`""
            Add-Content -Path $checkScriptPath -value "call `"mqsiservice.exe`" -v"
            $output = & $checkScriptPath
            Remove-Item -Path $checkScriptPath
            $selection = $output | Select-String "Version:" | select-String "$fixVersion"
            if ($selection -like "*$fixVersion*") {
                Write-Log "$fixVersion appears to be properly installed, continuing ..."
            } else {
                Write-Log "Failed to verify $fixVersion installation, please verify"
                exit 1
            }
        }

        Catch
        {
            Write-Log "An exception occured verifying $fixVersion installation"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Verify $fixVersion installation succesfull."
        } else {
            Write-Log "Verify $fixVersion installation failed."
        }
    }
}

#TODO: test for interim fix
function Check-MqsiService {
    <#
    .SYNOPSIS
        Check if ACE is properly installed

    .DESCRIPTION
        Check-AceInstall is a function that verifies if ACE is properly installed by checking the service is running
        and by verifying that the command environment works

    .PARAMETER fixVersion
        The version of ACE to verify

    .PARAMETER installDir
       The directory where the binaries are installed, windows default is C:\Program Files\IBM\ACE\<version>

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Stop-Ace -fixVersion 12.0.5.0 -installBasePath "C:\Program Files\IBM\ACE\" -nodeName TestNode
    #>
    param(
        [Parameter(Mandatory=$True)][String]$fixVersion,
        [Parameter(Mandatory=$True)][String]$installDir,
        [Parameter(Mandatory=$True)][String]$searchString
    )

    Begin{
        Write-Log "Begin installation check ..."
    }

    Process{
        Try{
            $serviceName = "AppConnectEnterpriseMasterService$fixVersion"
            $service = Check-Service -serviceName $serviceName
            if($service.Length -gt 0)
            {
                Write-Log "$fixVersion appears to be properly installed, continuing ..."
            }
            else
            {
                Write-Log "Failed to verify $fixVersion installation (service $serviceName not found), check the installation"
                exit 1
            }

            #check mqsiprofile
            $pwd = [string](Get-Location)
            $checkScriptPath =  "$pwd\checkAceVersion.bat"
            Write-Log "Creating temporary file $checkScriptPath"
            $null = New-Item -Path ./checkAceVersion.bat -Force
            Add-Content -Path $checkScriptPath -value "call `"$installDir\server\bin\mqsiprofile.cmd`""
            Add-Content -Path $checkScriptPath -value "call `"mqsiservice.exe`" -v"
            $output = & $checkScriptPath
            Remove-Item -Path $checkScriptPath
            $selection = $output | Select-String $searchString
            if ($selection -like "*$searchString*") {
                Write-Log "$searchString appears to be properly installed, continuing ..."
            } else {
                Write-Log "Failed to verify $searchString installation, please verify"
                exit 1
            }
        }

        Catch
        {
            Write-Log "An exception occured verifying $searchString installation"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Verify $searchString installation succesfull."
        } else {
            Write-Log "Verify $searchString installation failed."
        }
    }
}

function Install-UDN {
    <#
    .SYNOPSIS
        Install ACE User Define Nodes

    .DESCRIPTION
        Install-UDN is a function that installs used UDNs onto the ace runtime and toolkit

    .PARAMETER installDir
        The directory where the binaries are installed, windows default is C:\Program Files\IBM\ACE\<version>

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Install-UDN -installDir "C:\Program Files\IBM\ACE\12.0.7.0"
    #>
    param(
        [Parameter(Mandatory=$True)][String]$installDir
    )

    Begin{
        Write-Log "Begin installation UDN ..."
    }

    Process{
        Try{
            $pwd = [string](Get-Location)

            if (Test-Path -Path "$pwd\udn\toolkit\") {
                $pluginDir = "$installDir\tools\plugins"
                Write-Log "Copying from $pwd\udn\toolkit\ to $pluginDir"
                Copy-Item -Path $pwd\udn\toolkit\* -Destination $pluginDir -PassThru -Force | Out-Null
            } else {
                Write-Log "$pwd\udn\toolkit\ does not exists, skipping UDN toolkit copy ..."
            }

            if (Test-Path -Path "$pwd\udn\runtime\") {
                $jpluginDir = "$installDir\server\jplugin"
                Write-Log "Copying from $pwd\udn\runtime\ to $jpluginDir"
                Copy-Item -Path $pwd\udn\runtime\* -Destination $jpluginDir -PassThru -Force | Out-Null
            } else {
                Write-Log "$pwd\udn\runtime\ does not exists, skipping UDN runtime copy ..."
            }
        }

        Catch
        {
            Write-Log "An exception occured installing UDN's"
            return
        }
    }

    End{
        If($?){
            Write-Log "Installation of UDN's succesfull."
        } else {
            Write-Log "Installation of UDN's failed."
        }
    }
}

function Install-SharedClasses {
    <#
    .SYNOPSIS
        Install libraries into the Shared-Classes directory of ACE

    .DESCRIPTION
        Install-SharedClasses is a function that copies used jar files into the shared-classes directory of the
        ACE runtime

    .PARAMETER runtimeBasePath
        The directory where the ACE runtime is located, windows default is C:\ProgramData\IBM\MQSI

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Install-SharedClasses -runtimeBasePath "C:\ProgramData\IBM\MQSI"
    #>
    param(
        [Parameter(Mandatory=$True)][String]$runtimeBasePath
    )

    Begin{
        Write-Log "Start install shared-classes ..."
    }

    Process{
        Try{
            $pwd = [string](Get-Location)
            if (Test-Path -Path "$pwd\shared-classes") {
                $sharedClassesDir = "$runtimeBasePath\shared-classes"
                Write-Log "Copying from $pwd\shared-classes\ to $sharedClassesDir"
                Copy-Item -Path $pwd\shared-classes\* -Destination $sharedClassesDir -PassThru -Force | Out-Null
            } else {
                Write-Log "$pwd\shared-classes does not exists, skipping shared-classes copy ..."
            }
        }

        Catch
        {
            Write-Log "An exception occured installing shared-classes"
            return
        }
    }

    End{
        If($?){
            Write-Log "Installing shared-classes succesfull."
        } else {
            Write-Log "Installing shared-classes failed."
        }
    }
}

function Install-JavaSecurity {
    <#
    .SYNOPSIS
        Install a custom java.security file

    .DESCRIPTION
        Install-JavaSecurity is a function that overwrites the existing java.sercurity with an updated one

    .PARAMETER installDir
        The directory where the binaries are installed, windows default is C:\Program Files\IBM\ACE\<version>

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Install-JavaSecurity -installDir "C:\Program Files\IBM\ACE\12.0.7.0"
    #>
    param(
        [Parameter(Mandatory=$True)][String]$installDir
    )

    Begin{
        $aceZip = "$aceModDir.zip"
        $dir = [string](Get-Location)
        Write-Log "Begin installing java.security ..."
    }

    Process{
        Try{
            $pwd = [string](Get-Location)

            if (Test-Path -Path "$pwd\security") {
                $javaSecurityPath = "$installDir\common\jdk\jre\lib\security"
                Write-Log "Copying from $pwd\security to $javaSecurityPath"
                Copy-Item -Path $pwd\security\java.security -Destination $javaSecurityPath -PassThru -Force | Out-Null
            } else {
                Write-Log "$pwd\security does not exists, skipping java-security copy ..."
            }
        }

        Catch
        {
            Write-Log "An exception occured installing java.security"
            Break
        }
    }

    End{
        If($?){
            Write-Log "Installation java.security succesfull."
        } else {
            Write-Log "Installation java.security failed."
        }
    }
}

function Check-httpHealth {
    <#
    .SYNOPSIS
        Http Health Check

    .DESCRIPTION
        Check-httpHealth writes to the console and prepends the date and time in the "yyyy-MM-dd HH:mm:ss.fff" format
        to each loch line

    .PARAMETER entry
        The log line to write

    .NOTES
        Version:        1.0
        Author:         Matthias Blomme
        Creation Date:  2022-12-29
        Purpose/Change: Initial script development

    .EXAMPLE
        Write-Host "Begin run ..."
    #>

    param (
        [Parameter(Mandatory=$True, Position=0)][String]$hostName
    )
    Begin{}

    Process{
        $url = "https://" + $hostName + ":7093/httplistener/health"
        $httpResult = Invoke-RestMethod -Method 'Get' -Uri $url

        if ($httpResult.status -eq 'ok')
        {
            Write-host "Http call successful"
        } else {
            Write-host "Http call failed, check the httplistener"
        }
    }

    End{
    }

}


function Install-Scripts {
    <#
    .SYNOPSIS
        Copies all scripts from the scripts folder to the specified bin directory of the runtime.
    .DESCRIPTION
        This function copies all files under the "scripts" folder to the bin directory of the runtime specified by the `installDir` parameter.
    .PARAMETER installDir
        The target directory where the scripts will be copied.
    .EXAMPLE
        Install-Scripts -installDir "D:\IBM\ACE\12.0.12.8\server\bin\"
    .NOTES
        Ensure the target directory exists and you have sufficient permissions to write to it.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$installDir
    )

    begin {
        # Validate target directory
        if (-not (Test-Path -Path $installDir)) {
            throw "The specified install directory '$installDir' does not exist."
        }

        # Define the source directory for the scripts
        $scriptsPath = (Join-Path -Path $PSScriptRoot -ChildPath "scripts")

        # Validate source directory
        if (-not (Test-Path -Path $scriptsPath)) {
            throw "The scripts directory '$scriptsPath' does not exist."
        }
    }

    process {
        try {
            # Get all files from the scripts directory
            $scriptFiles = Get-ChildItem -Path $scriptsPath -File

            foreach ($file in $scriptFiles) {
                # Define the destination path for each file
                $destinationPath = Join-Path -Path $installDir -ChildPath $file.Name

                # Copy the file
                Write-Verbose "Copying $($file.FullName) to $destinationPath"
                Copy-Item -Path $file.FullName -Destination $destinationPath -Force
            }
        } catch {
            throw "An error occurred while copying scripts: $_"
        }
    }

    end {
        Write-Host "All scripts have been successfully copied to $installDir"
    }
}

function Invoke-AceEnvSimulation {
    <#
.SYNOPSIS
  Print-only simulation (by default) of persisting IBM ACE/MQ env vars into the Machine env.

.DESCRIPTION
  - Loads ACE via a single cmd.exe session so the 'set' sees the profile's changes:
        call mqsiprofile.cmd & set
  - Dumps ACE and Machine (System) envs.
  - Simulation rules:
      * SET-AS-IS → Names matching ^(MQ|WMQ|ACE|MQSI)_ are set as-is (Machine scope).
      * MERGE     → For variables whose *value* contains ACE/MQ paths (PATH-like):
                    - Keep ACE/MQ entries from ACE side.
                    - Strip ACE/MQ entries from Machine side.
                    - Put ACE first, then Machine leftovers.
                    - De-dupe (case-insensitive), preserve order, join with ';'
  - No changes are applied unless -PersistMachine is supplied. In apply mode, actions are shown and applied.

.PARAMETER AceProfile
  Full path to the ACE mqsiprofile.cmd to source.

.PARAMETER PersistMachine
  When present, actually writes the computed values to Machine scope
  (requires admin permissions). Otherwise, print-only.

.EXAMPLE
  # print-only (default)
  Invoke-AceEnvSimulation -AceProfile "C:\Program Files\IBM\ACE\12.0.12.17\server\bin\mqsiprofile.cmd"

.EXAMPLE
  # apply to Machine env
  Invoke-AceEnvSimulation -AceProfile "C:\Program Files\IBM\ACE\12.0.12.17\server\bin\mqsiprofile.cmd" -PersistMachine
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$AceProfile,

        [switch]$PersistMachine
    )

    # ---------- Patterns ----------
    $NameRegex  = '^(MQ|WMQ|ACE|MQSI)_'  # Name-matched => set as-is
    # Value contains any ACE/MQ-ish path segment (ibm\ace, mqsi, websphere mq, wmq, mq)
    $EntryRegex = '(?i)(^|[\\/])(?:ibm[\\/]+ace|mqsi|websphere[\\/]?mq|wmq|mq)([\\/]|$)'

    # ---------- Helpers ----------
    function Split-EnvEntries {
        param([string]$value)
        $out = @()
        if ([string]::IsNullOrWhiteSpace($value)) { return $out }
        foreach ($raw in ($value -split ';+')) {
            if ($null -eq $raw) { continue }
            $t = $raw.Trim(" `t`r`n`0;")
            if ([string]::IsNullOrWhiteSpace($t)) { continue }
            $out += $t
        }
        return $out
    }

    function Dedupe-PreserveOrder {
        param([string[]]$entries)
        $seen = @{}
        $out  = @()
        foreach ($e in $entries) {
            if ([string]::IsNullOrWhiteSpace($e)) { continue }
            $k = $e.ToLowerInvariant()
            if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $out += $e }
        }
        return ,$out  # return as string[]
    }

    function Entries-MatchingPattern    { param([string[]]$entries,[string]$regex)  return @($entries | Where-Object { $_ -match $regex }) }
    function Entries-NotMatchingPattern { param([string[]]$entries,[string]$regex)  return @($entries | Where-Object { $_ -notmatch $regex }) }

    function Load-AceEnvFromProfile {
        param([string]$ProfileCmd)
        $ht = @{}
        # single cmd.exe session so the 'set' reflects the profile's changes
        $cmdLine = "call `"$ProfileCmd`" & set"
        & cmd.exe /d /c $cmdLine 2>$null | ForEach-Object {
            $line = $_
            if ($null -ne $line) { $line = $line.Trim() }
            if ([string]::IsNullOrWhiteSpace($line)) { return }
            $parts = $line -split '=', 2
            if ($parts.Count -ne 2) { return }
            $name  = $parts[0].Trim(" `t`r`n`0") -replace "^\uFEFF","" -replace "^[\\]+",""
            $value = $parts[1]
            if ($name -ne '') { $ht[$name] = $value }
        }
        return $ht
    }

    function Load-MachineEnv {
        $dict = [System.Environment]::GetEnvironmentVariables('Machine')
        $ht = @{}
        foreach ($k in $dict.Keys) { $ht[[string]$k] = [string]$dict[$k] }
        return $ht
    }

    # ---------- Load both envs ----------
    $sys = Load-MachineEnv
    $ace = Load-AceEnvFromProfile -ProfileCmd $AceProfile

    # ---------- Dumps ----------
    Write-Host "=== Dump: ACE environment variables ==="
    foreach ($k in $ace.Keys | Sort-Object) { Write-Host "$k=$($ace[$k])" }
    Write-Host "=== End Dump (ACE) ===`n"

    Write-Host "=== Dump: System environment variables (Machine scope) ==="
    foreach ($k in $sys.Keys | Sort-Object) { Write-Host "$k=$($sys[$k])" }
    Write-Host "=== End Dump (System) ===`n"

    # ---------- Simulation ----------
    $results = @()

    # 1) Name-matched → SET-AS-IS
    foreach ($pair in $ace.GetEnumerator() | Where-Object { $_.Key -match $NameRegex }) {
        $results += [pscustomobject]@{ Action='SET-AS-IS'; Name=$pair.Key; Value=$pair.Value }
    }

    # 2) Value-matched → MERGE (ACE first)
    foreach ($pair in $ace.GetEnumerator() | Where-Object { $_.Key -notmatch $NameRegex -and $_.Value -match $EntryRegex }) {
        $n = $pair.Key

        $aceEntries = Split-EnvEntries $pair.Value
        $aceMatched = Entries-MatchingPattern -entries $aceEntries -regex $EntryRegex
        if ($aceMatched.Count -eq 0) { continue }

        $sysVal     = if ($sys.ContainsKey($n)) { $sys[$n] } else { '' }
        $sysEntries = Split-EnvEntries $sysVal
        $sysPruned  = Entries-NotMatchingPattern -entries $sysEntries -regex $EntryRegex

        # Robust array concatenation → prevents missing ';' (e.g., LIB with 8.3 paths)
        $concat      = @(@($aceMatched) + @($sysPruned))
        $dedup       = @(Dedupe-PreserveOrder $concat)
        $mergedValue = ($dedup -join ';')

        $results += [pscustomobject]@{ Action='MERGE'; Name=$n; Value=$mergedValue }
    }

    # ---------- Output / Apply ----------
    if (-not $PersistMachine) {
        Write-Host '=== Simulation Results (no changes applied) ==='
        foreach ($r in $results) {
            if ($r.Action -eq 'SET-AS-IS') {
                Write-Host ("[WOULD SET] {0}={1}" -f $r.Name, $r.Value)
                # [System.Environment]::SetEnvironmentVariable($r.Name, $r.Value, 'Machine')
            }
            elseif ($r.Action -eq 'MERGE') {
                Write-Host ("[WOULD MERGE] {0}={1}" -f $r.Name, $r.Value)
                # [System.Environment]::SetEnvironmentVariable($r.Name, $r.Value, 'Machine')
            }
        }
        Write-Host '=== End ==='
        return
    }

    # Persist to Machine (requires admin)
    Write-Host '=== APPLYING changes to Machine environment ==='
    foreach ($r in $results) {
        try {
            Write-Host ("[APPLY] {0} {1}={2}" -f ($r.Action -eq 'MERGE' ? 'MERGE' : 'SET'), $r.Name, $r.Value)
            [System.Environment]::SetEnvironmentVariable($r.Name, $r.Value, 'Machine')
        }
        catch {
            Write-Warning "Failed to set $($r.Name): $($_.Exception.Message)"
        }
    }
    Write-Host '=== Done applying changes ==='
}
