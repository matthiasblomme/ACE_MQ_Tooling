# Load environment settings
#. "C:\Program Files (x86)\IBM\WebSphere MQ\bin\setmqenv.cmd" -m Installation1
#. "C:\Program Files\ibm\ACE\12.0.7.0\server\bin\mqsiprofile.cmd"
# Load the environment variables set by setmqenv.cmd into the PowerShell session
cmd.exe /c "D:\IBM\WMQ\bin\setmqenv.cmd -s && set" | ForEach-Object {
    # Split the output into name and value
    $name, $value = $_ -split "="

    # Check if the name or value contains MQ, WMQ, or ACE
    if ($name -match "^(MQ|WMQ|ACE)_" -or $value -match "(MQ|WMQ|ACE)") {
        Write-Host "[System.Environment]::SetEnvironmentVariable('$name', '$value', 'Machine')"
        # Uncomment the line below to persist the variables
        [System.Environment]::SetEnvironmentVariable($name, $value, 'Machine')
    }
}