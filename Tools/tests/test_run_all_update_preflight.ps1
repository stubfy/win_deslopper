#Requires -Version 5.0

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$runAllPath = Join-Path $repoRoot '1 - Automated\scripts\ps1\run_all.ps1'
$updaterPath = Join-Path $repoRoot '1 - Automated\scripts\ps1\update_pack.ps1'

function Assert-Contains {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$runAll = Get-Content -Path $runAllPath -Raw
$updater = Get-Content -Path $updaterPath -Raw

Assert-Contains $updater '\[switch\]\$AssumeYes' 'update_pack.ps1 must support a non-interactive update confirmation for run_all.'
Assert-Contains $updater '\[int\]\$ParentPidForHandoff' 'update_pack.ps1 must allow run_all to pass its own PID to the update helper.'
Assert-Contains $updater 'exit 20' 'update_pack.ps1 -CheckOnly must return a distinct exit code when an update is available.'
Assert-Contains $runAll 'function Invoke-PackUpdatePreflight' 'run_all.ps1 must define the pack update preflight.'
Assert-Contains $runAll '-CheckOnly' 'run_all.ps1 must call update_pack.ps1 in check-only mode before launch.'
Assert-Contains $runAll 'Update the pack before running tweaks\? \(Y/N\) \[default: Y\]' 'run_all.ps1 must prompt for updating first, defaulting to Y.'
Assert-Contains $runAll '-AssumeYes' 'run_all.ps1 must avoid a second update confirmation after the preflight prompt.'
Assert-Contains $runAll '-ParentPidForHandoff \$PID' 'run_all.ps1 must make the update helper wait for the run_all PowerShell process before replacing the pack folder.'
Assert-Contains $runAll 'Invoke-PackUpdatePreflight -PackRoot \$PACK_ROOT -ScriptsRoot \$SCRIPTS' 'run_all.ps1 must run the update preflight before the main options menu.'

Write-Host 'run_all update preflight contract OK'
