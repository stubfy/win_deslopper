#Requires -RunAsAdministrator
# msi_snapshot.ps1 - Capture MSI interrupt state of all PCI devices.
# Canonical replay snapshot: 1 - Automated\backup\msi_state.json
# Local MSI tool folder still holds auxiliary JSONs only.

param(
    [string]$DataDir = '',
    [string]$StateFile = ''
)

$ErrorActionPreference = 'Continue'
$PACK_ROOT = Split-Path (Split-Path (Split-Path $PSScriptRoot))
if ($DataDir -eq '') { $DataDir = Join-Path $PACK_ROOT '3 - MSI Utils' }
if ($StateFile -eq '') { $StateFile = Join-Path $PACK_ROOT '1 - Automated\backup\msi_state.json' }
$LEGACY_STATE_FILE = Join-Path $DataDir 'msi_state.json'
$BACKUP_FILE = Join-Path $DataDir 'msi_state_backup.json'
$PREVIOUS_FILE = Join-Path $DataDir 'msi_state_previous.json'

function Write-Info($msg) { Write-Host "    $msg" }
function Write-Ok($msg) { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    [WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "    [ERROR] $msg" -ForegroundColor Red }
function Ensure-Dir([string]$Path) { if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null } }

function Resolve-StateFile {
    if (Test-Path $StateFile) { return }
    if (-not (Test-Path $LEGACY_STATE_FILE)) { return }
    try {
        Ensure-Dir (Split-Path $StateFile -Parent)
        Copy-Item -LiteralPath $LEGACY_STATE_FILE -Destination $StateFile -Force
        Write-Warn "Legacy snapshot migrated -> $StateFile"
    } catch {
        Write-Warn "Could not migrate legacy snapshot: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host '================================================' -ForegroundColor Cyan
Write-Host '   MSI SNAPSHOT                                 ' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''

Resolve-StateFile
Ensure-Dir $DataDir
Ensure-Dir (Split-Path $StateFile -Parent)

Write-Info 'Reading current live MSI state for backup...'
$liveState = [ordered]@{}
$liveState['_meta'] = [ordered]@{
    created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    machine = $env:COMPUTERNAME
    os = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
}

$allPciDevices = Get-PnpDevice -InstanceId 'PCI\*' -ErrorAction SilentlyContinue
foreach ($dev in $allPciDevices) {
    $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    if (Test-Path $msiPath) {
        $props = Get-ItemProperty -Path $msiPath -ErrorAction SilentlyContinue
        $liveState[$dev.InstanceId] = [ordered]@{
            FriendlyName = $dev.FriendlyName
            Class = $dev.Class
            MSISupported = $props.MSISupported
            MessageNumberLimit = $props.MessageNumberLimit
        }
    }
}

try {
    $liveState | ConvertTo-Json -Depth 3 | Set-Content -Path $BACKUP_FILE -Encoding UTF8
    Write-Ok 'Current live state saved -> msi_state_backup.json'
} catch {
    Write-Warn "Could not write msi_state_backup.json: $($_.Exception.Message)"
}

if (Test-Path $StateFile) {
    try {
        Copy-Item -Path $StateFile -Destination $PREVIOUS_FILE -Force
        Write-Ok 'Previous canonical snapshot preserved -> msi_state_previous.json'
    } catch {
        Write-Warn "Could not copy previous snapshot: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Info 'Enumerating PCI devices...'
Write-Host ''

$snapshot = [ordered]@{}
$snapshot['_meta'] = [ordered]@{
    created = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    machine = $env:COMPUTERNAME
    os = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
}
$countOn = 0
$countOff = 0
$countNoKey = 0

foreach ($dev in $allPciDevices) {
    $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    if (Test-Path $msiPath) {
        $props = Get-ItemProperty -Path $msiPath -ErrorAction SilentlyContinue
        $msiVal = $props.MSISupported
        $limitVal = $props.MessageNumberLimit
        $snapshot[$dev.InstanceId] = [ordered]@{
            FriendlyName = $dev.FriendlyName
            Class = $dev.Class
            MSISupported = $msiVal
            MessageNumberLimit = $limitVal
        }
        if ($msiVal -eq 1) {
            Write-Host ("    [MSI ON]  {0,-40} {1}" -f $dev.FriendlyName, $dev.InstanceId) -ForegroundColor Green
            $countOn++
        } else {
            Write-Host ("    [MSI OFF] {0,-40} {1}" -f $dev.FriendlyName, $dev.InstanceId) -ForegroundColor DarkYellow
            $countOff++
        }
    } else {
        $snapshot[$dev.InstanceId] = [ordered]@{
            FriendlyName = $dev.FriendlyName
            Class = $dev.Class
            MSISupported = $null
            MessageNumberLimit = $null
        }
        Write-Host ("    [No key]  {0,-40} {1}" -f $dev.FriendlyName, $dev.InstanceId) -ForegroundColor DarkGray
        $countNoKey++
    }
}

Write-Host ''
try {
    $snapshot | ConvertTo-Json -Depth 3 | Set-Content -Path $StateFile -Encoding UTF8
    Write-Ok ("Snapshot written -> {0}" -f $StateFile)
} catch {
    Write-Err ("Failed to write snapshot: {0}" -f $_.Exception.Message)
}

Write-Host ''
Write-Host "    Summary: $countOn MSI ON, $countOff MSI OFF, $countNoKey no registry key" -ForegroundColor Cyan
Write-Host ''
Write-Host "    Canonical snapshot: $StateFile" -ForegroundColor DarkGray
Write-Host '    Run msi_restore.bat after a reformat to replay this state.' -ForegroundColor DarkGray
Write-Host ''
