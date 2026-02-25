param(
    [parameter(Mandatory=$true)]
    [ValidateRange(1, [int]::MaxValue)]
    [int] $portNumber
)

Begin {
}

process{
    try{
        $tcp = Get-NetTCPConnection -LocalPort $portNumber -ErrorAction Ignore
        $proc = Get-Process -Id ($tcp).OwningProcess -ErrorAction Ignore

        Write-Host "Name: " $proc.Name
        Write-Host "Proc Id: " $proc.Id
    }
    catch {

    }
}


End {
    If($?){

    } else {
        Write-Host "No process is using port $portNumber."
    }
}
