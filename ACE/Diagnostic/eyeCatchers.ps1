<#
.SYNOPSIS
    Extracts BIP message identifiers from a binary dump file.

.DESCRIPTION
    This script scans a binary input file for sequences of printable ASCII
    characters (plus whitespace) of length 4 or more. Within those sequences
    it looks for patterns of the form:

        >BIPxxxx

    where "xxxx" are four word characters (letters, digits, or underscore).
    Each BIP code found (e.g. "BIP2232") is written as a single line
    to the specified output file.

    This is a PowerShell rewrite of the classic Perl "eyeCatchers" script
    used for parsing IBM integration / broker dumps.

.PARAMETER InputFile
    Path to the binary dump file to be scanned.

.PARAMETER OutputFile
    Path to the text file where extracted BIP codes will be written.

.EXAMPLE
    .\eyeCatchers.ps1 -InputFile .\core.dmp -OutputFile .\BIPcodes.txt

.NOTES
    - Designed for Windows PowerShell 5.1 and PowerShell 7+.
    - Reads the input as raw bytes to avoid encoding issues.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true,
            Position  = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$InputFile,

    [Parameter(Mandatory = $true,
            Position  = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputFile
)

# --- Basic validation --------------------------------------------------------

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: '$InputFile'"
}

# Ensure output directory exists (if user passed a path with directories)
$outDir = Split-Path -Path $OutputFile -Parent
if ([string]::IsNullOrWhiteSpace($outDir) -eq $false -and
        -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# --- Helper: test if a byte is printable ASCII or whitespace -----------------

function Test-PrintableOrWhitespace {
    param(
        [Parameter(Mandatory = $true)]
        [byte]$Byte
    )

    # Printable ASCII range 0x20 (' ') to 0x7E ('~')
    if ($Byte -ge 0x20 -and $Byte -le 0x7E) {
        return $true
    }

    # Also allow "whitespace" characters, similar to Perl \s
    $char = [char]$Byte
    if ([char]::IsWhiteSpace($char)) {
        return $true
    }

    return $false
}

# --- Read file as raw bytes --------------------------------------------------

# Using .NET directly avoids any implicit encoding assumptions by Get-Content.
[byte[]]$bytes = [System.IO.File]::ReadAllBytes($InputFile)

# StringBuilder to accumulate a current "printable" segment
$segmentBuilder = [System.Text.StringBuilder]::new()

# List to store extracted BIP codes
$foundBipCodes = [System.Collections.Generic.List[string]]::new()

# Regex pattern: find ">BIPxxxx" and capture "BIPxxxx"
# This corresponds to the Perl patterns:
#   />(BIP\d{4})/
#   />(BIP\w{4})/
# but unified to "four word characters".
$pattern = '>(BIP\w{4})'

function Process-Segment {
    param(
        [Parameter(Mandatory = $true)]
        [System.Text.StringBuilder]$Builder
    )

    # Only process if we reached the minimum length of 4 characters.
    if ($Builder.Length -lt 4) {
        $Builder.Clear() | Out-Null
        return
    }

    $text = $Builder.ToString()

    # Find all matches of >BIPxxxx and store the captured code (group 1).
    [System.Text.RegularExpressions.Regex]::Matches($text, $pattern) |
            ForEach-Object {
                $foundBipCodes.Add($_.Groups[1].Value)
            }

    # Clear for the next segment.
    $Builder.Clear() | Out-Null
}

# --- Main scan loop ----------------------------------------------------------

foreach ($b in $bytes) {
    if (Test-PrintableOrWhitespace -Byte $b) {
        # Append printable/whitespace char to current segment
        [void]$segmentBuilder.Append([char]$b)
    }
    else {
        # Non-printable: end of current segment, process it
        Process-Segment -Builder $segmentBuilder
    }
}

# Process any remaining segment at EOF
if ($segmentBuilder.Length -gt 0) {
    Process-Segment -Builder $segmentBuilder
}

# --- Write results -----------------------------------------------------------

# Write one BIP code per line. Using UTF8 is fine since content is ASCII.
$foundBipCodes | Set-Content -LiteralPath $OutputFile -Encoding UTF8

Write-Host "Scan complete. Found $($foundBipCodes.Count) BIP code(s)." -ForegroundColor Green
Write-Host "Output written to: $OutputFile"
