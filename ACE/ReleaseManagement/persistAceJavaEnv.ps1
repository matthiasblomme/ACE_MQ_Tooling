#requires -version 5
<#
.SYNOPSIS
  Library function: persist JAVA_HOME (jre8) and JAVA_HOME_17 (jre17), and ensure
  <JavaHomePath>\bin is on PATH so `java` resolves system-wide. Targets MACHINE
  scope (persisted) or current PROCESS scope (for testing).

.DESCRIPTION
  Dot-source this file to load the Persist-AceJavaEnv function, then call it.
  PowerShell 5.1 compatible.

  Scopes:
    -Apply         : apply to the CURRENT PROCESS (current PS session) so changes
                     can be tested without persisting.
    -ApplyMachine  : apply to MACHINE scope (persisted system-wide).
    (neither)      : SIMULATE only; report what would change at MACHINE scope.
    (both)         : apply to PROCESS and MACHINE independently.

  Per selected scope:
    - SET JAVA_HOME    = <JavaHomePath>     (jre8 jdk; default for older Java tools)
    - SET JAVA_HOME_17 = <JavaHome17Path>   (jre17 jdk; for tools that opt in)
    - PREPEND <JavaHomePath>\bin to that scope's PATH if not already present
      (unless -SkipPathUpdate)

  Does NOT touch CLASSPATH. A JRE does not need to be on CLASSPATH; the JVM
  resolves its own runtime classes relative to java.exe.

.NOTES
    Version:        1.1
    Author:         Matthias Blomme
    Creation Date:  2026-04-27
    Purpose/Change: Initial script development; added -Apply (PROCESS) / -ApplyMachine.
#>

