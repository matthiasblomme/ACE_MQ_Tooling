<#
.SYNOPSIS
  Switch default ACE environment (machine-level) by running a NEW mqsiprofile.cmd under a cleaned baseline env,
  then persisting the resulting env vars at MACHINE scope.

.DESCRIPTION
  PowerShell 5.1 compatible.

  Baseline:
    - Uses current process environment (Env:) as the baseline (no registry reads).

  Cleaning (for profiling only):
    1) REMOVE from the child env:
         Names matching: ^(MQ|WMQ|ACE|MQSI)_
    2) CLEAN values that contain the OLD version marker (e.g. 12.0.12.17):
         - If value is PATH-like (semicolon-separated): remove entries containing OldVersion
         - Else (scalar): blank it

  Profiling:
    - Runs: cmd.exe /d /c "call "<AceProfile>" & set"
      with the cleaned environment and captures "set" output.

  Persisting (MACHINE scope) - selection rules:
    - SET all vars whose names match: ^(MQ|WMQ|ACE|MQSI)_ exactly as produced by mqsiprofile
    - SET any var whose ORIGINAL (process) value referenced OldVersion (scalar or list), using post-profile value
      (e.g., TOOLS_FILEPATH, PROSPECTIVE_MQSI_FILEPATH, CLASSPATH, etc.)
    - SET Path as produced by mqsiprofile (optional -Normalize de-dupes)
    - SET JAVA_HOME derived from MQSI_JREPATH (removing trailing "\jre" or "/jre")

  Deletions:
    - Default: NO deletions at machine scope; extra vars are reported only.
    - Optional: -DeleteExtraVars deletes extra name-matched vars at MACHINE scope (those present originally but absent in desired set).

.PARAMETER AceProfile
  Full path to the NEW install mqsiprofile.cmd (e.g. ...\12.0.12.18\server\bin\mqsiprofile.cmd)

.PARAMETER OldVersion
  Old ACE version marker used to remove old path/value contamination (e.g. 12.0.12.17)

.PARAMETER Apply
  If specified, writes the planned changes to MACHINE environment variables.
  Otherwise SIMULATE only (default).

.PARAMETER Normalize
  If specified, normalizes the final desired Path by de-duping entries (case-insensitive),
  trimming whitespace, removing empty entries, and removing trailing semicolons. Order is preserved.

.PARAMETER DeleteExtraVars
  If specified (meaningful with -Apply), deletes name-matched variables (^(MQ|WMQ|ACE|MQSI)_)
  from MACHINE scope when they exist in the current env but are absent from the post-profile desired set.

.PARAMETER OutDir
  Export directory (default: a new temp folder)

.PARAMETER VerboseDump
  If specified, prints the full env dumps to console in addition to files.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path -LiteralPath $_ })]
    [string]$AceProfile,

    [Parameter(Mandatory=$true)]
    [string]$OldVersion,

    [switch]$Apply,

    [switch]$Normalize,

    [switch]$DeleteExtraVars,

    [string]$OutDir = (Join-Path $env:TEMP ("AceEnvSwitch_" + (Get-Date -Format "yyyyMMdd_HHmmss"))),

    [switch]$VerboseDump
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

$NameRegex = '^(MQ|WMQ|ACE|MQSI)_'

function Write-Info([string]$m) { Write-Host ("[INFO]  {0}" -f $m) }
function Write-Warn([string]$m) { Write-Host ("[WARN]  {0}" -f $m) -ForegroundColor Yellow }

function Ensure-Dir([string]$p) {
    if(-not (Test-Path -LiteralPath $p)) {
        New-Item -ItemType Directory -Path $p | Out-Null
    }
}

function Get-ProcessEnv {
    $h = @{}
    Get-ChildItem Env: | ForEach-Object { $h[$_.Name] = [string]$_.Value }
    return $h
}

function Export-EnvToFile([hashtable]$envDict, [string]$filePath) {
    $envDict.Keys | Sort-Object | ForEach-Object { "{0}={1}" -f $_, $envDict[$_] } |
            Set-Content -Path $filePath -Encoding UTF8
}

