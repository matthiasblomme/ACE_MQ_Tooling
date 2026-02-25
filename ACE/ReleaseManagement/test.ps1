. "./AceLibrary.ps1"

function Check-Service {

    Write-Host "Before check-service"
    $service = Check-Service -serviceName "bthserv"
    write-host "after check-service"

    Write-Host "Before get-service"
    $service = Get-Service -serviceName "bthserv"
    write-host "after get-service"
}
