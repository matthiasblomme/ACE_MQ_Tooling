#Requires -Version 5.1
<#
.SYNOPSIS
    IaC reconciliation script for IBM MQ. Config files are the single source of truth.

.DESCRIPTION
    Reads one or more MQSC config files (single-line format) and reconciles the target
    queue manager to match: creating missing objects, updating objects where specified
    attributes differ, and optionally deleting objects that are not present in the config.

    Only attributes explicitly listed in the config file are compared and updated.
    All other existing attributes on an object are left untouched.

.PARAMETER QueueManager
    Name of the queue manager to target.

.PARAMETER ConfigFile
    One or more paths to MQSC config files. Files are processed in order.

.PARAMETER Delete
    If specified, objects found on the queue manager but not present in any config file
    will be deleted. Combine with -SkipSystemObjects (default: on) to protect SYSTEM.* objects.

.PARAMETER WhatIf
    Dry-run mode. Prints all planned MQSC commands without executing them.
    Current state IS queried, so CREATE vs UPDATE vs OK is accurately reported.

.PARAMETER SkipSystemObjects
    When using -Delete, skip any object whose name starts with "SYSTEM." or "AMQ.".
    Defaults to $true.

.PARAMETER Purge
    When deleting queue objects (QLOCAL/QREMOTE/QALIAS/QMODEL), append PURGE to the DELETE
    command so non-empty queues are cleared automatically. Has no effect without -Delete.

.PARAMETER DockerContainer
    If specified, all runmqsc commands are executed via 'docker exec -i <container>'.
    Useful when the queue manager runs inside a Docker container.

.EXAMPLE
    .\Invoke-MQConfig.ps1 -QueueManager QM1 -ConfigFile .\queues.mqsc -WhatIf
    .\Invoke-MQConfig.ps1 -QueueManager QM1 -ConfigFile .\queues.mqsc,.\channels.mqsc
    .\Invoke-MQConfig.ps1 -QueueManager QM1 -ConfigFile .\config\*.mqsc -Delete -Purge
    .\Invoke-MQConfig.ps1 -QueueManager QM1 -ConfigFile .\queues.mqsc -DockerContainer QM1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $QueueManager,

    [Parameter(Mandatory)]
    [string[]] $ConfigFile,

    [switch] $Delete,

    [switch] $Purge,

    [switch] $WhatIf,

    [bool] $SkipSystemObjects = $true,

    [string] $DockerContainer = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region --- Constants ---

# Maps object type keyword to display/delete verb used in runmqsc
$script:ObjectTypeMap = [ordered]@{
    QLOCAL  = @{ Display = 'QLOCAL';  Delete = 'QLOCAL'  }
    QREMOTE = @{ Display = 'QREMOTE'; Delete = 'QREMOTE' }
    QALIAS  = @{ Display = 'QALIAS';  Delete = 'QALIAS'  }
    QMODEL  = @{ Display = 'QMODEL';  Delete = 'QMODEL'  }
    CHANNEL = @{ Display = 'CHANNEL'; Delete = 'CHANNEL' }
    TOPIC   = @{ Display = 'TOPIC';   Delete = 'TOPIC'   }
    SUB     = @{ Display = 'SUB';     Delete = 'SUB'     }
}

# Counters
$script:CountCreate = 0
$script:CountUpdate = 0
$script:CountDelete = 0
$script:CountOk     = 0
$script:CountError  = 0

#endregion

#region --- Logging ---

function Write-MQLog {
    param([string]$Tag, [string]$Message, [string]$Color = 'White')
    Write-Host ("  [{0,-6}] {1}" -f $Tag, $Message) -ForegroundColor $Color
}

#endregion

#region --- Helpers ---

function Format-MQObjectName {
    <#
    .SYNOPSIS
        Returns the object name ready for embedding in an MQSC command.
        Names containing whitespace are wrapped in single quotes.
    #>
    param([string] $Name)
    if ($Name -match '\s') { return "'$Name'" }
    return $Name
}

#endregion

#region --- MQSC Line Parser ---

