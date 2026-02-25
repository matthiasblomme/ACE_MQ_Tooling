# Function to run MQSC commands and capture output
function Run-MQSCCommand {
    param (
        [string]$queueManagerName,
        [string]$command
    )

    # Directly run the command using PowerShell's built-in command execution
    $output = echo $command | & "runmqsc" $queueManagerName
    return $output
}

# Define your queue manager name here
$queueManagerName = "PSAAEDIMQPROD"

# Step 1: Get the list of all queues using the 'dis ql(*)' command
$mqOutput = Run-MQSCCommand -queueManagerName $queueManagerName -command "dis ql(*)"
#Write-Host "MQ Output: $mqOutput"

# Step 2: Filter out lines that contain queue names
# First, we trim extra spaces from each line and filter for those containing "QUEUE("
$queues = $mqOutput | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^QUEUE\(" }

# Check if queues were captured
if ($queues.Count -eq 0) {
    Write-Host "No queues found in the MQ output."
    exit
}

# Print the queues for debugging
#Write-Host "Queues: $queues"

# Step 3: Extract queue names from the output (queue name is between 'QUEUE(' and ')')
$queueNames = $queues -replace "^.*QUEUE\(", "" -replace "\).*$", ""

# Debug: Print extracted queue names
#Write-Host "Queue names extracted: $queueNames"

# Step 4: Filter the list for backout queues (queues ending with .BACKOUT or _BACKOUT)
$backoutQueues = $queueNames | Where-Object { $_ -match "(\.BACKOUT|_BACKOUT)$" }

# Step 5: Print all backout queues found
# Write-Host "Backout Queues Found:"
#$backoutQueues | ForEach-Object { Write-Host $_ }

# Step 6: Check if corresponding input queues exist
Write-Host "`nChecking for orphaned backout queues (where the input queue doesn't exist)..."
$orphanedQueues = @()

foreach ($backoutQueue in $backoutQueues) {
    # Check if the queue ends with '.BACKOUT' or '_BACKOUT', and remove it to find the input queue
    $inputQueue = if ($backoutQueue -match "\.BACKOUT$") {
        $backoutQueue -replace "\.BACKOUT$", ""
    } elseif ($backoutQueue -match "_BACKOUT$") {
        $backoutQueue -replace "_BACKOUT$", ""
    }

    # Check if the input queue exists
    if (-not ($queueNames -contains $inputQueue)) {
        Write-Host "$backoutQueue $inputQueue"
        $orphanedQueues += $backoutQueue
    }
}

if ($orphanedQueues.Count -eq 0) {
    Write-Host "`nNo orphaned backout queues found!"
} else {
    Write-Host "`nSummary: Orphaned backout queues found."
}