function Is-ListVarValue([string]$value) {
    if([string]::IsNullOrWhiteSpace($value)) { return $false }
    return ($value -like '*;*') -and (($value -like '*\*') -or ($value -like '*:*'))
}

function Value-ContainsOldVersion([string]$value, [string]$oldVersionLiteral) {
    if([string]::IsNullOrWhiteSpace($value)) { return $false }
    return ($value -match "(?i)$([Regex]::Escape($oldVersionLiteral))")
}

function Clean-ListValue([string]$value, [string]$oldVersionLiteral) {
    if([string]::IsNullOrEmpty($value)) { return $value }

    $items = $value -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    $kept = New-Object System.Collections.Generic.List[string]
    foreach($it in $items) {
        if($it -match "(?i)$([Regex]::Escape($oldVersionLiteral))") { continue }
        $kept.Add($it) | Out-Null
    }

    # De-dupe (case-insensitive) preserving order
    $seen = @{}
    $dedup = New-Object System.Collections.Generic.List[string]
    foreach($k in $kept) {
        $key = $k.ToLowerInvariant()
        if(-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $dedup.Add($k) | Out-Null
        }
    }

    return ($dedup -join ';')
}

function Normalize-PathValue([string]$pathValue) {
    if([string]::IsNullOrWhiteSpace($pathValue)) { return $pathValue }

    $items = $pathValue -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

    $seen = @{}
    $out = New-Object System.Collections.Generic.List[string]
    foreach($it in $items) {
        $key = $it.ToLowerInvariant()
        if(-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $out.Add($it) | Out-Null
        }
    }
    return ($out -join ';')
}

function Clean-EnvForProfiling([hashtable]$baseEnv, [string]$oldVersionLiteral) {
    $clean = @{}

    foreach($k in $baseEnv.Keys) {
        $v = $baseEnv[$k]

        # 1) Drop all name-matched vars (profiling only)
        if($k -match $NameRegex) { continue }

        # 2) Only clean values that reference the OLD version marker
        if(Value-ContainsOldVersion -value $v -oldVersionLiteral $oldVersionLiteral) {
            if(Is-ListVarValue $v) {
                $clean[$k] = (Clean-ListValue -value $v -oldVersionLiteral $oldVersionLiteral)
            } else {
                $clean[$k] = ''
            }
            continue
        }

        $clean[$k] = $v
    }

    return $clean
}

function Run-CmdWithEnvAndProfile {
    param(
        [Parameter(Mandatory=$true)][hashtable]$EnvMap,
        [Parameter(Mandatory=$true)][string]$AceProfilePath
    )

    if (-not (Test-Path -LiteralPath $AceProfilePath)) {
        throw "AceProfile file not found: $AceProfilePath"
    }

    $cmdBody = 'call "{0}" & set' -f $AceProfilePath
    $cmdArgs = '/d /c "{0}"' -f $cmdBody

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $env:ComSpec
    $psi.Arguments = $cmdArgs
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow = $true

    $psi.Environment.Clear()
    foreach ($k in $EnvMap.Keys) {
        $psi.Environment[$k] = [string]$EnvMap[$k]
    }

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($p.ExitCode -ne 0) {
        throw "Failed to run profile. ExitCode=$($p.ExitCode). Error: $stderr"
    }

    $result = @{}
    foreach ($line in ($stdout -split "(`r`n|`n|`r)")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $idx = $line.IndexOf('=')
        if ($idx -gt 0) {
            $k = $line.Substring(0, $idx)
            $v = $line.Substring($idx + 1)
            if ($k) { $result[$k] = $v }
        }
    }

    return $result
}

function Derive-JavaHomeFromMqsiJrePath([hashtable]$envDict) {
    if(-not $envDict.ContainsKey('MQSI_JREPATH')) { return $null }
    $p = [string]$envDict['MQSI_JREPATH']
    if([string]::IsNullOrWhiteSpace($p)) { return $null }
    return ($p -replace '(?i)[\\/]+jre[\\/]*$','')
}