function ConvertFrom-MQSCLine {
    <#
    .SYNOPSIS
        Parses a single-line MQSC statement into a structured object.
    .OUTPUTS
        PSCustomObject with Verb, ObjectType, ObjectName, Attributes hashtable.
        Returns $null for comment lines, empty lines, or unrecognised verbs.
    #>
    param([string] $Line)

    $trimmed = $Line.Trim()

    # Skip MQSC comments and empty lines
    if ($trimmed -eq '' -or $trimmed.StartsWith('*') -or $trimmed.StartsWith('--')) {
        return $null
    }

    # Match verb: DEFINE or ALTER
    if ($trimmed -notmatch '^(DEFINE|ALTER)\s+') {
        Write-Verbose "Skipping unrecognised line: $trimmed"
        return $null
    }
    $verb = $Matches[1]
    $rest = $trimmed.Substring($verb.Length).TrimStart()

    # Match object type keyword (e.g. QLOCAL, CHANNEL, SUB ...)
    $knownTypes = $script:ObjectTypeMap.Keys -join '|'
    if ($rest -notmatch "^($knownTypes)\s*\(") {
        Write-Verbose "Skipping unknown object type in: $trimmed"
        return $null
    }
    $objectType = $Matches[1]
    $rest = $rest.Substring($objectType.Length).TrimStart()

    # Match object name - first token of form (NAME)
    if ($rest -notmatch '^\(([^)]+)\)') {
        Write-Verbose "Cannot parse object name from: $trimmed"
        return $null
    }
    # Strip surrounding single quotes from name if present (e.g. SUB('name with spaces'))
    $objectName = $Matches[1].Trim() -replace "^'|'$", ''
    $rest = $rest.Substring($Matches[0].Length).TrimStart()

    # Parse remaining KEY(VALUE) attribute pairs
    # VALUE may be a quoted string 'text' or an unquoted keyword
    $attributes = @{}
    $attrPattern = [regex]"([A-Z][A-Z0-9]*)\(('[^']*'|[^)]*)\)"

    foreach ($m in $attrPattern.Matches($rest)) {
        $key   = $m.Groups[1].Value.ToUpperInvariant()
        $value = $m.Groups[2].Value
        $attributes[$key] = $value
    }

    return [PSCustomObject]@{
        Verb       = $verb
        ObjectType = $objectType
        ObjectName = $objectName
        Attributes = $attributes
    }
}

#endregion

#region --- runmqsc Wrappers ---

function Invoke-RunmqscRaw {
    <#
    .SYNOPSIS
        Pipes MQSC input directly to runmqsc, either locally or via docker exec.
        Always executes - no WhatIf gate. Used for reads and writes alike.
    #>
    param([string] $MqscInput)

    try {
        if ($DockerContainer -ne '') {
            $output = $MqscInput | docker exec -i $DockerContainer bash -c "runmqsc $QueueManager" 2>&1
        }
        else {
            $output = $MqscInput | & runmqsc $QueueManager 2>&1
        }
        return ($output -join "`n")
    }
    catch {
        throw "runmqsc execution failed: $_"
    }
}

function Invoke-RunmqscCommand {
    <#
    .SYNOPSIS
        Executes one or more mutating MQSC commands. Respects -WhatIf.
    .OUTPUTS
        Raw stdout string from runmqsc. Returns $null in WhatIf mode.
    #>
    param([string[]] $Commands)

    if ($WhatIf) {
        foreach ($cmd in $Commands) {
            Write-Host "  [WHATIF ] $cmd" -ForegroundColor DarkCyan
        }
        return $null
    }

    $joined = ($Commands -join "`n") + "`nEND"
    return Invoke-RunmqscRaw -MqscInput $joined
}

#endregion

#region --- runmqsc Output Parser ---

function ConvertFrom-RunmqscOutput {
    <#
    .SYNOPSIS
        Parses the multi-line output of a DISPLAY command into a flat attribute hashtable.
    .DESCRIPTION
        runmqsc wraps attribute output across multiple lines. This function joins
        continuation lines and extracts all KEY(VALUE) pairs.
    #>
    param([string] $RawOutput)

    $result = @{}

    # Strip header/trailer lines and command echo lines
    $lines = $RawOutput -split "`n" | ForEach-Object { $_.TrimEnd() }

    $attrLines = $lines | Where-Object {
        $_ -ne '' `
        -and $_ -notmatch '^AMQ\d+' `
        -and $_ -notmatch '^\d+ MQSC command' `
        -and $_ -notmatch '^\s+\d+\s*:' `
        -and $_ -notmatch '^5724-' `
        -and $_ -notmatch '^Starting MQSC'
    }

    $combined = $attrLines -join ' '

    $attrPattern = [regex]"([A-Z][A-Z0-9]*)\(('[^']*'|[^)]*)\)"
    foreach ($m in $attrPattern.Matches($combined)) {
        $key   = $m.Groups[1].Value.ToUpperInvariant()
        $value = $m.Groups[2].Value
        $result[$key] = $value
    }

    return $result
}

#endregion

#region --- MQ Object State Queries ---

function Get-MQObjectCurrentState {
    <#
    .SYNOPSIS
        Returns the current attribute hashtable for an MQ object, or $null if it doesn't exist.
    #>
    param([string] $ObjectType, [string] $ObjectName)

    $cmd = "DISPLAY $ObjectType($(Format-MQObjectName $ObjectName)) ALL"

    # Always runs - not gated by WhatIf (read-only, needed for accurate diff)
    try {
        $raw = Invoke-RunmqscRaw -MqscInput "$cmd`nEND"
    }
    catch {
        throw "Failed to query $ObjectType($ObjectName): $_"
    }

    $attrs = ConvertFrom-RunmqscOutput -RawOutput $raw

    # Object not found: no attributes parsed AND an error code present in output
    # Covers AMQ8147E (queue), AMQ8418E (channel), AMQ8755E (topic), AMQ8103E (sub), etc.
    if ($attrs.Count -eq 0 -and $raw -match 'AMQ\d+E') {
        return $null
    }

    return $attrs
}

