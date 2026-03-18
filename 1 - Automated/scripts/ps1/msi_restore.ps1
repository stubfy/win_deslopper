#Requires -RunAsAdministrator
# msi_restore.ps1 - Reapply MSI interrupt state from the canonical saved snapshot.
# Canonical replay snapshot: 1 - Automated\backup\msi_state.json
# Local MSI tool folder still holds auxiliary JSONs only.

param(
    [string]$StateFile = '',
    [string]$DataDir = '',
    [switch]$SkipConfirm
)

$ErrorActionPreference = 'Continue'
$PACK_ROOT = Split-Path (Split-Path (Split-Path $PSScriptRoot))
if ($DataDir -eq '') { $DataDir = Join-Path $PACK_ROOT '3 - MSI Utils' }
if ($StateFile -eq '') { $StateFile = Join-Path $PACK_ROOT '1 - Automated\backup\msi_state.json' }
$LEGACY_STATE_FILE = Join-Path $DataDir 'msi_state.json'
$PRE_RESTORE_BACKUP = Join-Path $DataDir 'msi_state_pre_restore.json'

function Write-Info($msg) { Write-Host "    $msg" }
function Write-Ok($msg) { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    [WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "    [ERROR] $msg" -ForegroundColor Red }
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }

function Resolve-StateFile {
    if (Test-Path $StateFile) { return $StateFile }
    if (-not (Test-Path $LEGACY_STATE_FILE)) { return $StateFile }
    try {
        Ensure-Dir (Split-Path $StateFile -Parent)
        Copy-Item -LiteralPath $LEGACY_STATE_FILE -Destination $StateFile -Force
        Write-Warn "Legacy snapshot migrated -> $StateFile"
        return $StateFile
    } catch {
        Write-Warn "Could not migrate legacy snapshot: $($_.Exception.Message)"
        return $LEGACY_STATE_FILE
    }
}

Write-Host ''
Write-Host '================================================' -ForegroundColor Cyan
Write-Host '   MSI RESTORE                                  ' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''

Ensure-Dir $DataDir
$ResolvedStateFile = Resolve-StateFile

if (-not (Test-Path $ResolvedStateFile)) {
    Write-Err "Snapshot not found: $ResolvedStateFile"
    Write-Info 'Run msi_snapshot.bat first to create a snapshot.'
    Write-Host ''
    exit 1
}

try {
    $raw = Get-Content $ResolvedStateFile -Encoding UTF8 | ConvertFrom-Json
    $metaObj = $raw._meta
    Write-Info "Snapshot: $ResolvedStateFile"
    Write-Info "Created : $($metaObj.created) on $($metaObj.machine)"
    Write-Info "OS      : $($metaObj.os)"
} catch {
    Write-Err "Failed to read snapshot: $($_.Exception.Message)"
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Info 'Saving current live state before modifications...'
$preBackup = [ordered]@{}
$preBackup['_meta'] = [ordered]@{
    created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    machine = $env:COMPUTERNAME
    os = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
}

$allPciDevices = Get-PnpDevice -InstanceId 'PCI\*' -ErrorAction SilentlyContinue
foreach ($dev in $allPciDevices) {
    $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    if (Test-Path $msiPath) {
        $props = Get-ItemProperty -Path $msiPath -ErrorAction SilentlyContinue
        $preBackup[$dev.InstanceId] = [ordered]@{
            FriendlyName = $dev.FriendlyName
            Class = $dev.Class
            MSISupported = $props.MSISupported
            MessageNumberLimit = $props.MessageNumberLimit
        }
    }
}

try {
    $preBackup | ConvertTo-Json -Depth 3 | Set-Content -Path $PRE_RESTORE_BACKUP -Encoding UTF8
    Write-Ok 'Pre-restore backup saved -> msi_state_pre_restore.json'
} catch {
    Write-Warn "Could not write pre-restore backup: $($_.Exception.Message)"
}

Write-Host ''
$currentDeviceIds = @{}
foreach ($dev in $allPciDevices) { $currentDeviceIds[$dev.InstanceId] = $dev }

$toApply = @()
$propsNames = $raw | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
foreach ($id in $propsNames) {
    if ($id -eq '_meta') { continue }
    $entry = $raw.$id
    if ($null -ne $entry.MSISupported) { $toApply += $id }
}

Write-Info "$($toApply.Count) device(s) with MSI state to apply (null entries will be skipped)."
Write-Host ''

if (-not $SkipConfirm) {
    $ans = Read-Host '  Continue? (Y/N) [default: N]'
    if ($ans -notin @('Y', 'y')) {
        Write-Info 'Aborted by user.'
        Write-Host ''
        exit 0
    }
    Write-Host ''
}

$countApplied = 0
$countSkipped = 0
$countNotFound = 0
$countErrors = 0

foreach ($id in $propsNames) {
    if ($id -eq '_meta') { continue }
    $entry = $raw.$id
    if ($null -eq $entry.MSISupported) {
        $countSkipped++
        continue
    }
    if (-not $currentDeviceIds.ContainsKey($id)) {
        Write-Warn "Device not found on this system (may have changed slot/ID): $id"
        if ($entry.FriendlyName) { Write-Warn "  Was: $($entry.FriendlyName)" }
        $countNotFound++
        continue
    }

    $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    try {
        if (-not (Test-Path $msiPath)) { New-Item -Path $msiPath -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $msiPath -Name 'MSISupported' -Value ([int]$entry.MSISupported) -Type DWord -Force -ErrorAction Stop
        if ($null -ne $entry.MessageNumberLimit) {
            Set-ItemProperty -Path $msiPath -Name 'MessageNumberLimit' -Value ([int]$entry.MessageNumberLimit) -Type DWord -Force -ErrorAction Stop
        }
        $label = if ($entry.FriendlyName) { $entry.FriendlyName } else { $id }
        $msiLabel = if ($entry.MSISupported -eq 1) { 'MSI ON' } else { 'MSI OFF' }
        Write-Ok ("[$msiLabel] $label")
        $countApplied++
    } catch {
        Write-Err ("Failed on {0}: {1}" -f $id, $_.Exception.Message)
        $countErrors++
    }
}

Write-Host ''
Write-Host ("    Applied: {0}  |  Skipped (no key): {1}  |  Not found: {2}  |  Errors: {3}" -f $countApplied, $countSkipped, $countNotFound, $countErrors) -ForegroundColor Cyan
Write-Host ''

if ($countNotFound -gt 0) {
    Write-Warn 'Some devices were not found. They may have changed PCI slot or InstanceId.'
    Write-Warn 'Open MSI_util_v3.exe to configure them manually.'
    Write-Host ''
}

Write-Host '    Reboot required for changes to take effect.' -ForegroundColor Yellow
Write-Host ''