function Get-EnvDiff {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Before,
        [Parameter(Mandatory=$true)][hashtable]$After,
        [Parameter(Mandatory=$true)][string[]]$Keys
    )

    $out = @()
    foreach($k in ($Keys | Sort-Object -Unique)) {
        $b = if($Before.ContainsKey($k)) { [string]$Before[$k] } else { $null }
        $a = if($After.ContainsKey($k))  { [string]$After[$k] }  else { $null }
        if($b -ne $a) {
            $out += [PSCustomObject]@{ Name=$k; Before=$b; After=$a }
        }
    }
    return $out
}

# ---------------- MAIN ----------------

$mode = if($Apply) { "APPLY" } else { "SIMULATE" }

Write-Info "AceProfile      : $AceProfile"
Write-Info "OldVersion      : $OldVersion"
Write-Info "Mode            : $mode"
Write-Info "OutDir          : $OutDir"
Write-Info ("Normalize Path  : {0}" -f ($(if($Normalize) { "YES" } else { "NO" })))
Write-Info ("DeleteExtraVars : {0}" -f ($(if($DeleteExtraVars) { "YES" } else { "NO" })))

Ensure-Dir $OutDir

$orig = Get-ProcessEnv
$origFile = Join-Path $OutDir "env-original-process.txt"
Export-EnvToFile $orig $origFile
Write-Info "Original process env exported to: $origFile"

$clean = Clean-EnvForProfiling -baseEnv $orig -oldVersionLiteral $OldVersion
$cleanFile = Join-Path $OutDir "env-cleaned-for-profile.txt"
Export-EnvToFile $clean $cleanFile
Write-Info "Cleaned env for profiling exported to: $cleanFile"

$after = Run-CmdWithEnvAndProfile -EnvMap $clean -AceProfilePath $AceProfile
$afterFile = Join-Path $OutDir "env-after-mqsiprofile.txt"
Export-EnvToFile $after $afterFile
Write-Info "Env after mqsiprofile exported to: $afterFile"

if($VerboseDump) {
    Write-Host "`n===== ORIGINAL (PROCESS) ENV (FULL) ====="
    $orig.Keys | Sort-Object | ForEach-Object { "{0}={1}" -f $_, $orig[$_] }

    Write-Host "`n===== CLEANED ENV FOR PROFILE (FULL) ====="
    $clean.Keys | Sort-Object | ForEach-Object { "{0}={1}" -f $_, $clean[$_] }

    Write-Host "`n===== AFTER MQSIPROFILE (FULL) ====="
    $after.Keys | Sort-Object | ForEach-Object { "{0}={1}" -f $_, $after[$_] }
}
else {
    Write-Info "Full env dumps are in files under: $OutDir (use -VerboseDump to print them)."
}

# ---------------- Build desired MACHINE updates ----------------

$desired = @{}

# A) Name-matched vars from post-profile env (authoritative)
foreach($k in $after.Keys) {
    if($k -match $NameRegex) {
        $desired[$k] = [string]$after[$k]
    }
}

# B) Any var whose ORIGINAL value referenced OldVersion -> set it from post-profile env (if present)
$oldValueMatchedKeys = @()
foreach($k in $orig.Keys) {
    $v = [string]$orig[$k]
    if(Value-ContainsOldVersion -value $v -oldVersionLiteral $OldVersion) {
        $oldValueMatchedKeys += $k
        if($after.ContainsKey($k)) {
            $desired[$k] = [string]$after[$k]
        }
    }
}
# Force array, even if single item / null
$oldValueMatchedKeys = @($oldValueMatchedKeys | Sort-Object -Unique)

# C) Path exactly as produced by post-profile env (ensure we always carry it)
if($after.ContainsKey('Path')) {
    $desired['Path'] = [string]$after['Path']
} elseif($after.ContainsKey('PATH')) {
    $desired['Path'] = [string]$after['PATH']
} else {
    Write-Warn "No Path found in post-profile environment; Path will not be set."
}

if($Normalize -and $desired.ContainsKey('Path')) {
    $desired['Path'] = Normalize-PathValue -pathValue ([string]$desired['Path'])
}

# D) JAVA_HOME forced from MQSI_JREPATH (explicit requirement override)
$javaHome = Derive-JavaHomeFromMqsiJrePath -envDict $after
if($javaHome) {
    $desired['JAVA_HOME'] = $javaHome
} else {
    Write-Warn "MQSI_JREPATH missing/empty after profiling; JAVA_HOME will not be set."
}