function Get-AllMQObjectNames {
    <#
    .SYNOPSIS
        Returns a list of all object names of the given type on the queue manager.
    #>
    param([string] $ObjectType)

    # The attribute name that holds the object name in DISPLAY output per type
    $nameAttr = if ($ObjectType -match '^Q') { 'QUEUE' } else { $ObjectType }

    $cmd = "DISPLAY $ObjectType(*)"

    try {
        $raw = Invoke-RunmqscRaw -MqscInput "$cmd`nEND"
    }
    catch {
        throw "Failed to enumerate ${ObjectType}s: $_"
    }

    # Strip command echo lines (e.g. "     1 : DISPLAY CHANNEL(*)") before regex matching
    # to prevent the wildcard (*) from being extracted as an object name
    $filtered = ($raw -split "`n") |
        Where-Object { $_ -notmatch '^\s+\d+\s*:' } |
        Out-String

    $names = [System.Collections.Generic.List[string]]::new()
    $pattern = [regex]"$nameAttr\(([^)]+)\)"
    foreach ($m in $pattern.Matches($filtered)) {
        $names.Add($m.Groups[1].Value.Trim())
    }

    return $names
}

#endregion

#region --- Attribute Comparison ---

function Compare-MQAttributes {
    <#
    .SYNOPSIS
        Compares desired attributes against current ones.
        Only keys present in $Desired are evaluated.
    .OUTPUTS
        Hashtable of attributes that need updating (key -> desired value).
    #>
    param(
        [hashtable] $Desired,
        [hashtable] $Current
    )

    $diff = @{}
    foreach ($key in $Desired.Keys) {
        $desiredVal = $Desired[$key]
        $currentVal = if ($Current.ContainsKey($key)) { $Current[$key] } else { '' }

        # Normalise for comparison: strip surrounding single-quotes
        $desiredNorm = $desiredVal -replace "^'|'$", ''
        $currentNorm = $currentVal -replace "^'|'$", ''

        if ($desiredNorm -ne $currentNorm) {
            $diff[$key] = $desiredVal
        }
    }
    return $diff
}

#endregion

#region --- Attribute Serialiser ---

function ConvertTo-MQSCAttributes {
    param([hashtable] $Attributes)
    return ($Attributes.GetEnumerator() | ForEach-Object { "$($_.Key)($($_.Value))" }) -join ' '
}

#endregion

#region --- Main ---

Write-Host ""
Write-Host "=== Invoke-MQConfig ===" -ForegroundColor Cyan
Write-Host "  Queue Manager : $QueueManager"
if ($DockerContainer -ne '') {
    Write-Host "  Docker        : $DockerContainer"
}
Write-Host "  Config Files  : $($ConfigFile -join ', ')"
Write-Host "  Delete mode   : $Delete"
Write-Host "  Purge mode    : $Purge"
Write-Host "  WhatIf mode   : $WhatIf"
Write-Host ""

# --- Step 1: Load and parse all config files into desired-state map ---

# desiredState[$ObjectType][$ObjectName] = @{ KEY = VALUE; ... }
$desiredState = @{}
foreach ($type in $script:ObjectTypeMap.Keys) {
    $desiredState[$type] = @{}
}

$expandedFiles = $ConfigFile | ForEach-Object { Resolve-Path $_ -ErrorAction SilentlyContinue } | Where-Object { $_ }

if (-not $expandedFiles) {
    Write-Error "No config files found matching: $($ConfigFile -join ', ')"
    exit 1
}

