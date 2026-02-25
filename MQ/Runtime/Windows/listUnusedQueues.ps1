# Define the path to the directory
$directoryPath = "D:\MQ\qmgrs\QMGR\queues"

# Get the current directory
$currentDirectory = Get-Location

# Define the output CSV file path in the current directory
$outputCsv = Join-Path -Path $currentDirectory -ChildPath "Files_Not_Accessed.csv"

# Get the current date and calculate the date 1 month ago
$currentDate = Get-Date
$oneMonthAgo = $currentDate.AddMonths(-1)

# Get all files in the directory that haven't been modified in the last month
$files = Get-ChildItem -Path $directoryPath -File -Recurse |
        Where-Object { $_.LastWriteTime -lt $oneMonthAgo }

# Create an array to store the file details
$fileDetails = @()

# Loop through each file and collect details
foreach ($file in $files) {
    # Replace '!' with '.' in the file name
    $fileName = $file.Name -replace '!', '.'

    # Create a custom object with file name and last modified time
    $fileDetail = [PSCustomObject]@{
        'File Name'       = $fileName
        'Last Modified'   = $file.LastWriteTime
    }

    # Add the file detail to the array
    $fileDetails += $fileDetail
}

# Export the file details to a CSV file
$fileDetails | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "CSV file of files not modified in the last month has been created at: $outputCsv"
