param(
    [string]$node  # Define a parameter for <node>
)

# Check if the <node> parameter is provided
if (-not $node) {
    Write-Host "Usage: deployedInfo.ps1 -node <node_name>"
    exit 1
}

# Run the mqsilist command and store the output in a variable
$mqsilistOutput = mqsilist $node -r -d2
# Split the output into an array of lines
$outputLines = $mqsilistOutput -split [Environment]::NewLine

# Define the patterns you want to match
$patterns = "BIP1390I", "BIP1273I", "BIP1275I", "BIP1276I"
$printPattern = "^.*?'(?<name>.*?)'.*?'(?<is>.*?)'(?<status>.*?)\s*\..*?'(?<time>.*?)'.*?'(?<bar>.*?)'.*$"


# Loop through each line and check if it matches any of the patterns
for ($i = 0; $i -lt $outputLines.Length; $i++) {
    foreach ($pattern in $patterns) {
        if ($outputLines[$i] -match "^$pattern") {
            # If a match is found, concatenate the line and the next line
            $output = "$($outputLines[$i]) $($outputLines[$i + 1])"
            $match = $output -match $printPattern
            if ($match) {
                if ($matches['name'] -eq '') {
                    Write-host "$($matches['name']), $($matches['is']), $($matches['time']), $($matches['bar'])"
                }
                else {
                    Write-host "$($matches['name']), $($matches['is']), $($matches['status']), $($matches['time']), $($matches['bar'])"
                }
            }
        }
    }
}
