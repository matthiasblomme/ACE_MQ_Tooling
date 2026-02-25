# Search for all java.exe on C: and get their versions
$javaFiles = Get-ChildItem -Path C:\ -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue -Force

$results = foreach ($file in $javaFiles) {
    try {
        # Run java.exe -version and capture stderr (since Java writes version info there)
        $version = & $file.FullName -version 2>&1
        [PSCustomObject]@{
            Path    = $file.FullName
            Version = ($version -join " ; ")
        }
    }
    catch {
        [PSCustomObject]@{
            Path    = $file.FullName
            Version = "Error running -version"
        }
    }
}

# Print results
$results | Format-Table -AutoSize

# Export to CSV
$exportPath = "C:\java_inventory.csv"
$results | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8

Write-Host "Results exported to $exportPath"
