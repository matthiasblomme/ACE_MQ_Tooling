# Function to run MQSC commands and capture output
function Run-MQSCCommand {
    param (
        [string]$queueManagerName,
        [string]$command
    )

    $output = echo $command | & "runmqsc" $queueManagerName
    return $output
}

$queueManagerName = "QM1"

# Step 1: Get subscription details (including SUB and DEST)
$subOutput = Run-MQSCCommand -queueManagerName $queueManagerName -command "dis sub(*) dest"

# Step 2: Extract subscription names (SUB) and destination queues (DEST)
$subData = @{}

$subName = ""
foreach ($line in $subOutput) {
    if ($line -match "SUB\(") {
        $subName = $line -replace "^.*SUB\(", "" -replace "\).*$", ""
    }
    if ($line -match "DEST\(" -and $subName -ne "") {
        $destQueue = $line -replace "^.*DEST\(", "" -replace "\).*$", ""
        $subData[$subName] = $destQueue
        $subName = ""  # Reset for next subscription
    }
}

# Step 3: Get existing queues
$mqOutput = Run-MQSCCommand -queueManagerName $queueManagerName -command "dis ql(*)"
$queues = $mqOutput | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^QUEUE\(" }
$queueNames = $queues -replace "^.*QUEUE\(", "" -replace "\).*$", ""

# Step 4: Identify orphaned subscriptions
Write-Host "`nChecking for subscriptions with missing destination queues..."
$orphanedSubscriptions = @()

foreach ($sub in $subData.Keys) {
    $destQueue = $subData[$sub]
    if (-not ($queueNames -contains $destQueue)) {
        Write-Host "Orphaned Subscription: '$sub' -> Destination Queue '$destQueue' does not exist!"
        $orphanedSubscriptions += $sub
    }
}

if ($orphanedSubscriptions.Count -eq 0) {
    Write-Host "`nNo orphaned subscriptions found!"
} else {
    Write-Host "`nSummary: Orphaned subscriptions found."
}
