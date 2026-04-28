#requires -version 5
<#
.SYNOPSIS
  Library function: remove ACE/MQ-related variables from MACHINE-scope (or current
  PROCESS, for testing) environment.

.DESCRIPTION
  Dot-source this file to load the Cleanup-AceMqEnv function, then call it.
  PowerShell 5.1 compatible.

  Scopes:
    -Apply         : apply the cleanup to the CURRENT PROCESS (current PS session)
                     so changes can be tested without persisting.
    -ApplyMachine  : apply the cleanup to MACHINE scope (persisted system-wide).
    (neither)      : SIMULATE only; report what would change at MACHINE scope.
    (both)         : apply to PROCESS and MACHINE independently.

  What it does (per selected scope):
    1) DELETE every variable whose name matches: ^(MQ|WMQ|ACE|MQSI)_
    2) DELETE the version-pinned scalars: TOOLS_FILEPATH, PROSPECTIVE_MQSI_FILEPATH
    3) CLEAN list-valued variables (Path, CLASSPATH, INCLUDE, LIB, MIBDIRS,
       _NT_SYMBOL_PATH) by dropping entries that contain any of:
         \ibm\ACE\
         \IBM\MQSI\
         \ProgramData\IBM\MQSI\
         IBM\WebSphere MQ\
       After dropping, entries are de-duped (case-insensitive, order-preserved).

  Untouched: JAVA_HOME, JAVA_HOME_17, and anything else.

  PATH note:
    After cleanup, PATH no longer contains a JRE bin entry. Re-establishing a
    Java reference on PATH is the responsibility of Persist-AceJavaEnv, which
    prepends <JavaHomePath>\bin. Run Persist-AceJavaEnv after Cleanup-AceMqEnv.

.NOTES
    Version:        1.1
    Author:         Matthias Blomme
    Creation Date:  2026-04-27
    Purpose/Change: Initial script development; added -Apply (PROCESS) / -ApplyMachine.
#>