# Extra vars candidate list (name-matched but absent in desired set)
$extraVars = @()
foreach($k in $orig.Keys) {
    if($k -match $NameRegex -and -not $desired.ContainsKey($k)) { $extraVars += $k }
}
$extraVars = @($extraVars | Sort-Object -Unique)

# Diff for review
$changes = @(
    Get-EnvDiff -Before $orig -After $desired -Keys ($desired.Keys)
)

# Sanity: warn if OldVersion is still present in desired Path
if($desired.ContainsKey('Path') -and -not [string]::IsNullOrWhiteSpace([string]$desired['Path'])) {
    if([string]$desired['Path'] -match "(?i)$([Regex]::Escape($OldVersion))") {
        Write-Warn "Post-profile Path still contains OldVersion marker '$OldVersion'. Review env-cleaning rules / short-path variants."
    }
}

if($DeleteExtraVars) {
    if(-not $Apply) {
        Write-Warn "-DeleteExtraVars specified, but Mode=SIMULATE. No machine deletions will occur."
    } else {
        Write-Warn "-DeleteExtraVars is ENABLED. Matching extra vars WILL be deleted at MACHINE scope during APPLY."
    }
} else {
    Write-Warn "Machine-scope variables will NOT be auto-deleted. This script only SETs/UPDATES variables."
}

Write-Host "`n===== PLANNED ACTIONS ($mode) ====="
Write-Info ("Normalize Path: {0}" -f ($(if($Normalize) { "ENABLED" } else { "DISABLED" })))

Write-Info ("OldVersion value-matched variables (origin contained {0}): {1}" -f $OldVersion, (@($oldValueMatchedKeys).Count))
if((@($oldValueMatchedKeys).Count) -gt 0) {
    foreach($k in @($oldValueMatchedKeys)) {
        $v = [string]$orig[$k]
        Write-Host ("  - {0}={1}" -f $k, $v)
    }
}

Write-Info ("Extra vars (name-matched but absent in post-profile env): {0}" -f (@($extraVars).Count))
if((@($extraVars).Count) -gt 0) {
    foreach($k in @($extraVars)) {
        $v = if($orig.ContainsKey($k)) { [string]$orig[$k] } else { '' }
        Write-Host ("  - {0}={1}" -f $k, $v)
    }

    $extraFileName = if($DeleteExtraVars) { "would-delete-to-delete.txt" } else { "would-delete-not-deleted.txt" }
    $extraFile = Join-Path $OutDir $extraFileName
    @($extraVars) | ForEach-Object { "{0}={1}" -f $_, $orig[$_] } | Set-Content -Path $extraFile -Encoding UTF8
    Write-Info "Extra vars list exported to: $extraFile"
}

Write-Info ("Variables to set/update at MACHINE scope: {0}" -f ($desired.Keys.Count))

foreach($c in (@($changes) | Sort-Object Name)) {
    Write-Host "`n--- $($c.Name) ---"
    Write-Host "BEFORE (process): $($c.Before)"
    Write-Host "AFTER  (desired): $($c.After)"
}

if(-not $Apply) {
    Write-Host "`n[SIMULATE] No machine-level changes were made."
    exit 0
}

Write-Host "`n===== APPLYING MACHINE-LEVEL CHANGES ====="

# 1) Set/update (machine)
foreach($k in $desired.Keys) {
    [Environment]::SetEnvironmentVariable($k, [string]$desired[$k], 'Machine')
}

# 2) Optional delete (machine) for extra vars
if($DeleteExtraVars -and (@($extraVars).Count -gt 0)) {
    Write-Host "`n===== DELETING EXTRA MACHINE-LEVEL VARS (ENABLED) ====="
    foreach($k in @($extraVars)) {
        [Environment]::SetEnvironmentVariable($k, $null, 'Machine')
        Write-Info ("Deleted MACHINE var: {0}" -f $k)
    }
}

Write-Info "Machine environment updated."
Write-Info "Snapshots available in: $OutDir"
Write-Warn "Note: existing services/processes typically need restart to pick up updated MACHINE environment variables."
