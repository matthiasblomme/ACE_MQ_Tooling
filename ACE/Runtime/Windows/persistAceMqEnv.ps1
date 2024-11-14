#. "C:\Program Files (x86)\IBM\WebSphere MQ\bin\setmqenv.cmd " -m Installation1
#. "C:\Program Files\ibm\ACE\12.0.7.0\server\bin\mqsiprofile.cmd"

#env by name
$envArray = [System.Environment]::GetEnvironmentVariables()

Write-Host "-----------------------------------------------------------------"
Write-Host "Script is running in print mode, it will not execute the commands"
Write-Host "   Remove the comment on line 18 and 24 to switch to write mode  "
Write-Host "-----------------------------------------------------------------"

foreach($key in $envArray.keys){
    $value = ($envArray[$key] | Out-String).Trim()
    if (($key -like "*MQ*") -or  ($key -like "*ACE*")) {
        #Write-Host $key
        #Write-Host $value
        Write-Host "[System.Environment]::SetEnvironmentVariable('$key', '$value', 'Machine')"
        #[System.Environment]::SetEnvironmentVariable('$key', '$value', 'Machine')
    } else {
        if (($value -like "*MQ*") -or ($value -like "*ACE*")) {
            #Write-Host $key
            #Write-Host $value
            Write-Host "[System.Environment]::SetEnvironmentVariable('$key', '$value', 'Machine')"
            #[System.Environment]::SetEnvironmentVariable('$key', '$value', 'Machine')
        }
    }
}

#env by value 