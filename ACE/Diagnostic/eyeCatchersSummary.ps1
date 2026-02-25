<#
.SYNOPSIS
    Summarizes eyecatchers by occurrence count.

.DESCRIPTION
    Takes as input a text file where each line is an eyecatcher (e.g. BIP codes
    extracted by the eyeCatchers script), counts how often each unique line
    appears, and writes a summary file sorted by descending count.

    Output format (one per line):
        <eyecatcher> <count>

.PARAMETER InputFile
    Path to the eyecatchers input file (one eyecatcher per line).

.PARAMETER OutputFile
    Path to the summary output file.

.EXAMPLE
    .\eyeCatchersSummary.ps1 -InputFile .\BIPcodes.txt -OutputFile .\BIPcodes_summary.txt
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

# --- Validation --------------------------------------------------------------

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: '$InputFile'"
}

$outDir = Split-Path -Path $OutputFile -Parent
if ([string]::IsNullOrWhiteSpace($outDir) -eq $false -and
        -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# --- Read all lines and count occurrences ------------------------------------

# Using a hashtable just like the Perl %eyecatchers
$counts = @{}

Get-Content -LiteralPath $InputFile | ForEach-Object {
    $line = $_.Trim()

    if ([string]::IsNullOrEmpty($line)) {
        return
    }

    if ($counts.ContainsKey($line)) {
        $counts[$line]++
    }
    else {
        $counts[$line] = 1
    }
}

# --- Sort by count (descending) and write output -----------------------------

# Create "eyecatcher count" lines, sorted by count descending
$resultLines =
$counts.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        ForEach-Object {
            "{0} {1}" -f $_.Key, $_.Value
        }

$resultLines | Set-Content -LiteralPath $OutputFile -Encoding UTF8

Write-Host "Summary complete. Unique eyecatchers: $($counts.Count)" -ForegroundColor Green
Write-Host "Output written to: $OutputFile"