function Cleanup-AceMqEnv {
    <#
    .SYNOPSIS
      Remove ACE/MQ-related variables from PROCESS and/or MACHINE environment.

    .PARAMETER Apply
      Apply the cleanup to the CURRENT PROCESS (current PS session). Useful for
      testing the effect before persisting.

    .PARAMETER ApplyMachine
      Apply the cleanup to MACHINE scope (persisted system-wide).

    .PARAMETER OutDir
      Snapshot directory (default: a new temp folder).

    .PARAMETER VerboseDump
      If specified, prints full env dumps to console in addition to files.

    .EXAMPLE
      # Simulate only (default)
      Cleanup-AceMqEnv

    .EXAMPLE
      # Apply to current session only - safe to test
      Cleanup-AceMqEnv -Apply

    .EXAMPLE
      # Persist at MACHINE scope
      Cleanup-AceMqEnv -ApplyMachine

    .EXAMPLE
      # Both
      Cleanup-AceMqEnv -Apply -ApplyMachine
    #>

    [CmdletBinding()]
    param(
        [switch]$Apply,

        [switch]$ApplyMachine,

        [string]$OutDir = (Join-Path $env:TEMP ("AceEnvCleanup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))),

        [switch]$VerboseDump
    )

    Set-StrictMode -Version 2
    $ErrorActionPreference = 'Stop'

    $NameRegex = '^(MQ|WMQ|ACE|MQSI)_'
    $ScalarsToDelete = @('TOOLS_FILEPATH','PROSPECTIVE_MQSI_FILEPATH')
    $ListVarsToClean = @('Path','CLASSPATH','INCLUDE','LIB','MIBDIRS','_NT_SYMBOL_PATH')
    $AceMqPatterns   = @('\ibm\ACE\','\IBM\MQSI\','\ProgramData\IBM\MQSI\','IBM\WebSphere MQ\')

    function Write-Info([string]$m) { Write-Host ("[INFO]  {0}" -f $m) }
    function Write-Warn([string]$m) { Write-Host ("[WARN]  {0}" -f $m) -ForegroundColor Yellow }

    function Ensure-Dir([string]$p) {
        if(-not (Test-Path -LiteralPath $p)) {
            New-Item -ItemType Directory -Path $p | Out-Null
        }
    }

    function Get-ScopedEnv([string]$scope) {
        $h = @{}
        if($scope -eq 'Process') {
            Get-ChildItem Env: | ForEach-Object { $h[[string]$_.Name] = [string]$_.Value }
        } else {
            $raw = [Environment]::GetEnvironmentVariables('Machine')
            foreach($k in $raw.Keys) { $h[[string]$k] = [string]$raw[$k] }
        }
        return $h
    }

    function Export-EnvToFile([hashtable]$envDict, [string]$filePath) {
        $envDict.Keys | Sort-Object | ForEach-Object { "{0}={1}" -f $_, $envDict[$_] } |
                Set-Content -Path $filePath -Encoding UTF8
    }

    function Is-AceMqPathEntry([string]$entry) {
        if([string]::IsNullOrWhiteSpace($entry)) { return $false }
        foreach($p in $AceMqPatterns) {
            if($entry -match [Regex]::Escape($p)) { return $true }
        }
        return $false
    }

    function Clean-ListValue([string]$value) {
        if([string]::IsNullOrEmpty($value)) { return @{ NewValue = $value; Dropped = @() } }

        $items = $value -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

        $dropped = New-Object System.Collections.Generic.List[string]
        $kept    = New-Object System.Collections.Generic.List[string]
        foreach($it in $items) {
            if(Is-AceMqPathEntry $it) {
                $dropped.Add($it) | Out-Null
            } else {
                $kept.Add($it) | Out-Null
            }
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

        return @{ NewValue = ($dedup -join ';'); Dropped = @($dropped) }
    }

    function Build-Plan([hashtable]$envDict) {
        $names = New-Object System.Collections.Generic.List[string]
        foreach($k in $envDict.Keys) {
            if($k -match $NameRegex) { $names.Add($k) | Out-Null }
        }
        foreach($s in $ScalarsToDelete) {
            if($envDict.ContainsKey($s)) { $names.Add($s) | Out-Null }
        }
        $namesArr = @($names | Sort-Object -Unique)

        $listChanges = @{}
        foreach($lv in $ListVarsToClean) {
            if(-not $envDict.ContainsKey($lv)) { continue }
            $before = [string]$envDict[$lv]
            $r = Clean-ListValue $before
            $after = [string]$r.NewValue
            if($before -ne $after) {
                $listChanges[$lv] = @{ Before = $before; After = $after; Dropped = @($r.Dropped) }
            }
        }

        # Safety: never empty Path
        if($listChanges.ContainsKey('Path') -and [string]::IsNullOrWhiteSpace([string]$listChanges['Path'].After)) {
            Write-Warn "Cleaning would empty Path. Aborting Path change to avoid breaking the system."
            $listChanges.Remove('Path') | Out-Null
        }

        return @{ Names = @($namesArr); ListChanges = $listChanges }
    }

    function Report-Plan([string]$scopeLabel, [hashtable]$envDict, [hashtable]$plan) {
        Write-Host "`n===== PLANNED ACTIONS at $scopeLabel scope ====="

        Write-Info ("Variables to DELETE: {0}" -f (@($plan.Names).Count))
        foreach($n in @($plan.Names)) {
            $v = if($envDict.ContainsKey($n)) { [string]$envDict[$n] } else { '' }
            Write-Host ("  - DELETE {0}={1}" -f $n, $v)
        }

        Write-Info ("List-vars to CLEAN: {0}" -f $plan.ListChanges.Keys.Count)
        foreach($lv in ($plan.ListChanges.Keys | Sort-Object)) {
            $c = $plan.ListChanges[$lv]
            Write-Host "`n--- $lv ---"
            Write-Host ("BEFORE: {0}" -f $c.Before)
            Write-Host ("AFTER : {0}" -f $c.After)
            if((@($c.Dropped)).Count -gt 0) {
                Write-Host "Dropped entries:"
                foreach($d in @($c.Dropped)) { Write-Host ("  - {0}" -f $d) }
            }
        }
    }

    function Apply-Plan([hashtable]$plan, [string]$scope) {
        foreach($n in @($plan.Names)) {
            [Environment]::SetEnvironmentVariable($n, $null, $scope)
            Write-Info ("Deleted {0} var: {1}" -f $scope.ToUpper(), $n)
        }
        foreach($lv in ($plan.ListChanges.Keys | Sort-Object)) {
            $newVal = [string]$plan.ListChanges[$lv].After
            [Environment]::SetEnvironmentVariable($lv, $newVal, $scope)
            Write-Info ("Updated {0} var: {1}" -f $scope.ToUpper(), $lv)
        }
    }

    # ---------------- MAIN ----------------

    $doProcess = [bool]$Apply
    $doMachine = [bool]$ApplyMachine
    $simulate  = -not ($doProcess -or $doMachine)

    $mode = if($doProcess -and $doMachine) { "APPLY (PROCESS+MACHINE)" }
            elseif($doMachine) { "APPLY (MACHINE)" }
            elseif($doProcess) { "APPLY (PROCESS)" }
            else { "SIMULATE (MACHINE)" }

    Write-Info "Mode            : $mode"
    Write-Info "OutDir          : $OutDir"
    Ensure-Dir $OutDir

    # MACHINE plan: built whenever MACHINE is involved (SIMULATE or -ApplyMachine).
    $envM = $null; $planM = $null
    if($simulate -or $doMachine) {
        $envM = Get-ScopedEnv 'Machine'
        Export-EnvToFile $envM (Join-Path $OutDir "machine-env-before.txt")
        Write-Info "Machine env (before) exported to: $OutDir\machine-env-before.txt"
        if($VerboseDump) {
            Write-Host "`n===== MACHINE ENV (BEFORE, FULL) ====="
            $envM.Keys | Sort-Object | ForEach-Object { "{0}={1}" -f $_, $envM[$_] }
        }
        $planM = Build-Plan $envM
        Report-Plan 'MACHINE' $envM $planM
    }

    # PROCESS plan: only when -Apply is set.
    $envP = $null; $planP = $null
    if($doProcess) {
        $envP = Get-ScopedEnv 'Process'
        Export-EnvToFile $envP (Join-Path $OutDir "process-env-before.txt")
        Write-Info "Process env (before) exported to: $OutDir\process-env-before.txt"
        if($VerboseDump) {
            Write-Host "`n===== PROCESS ENV (BEFORE, FULL) ====="
            $envP.Keys | Sort-Object | ForEach-Object { "{0}={1}" -f $_, $envP[$_] }
        }
        $planP = Build-Plan $envP
        Report-Plan 'PROCESS' $envP $planP
    }

    if($simulate) {
        Write-Host "`n[SIMULATE] No changes were made."
        return
    }

    # ---------------- Apply ----------------

    if($doMachine) {
        Write-Host "`n===== APPLYING at MACHINE scope ====="
        Apply-Plan $planM 'Machine'
        $envMAfter = Get-ScopedEnv 'Machine'
        Export-EnvToFile $envMAfter (Join-Path $OutDir "machine-env-after.txt")
        Write-Info "Machine env (after) exported to: $OutDir\machine-env-after.txt"
    }

    if($doProcess) {
        Write-Host "`n===== APPLYING at PROCESS scope (current session) ====="
        Apply-Plan $planP 'Process'
        $envPAfter = Get-ScopedEnv 'Process'
        Export-EnvToFile $envPAfter (Join-Path $OutDir "process-env-after.txt")
        Write-Info "Process env (after) exported to: $OutDir\process-env-after.txt"
    }

    Write-Info "Cleanup complete."
    if($doMachine) {
        Write-Warn "Existing services/processes typically need restart to pick up updated MACHINE environment variables."
        Write-Warn "Reminder: run Persist-AceJavaEnv next to set JAVA_HOME / JAVA_HOME_17 and restore a JRE bin entry on PATH."
    }
}
