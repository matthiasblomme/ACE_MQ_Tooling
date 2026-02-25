param(
    [string]$node  # Define a parameter for the integration node name
)

# Check if the <node> parameter is provided
if (-not $node) {
    Write-Host "Usage: deployedInfo.ps1 -node <node_name>"
    exit 1
}

# Run mqsilist for the given node and capture the full deployment report
$mqsilistOutput = mqsilist $node -r -d2

# Split the output into lines so we can loop through them
$outputLines = $mqsilistOutput -split [Environment]::NewLine

# These are the message identifiers we care about in the mqsilist output
$patterns = "BIP1390I", "BIP1273I", "BIP1275I", "BIP1276I"

# Regex pattern to extract:
#   - name: flow/library/application name
#   - is: the application name
#   - status: whether it's running or not
#   - time: deployment timestamp
#   - bar: BAR file path
$printPattern = "^.*?'(?<name>.*?)'.*?'(?<is>.*?)'(?<status>.*?)\s*\..*?'(?<time>.*?)'.*?'(?<bar>.*?)'.*$"

# Loop through the lines and check if they match any of the target patterns
for ($i = 0; $i -lt $outputLines.Length; $i++) {
    foreach ($pattern in $patterns) {
        if ($outputLines[$i] -match "^$pattern") {
            # Concatenate the current line with the next line (mqsilist output is usually spread over two lines)
            $output = "$($outputLines[$i]) $($outputLines[$i + 1])"

            # Try matching the output against the defined pattern
            $match = $output -match $printPattern
            if ($match -and $matches['name']) {
                # Extract the captured values
                $name   = $matches['name']
                $app    = $matches['is']
                $status = $matches['status']
                $bar    = $matches['bar']
                $timestamp = $matches['time']

                # Initialize timestamp parts in case they're not present
                $year = ''
                $month = ''
                $day = ''
                $timeOnly = ''

                # If the timestamp is in the expected format, extract the parts using a safe regex
                $timestampMatch = [regex]::Match($timestamp, '^(\d{4})-(\d{2})-(\d{2}) (\d{2}:\d{2}:\d{2})$')
                if ($timestampMatch.Success) {
                    $year = $timestampMatch.Groups[1].Value
                    $month = $timestampMatch.Groups[2].Value
                    $day = $timestampMatch.Groups[3].Value
                    $timeOnly = $timestampMatch.Groups[4].Value
                }

                # Print all fields in order: Flow, App, State, Year, Month, Day, Time, Bar
                Write-Host "$name, $app, $status, $year, $month, $day, $timeOnly, $bar"
            }
        }
    }
}