function Persist-AceJavaEnv {
    <#
    .SYNOPSIS
      Persist JAVA_HOME / JAVA_HOME_17 and add jre8 bin to PATH (PROCESS or MACHINE).

    .PARAMETER JavaHomePath
      Full path to the jre8 jdk (e.g. C:\Program Files\ibm\ACE\12.0.12.19\common\jdk).
      This becomes JAVA_HOME and its \bin is prepended to PATH.

    .PARAMETER JavaHome17Path
      Full path to the jre17 jdk (e.g. C:\Program Files\ibm\ACE\13.0.7.0\common\java17).
      This becomes JAVA_HOME_17.

    .PARAMETER Apply
      Apply to the CURRENT PROCESS (current PS session). Useful for testing.

    .PARAMETER ApplyMachine
      Apply to MACHINE scope (persisted system-wide).

    .PARAMETER SkipPathUpdate
      If specified, do NOT modify PATH. JAVA_HOME / JAVA_HOME_17 are still set.

    .PARAMETER OutDir
      Snapshot directory (default: a new temp folder).

    .EXAMPLE
      # Simulate
      Persist-AceJavaEnv -JavaHomePath  "C:\Program Files\ibm\ACE\12.0.12.19\common\jdk" `
                         -JavaHome17Path "C:\Program Files\ibm\ACE\13.0.7.0\common\java17"

    .EXAMPLE
      # Test in current session only
      Persist-AceJavaEnv -JavaHomePath  "..." -JavaHome17Path "..." -Apply

    .EXAMPLE
      # Persist
      Persist-AceJavaEnv -JavaHomePath  "..." -JavaHome17Path "..." -ApplyMachine
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path -LiteralPath $_ })]
        [string]$JavaHomePath,

        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path -LiteralPath $_ })]
        [string]$JavaHome17Path,

        [switch]$Apply,

        [switch]$ApplyMachine,

        [switch]$SkipPathUpdate,

        [string]$OutDir = (Join-Path $env:TEMP ("AceJavaEnv_" + (Get-Date -Format "yyyyMMdd_HHmmss")))
    )

    Set-StrictMode -Version 2
    $ErrorActionPreference = 'Stop'

    function Write-Info([string]$m) { Write-Host ("[INFO]  {0}" -f $m) }
    function Write-Warn([string]$m) { Write-Host ("[WARN]  {0}" -f $m) -ForegroundColor Yellow }

    function Ensure-Dir([string]$p) {
        if(-not (Test-Path -LiteralPath $p)) {
            New-Item -ItemType Directory -Path $p | Out-Null
        }
    }

    function Get-JavaMajorVersion([string]$javaHome) {
        $exe = Join-Path $javaHome 'bin\java.exe'
        if(-not (Test-Path -LiteralPath $exe)) { return $null }
        try {
            $out = & $exe -version 2>&1 | Out-String
        } catch {
            return $null
        }
        if($out -match 'version\s+"(?<v>[^"]+)"') {
            $v = $Matches['v']
            if($v -match '^1\.(?<m>\d+)\.') { return [int]$Matches['m'] }       # 1.8 -> 8
            if($v -match '^(?<m>\d+)(\.|$)') { return [int]$Matches['m'] }       # 17.0.x -> 17
        }
        return $null
    }

    function Path-Has-Entry([string]$pathValue, [string]$entry) {
        if([string]::IsNullOrWhiteSpace($pathValue)) { return $false }
        $target = $entry.TrimEnd('\').ToLowerInvariant()
        foreach($e in ($pathValue -split ';')) {
            $candidate = $e.Trim().TrimEnd('\').ToLowerInvariant()
            if($candidate -eq $target) { return $true }
        }
        return $false
    }

    function Get-ScopedPath([string]$scope) {
        if($scope -eq 'Process') { return [string]$env:Path }
        else { return [string][Environment]::GetEnvironmentVariable('Path', 'Machine') }
    }

    function Get-ScopedVar([string]$name, [string]$scope) {
        if($scope -eq 'Process') {
            $v = Get-Item -LiteralPath ("Env:{0}" -f $name) -ErrorAction SilentlyContinue
            if($v) { return [string]$v.Value } else { return $null }
        } else {
            return [string][Environment]::GetEnvironmentVariable($name, 'Machine')
        }
    }

    function Plan-PathFor([string]$scope, [string]$java8BinDir) {
        $cur = Get-ScopedPath $scope
        if($SkipPathUpdate) { return @{ Before=$cur; After=$cur; Changed=$false } }
        if(Path-Has-Entry $cur $java8BinDir) {
            return @{ Before=$cur; After=$cur; Changed=$false }
        }
        $new = if([string]::IsNullOrWhiteSpace($cur)) { $java8BinDir } else { "$java8BinDir;$cur" }
        return @{ Before=$cur; After=$new; Changed=$true }
    }

    function Report-Scope([string]$scopeLabel, [string]$scope, [string]$java8BinDir) {
        $curJH   = Get-ScopedVar 'JAVA_HOME'    $scope
        $curJH17 = Get-ScopedVar 'JAVA_HOME_17' $scope
        $pathPlan = Plan-PathFor $scope $java8BinDir

        Write-Host "`n===== PLANNED ACTIONS at $scopeLabel scope ====="
        Write-Host "`n--- JAVA_HOME ---"
        Write-Host ("BEFORE: {0}" -f $curJH)
        Write-Host ("AFTER : {0}" -f $JavaHomePath)

        Write-Host "`n--- JAVA_HOME_17 ---"
        Write-Host ("BEFORE: {0}" -f $curJH17)
        Write-Host ("AFTER : {0}" -f $JavaHome17Path)

        Write-Host "`n--- Path ---"
        if($SkipPathUpdate) {
            Write-Info "SkipPathUpdate=YES; PATH will not be modified."
            Write-Host ("UNCHANGED: {0}" -f $pathPlan.Before)
        } elseif($pathPlan.Changed) {
            Write-Host ("BEFORE: {0}" -f $pathPlan.Before)
            Write-Host ("AFTER : {0}" -f $pathPlan.After)
            Write-Info ("Prepending entry: {0}" -f $java8BinDir)
        } else {
            Write-Info ("PATH already contains '{0}'; no change." -f $java8BinDir)
            Write-Host ("UNCHANGED: {0}" -f $pathPlan.Before)
        }
        return $pathPlan
    }

    function Apply-Scope([string]$scope, [hashtable]$pathPlan) {
        [Environment]::SetEnvironmentVariable('JAVA_HOME',    $JavaHomePath,   $scope)
        Write-Info ("Set {0} JAVA_HOME"    -f $scope.ToUpper())
        [Environment]::SetEnvironmentVariable('JAVA_HOME_17', $JavaHome17Path, $scope)
        Write-Info ("Set {0} JAVA_HOME_17" -f $scope.ToUpper())
        if((-not $SkipPathUpdate) -and $pathPlan.Changed) {
            [Environment]::SetEnvironmentVariable('Path', [string]$pathPlan.After, $scope)
            Write-Info ("Updated {0} Path (prepended jre8 bin)" -f $scope.ToUpper())
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
    Write-Info "JavaHomePath    : $JavaHomePath"
    Write-Info "JavaHome17Path  : $JavaHome17Path"
    Write-Info ("SkipPathUpdate  : {0}" -f ($(if($SkipPathUpdate) { "YES" } else { "NO" })))
    Write-Info "OutDir          : $OutDir"

    Ensure-Dir $OutDir

    # Sanity checks
    $java8Bin    = Join-Path $JavaHomePath   'bin\java.exe'
    $java17Bin   = Join-Path $JavaHome17Path 'bin\java.exe'
    $java8BinDir = (Join-Path $JavaHomePath  'bin').TrimEnd('\')

    if(-not (Test-Path -LiteralPath $java8Bin))  { Write-Warn "JavaHomePath has no bin\java.exe: $java8Bin" }
    if(-not (Test-Path -LiteralPath $java17Bin)) { Write-Warn "JavaHome17Path has no bin\java.exe: $java17Bin" }

    $resolvedHome   = (Resolve-Path -LiteralPath $JavaHomePath).Path.TrimEnd('\')
    $resolved17Home = (Resolve-Path -LiteralPath $JavaHome17Path).Path.TrimEnd('\')
    if($resolvedHome.ToLowerInvariant() -eq $resolved17Home.ToLowerInvariant()) {
        Write-Warn "JavaHomePath and JavaHome17Path resolve to the same directory."
    }

    $major8  = Get-JavaMajorVersion $JavaHomePath
    $major17 = Get-JavaMajorVersion $JavaHome17Path
    if($major8  -ne $null -and $major8  -ne 8)  { Write-Warn ("JavaHomePath reports Java major version {0}, expected 8."  -f $major8) }
    if($major17 -ne $null -and $major17 -ne 17) { Write-Warn ("JavaHome17Path reports Java major version {0}, expected 17." -f $major17) }

    # Plan & report
    $pathPlanM = $null; $pathPlanP = $null
    if($simulate -or $doMachine) { $pathPlanM = Report-Scope 'MACHINE' 'Machine' $java8BinDir }
    if($doProcess)               { $pathPlanP = Report-Scope 'PROCESS' 'Process' $java8BinDir }

    if($simulate) {
        Write-Host "`n[SIMULATE] No changes were made."
        return
    }

    # Apply
    if($doMachine) {
        Write-Host "`n===== APPLYING at MACHINE scope ====="
        Apply-Scope 'Machine' $pathPlanM
    }
    if($doProcess) {
        Write-Host "`n===== APPLYING at PROCESS scope (current session) ====="
        Apply-Scope 'Process' $pathPlanP
    }

    # Snapshot
    $snapshot = [ordered]@{}
    if($doMachine) {
        $snapshot['MACHINE.JAVA_HOME']    = [Environment]::GetEnvironmentVariable('JAVA_HOME',    'Machine')
        $snapshot['MACHINE.JAVA_HOME_17'] = [Environment]::GetEnvironmentVariable('JAVA_HOME_17', 'Machine')
        $snapshot['MACHINE.Path']         = [Environment]::GetEnvironmentVariable('Path',         'Machine')
    }
    if($doProcess) {
        $snapshot['PROCESS.JAVA_HOME']    = $env:JAVA_HOME
        $snapshot['PROCESS.JAVA_HOME_17'] = $env:JAVA_HOME_17
        $snapshot['PROCESS.Path']         = $env:Path
    }
    $snapshotFile = Join-Path $OutDir "java-env-after.txt"
    $snapshot.Keys | ForEach-Object { "{0}={1}" -f $_, $snapshot[$_] } |
            Set-Content -Path $snapshotFile -Encoding UTF8
    Write-Info "Snapshot exported to: $snapshotFile"

    if($doMachine) {
        Write-Warn "Existing services/processes typically need restart to pick up updated MACHINE environment variables."
    }
}
