# Function to run MQSC commands and capture output
function Run-MQSCCommand {
    param (
        [string]$queueManagerName,
        [string]$command
    )

    $output = echo $command | & "runmqsc" $queueManagerName
    return $output
}

$queueManagerName = "PSAAEDIMQTEST"

# Step 1: Get subscription details (including SUB, TOPICSTR, DEST)
$subOutput = Run-MQSCCommand -queueManagerName $queueManagerName -command "dis sub(*) topicstr dest"

# Step 2: Extract SUB, TOPICSTR, and DEST values
$subData = @()
$subName = ""
$topicStr = ""
$destQueue = ""

foreach ($line in $subOutput) {
    if ($line -match "SUB\(") {
        $subName = $line -replace "^.*SUB\(", "" -replace "\).*$", ""
    }
    if ($line -match "TOPICSTR\(") {
        $topicStr = $line -replace "^.*TOPICSTR\(", "" -replace "\).*$", ""
    }
    if ($line -match "DEST\(") {
        $destQueue = $line -replace "^.*DEST\(", "" -replace "\).*$", ""

        # Store in array
        $subData += [PSCustomObject]@{
            SUB = $subName
            TOPICSTR = $topicStr
            DEST = $destQueue
        }

        # Reset values
        $subName = ""
        $topicStr = ""
        $destQueue = ""
    }
}

# Step 3: Group subscriptions by TOPICSTR and DEST to find duplicates
$duplicates = $subData | Group-Object -Property TOPICSTR, DEST | Where-Object { $_.Count -gt 1 }

# Step 4: Print duplicate subscriptions
Write-Host "`nChecking for duplicate subscriptions with the same TOPICSTR and DEST..."
if ($duplicates.Count -eq 0) {
    Write-Host "No duplicate subscriptions found!"
} else {
    Write-Host "`nDuplicate subscriptions detected:"
    foreach ($group in $duplicates) {
        Write-Host "`nTOPICSTR: $($group.Group[0].TOPICSTR) | DEST: $($group.Group[0].DEST)"
        foreach ($sub in $group.Group) {
            Write-Host "  - Subscription: $($sub.SUB)"
        }
    }
}