foreach ($file in $expandedFiles) {
    Write-Host "  Loading: $file" -ForegroundColor DarkGray
    $lines = Get-Content -Path $file -Encoding UTF8

    foreach ($line in $lines) {
        $parsed = ConvertFrom-MQSCLine -Line $line
        if ($null -eq $parsed) { continue }

        if (-not $desiredState.ContainsKey($parsed.ObjectType)) {
            Write-MQLog 'WARN' "Unsupported object type '$($parsed.ObjectType)' - skipping: $line" Yellow
            continue
        }

        $desiredState[$parsed.ObjectType][$parsed.ObjectName] = $parsed.Attributes
    }
}

$totalDesired = ($desiredState.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
Write-Host "  Loaded $totalDesired object definition(s) from config." -ForegroundColor DarkGray
Write-Host ""

# --- Step 2: Reconcile each object type ---

foreach ($objectType in $script:ObjectTypeMap.Keys) {
    $typeDesired = $desiredState[$objectType]
    if ($typeDesired.Count -eq 0 -and -not $Delete) { continue }

    Write-Host "--- $objectType ---" -ForegroundColor Yellow

    # Create / Update
    foreach ($name in $typeDesired.Keys) {
        $desiredAttrs = $typeDesired[$name]

        $current = Get-MQObjectCurrentState -ObjectType $objectType -ObjectName $name

        $fmtName = Format-MQObjectName $name

        if ($null -eq $current) {
            # Object does not exist - CREATE
            $attrStr = ConvertTo-MQSCAttributes -Attributes $desiredAttrs
            $cmd = "DEFINE $objectType($fmtName) $attrStr"
            Write-MQLog 'CREATE' "$objectType($name)" Green

            $result = Invoke-RunmqscCommand -Commands @($cmd)
            if (-not $WhatIf) {
                if ($result -match 'AMQ\d{4}E') {
                    Write-MQLog 'ERROR' "DEFINE failed for $objectType($name): $result" Red
                    $script:CountError++
                }
                else {
                    $script:CountCreate++
                }
            }
        }
        else {
            # Object exists - check for diffs on desired attributes only
            $diff = Compare-MQAttributes -Desired $desiredAttrs -Current $current

            if ($diff.Count -gt 0) {
                $attrStr = ConvertTo-MQSCAttributes -Attributes $diff
                $cmd = "ALTER $objectType($fmtName) $attrStr"
                Write-MQLog 'UPDATE' "$objectType($name)  <- $attrStr" Cyan

                $result = Invoke-RunmqscCommand -Commands @($cmd)
                if (-not $WhatIf) {
                    if ($result -match 'AMQ\d{4}E') {
                        Write-MQLog 'ERROR' "ALTER failed for $objectType($name): $result" Red
                        $script:CountError++
                    }
                    else {
                        $script:CountUpdate++
                    }
                }
            }
            else {
                Write-MQLog 'OK' "$objectType($name)" DarkGray
                $script:CountOk++
            }
        }
    }

    # Delete objects not in config
    if ($Delete) {
        $allOnQM = Get-AllMQObjectNames -ObjectType $objectType
        foreach ($name in $allOnQM) {
            if ($typeDesired.ContainsKey($name)) { continue }

            if ($SkipSystemObjects -and ($name -match '^SYSTEM\.' -or $name -match '^AMQ\.')) {
                Write-Verbose "  Skipping system object: $objectType($name)"
                continue
            }

            $fmtName = Format-MQObjectName $name
            $isQueueType = $objectType -match '^Q'
            $purgeSuffix = if ($Purge -and $isQueueType) { ' PURGE' } else { '' }

            Write-MQLog 'DELETE' "$objectType($name)$purgeSuffix" Magenta
            $cmd = "DELETE $objectType($fmtName)$purgeSuffix"
            $result = Invoke-RunmqscCommand -Commands @($cmd)
            if (-not $WhatIf) {
                if ($result -match 'AMQ\d{4}E') {
                    Write-MQLog 'ERROR' "DELETE failed for $objectType($name): $result" Red
                    $script:CountError++
                }
                else {
                    $script:CountDelete++
                }
            }
        }
    }
}

# --- Step 3: Summary ---

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "  (WhatIf mode - no changes were made)" -ForegroundColor DarkCyan
}
else {
    Write-Host "  Created  : $($script:CountCreate)" -ForegroundColor Green
    Write-Host "  Updated  : $($script:CountUpdate)" -ForegroundColor Cyan
    Write-Host "  Deleted  : $($script:CountDelete)" -ForegroundColor Magenta
    Write-Host "  OK       : $($script:CountOk)"     -ForegroundColor DarkGray
    if ($script:CountError -gt 0) {
        Write-Host "  Errors   : $($script:CountError)" -ForegroundColor Red
    }
}
Write-Host ""

#endregion
