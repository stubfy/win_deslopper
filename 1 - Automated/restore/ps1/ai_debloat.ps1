# restore\ai_debloat.ps1 - Remove AI deep-debloat hooks and restore saved files

$ROOT       = Split-Path (Split-Path (Split-Path $PSScriptRoot))
$BACKUP_DIR = Join-Path $ROOT 'backup'
$STATE_FILE = Join-Path $BACKUP_DIR 'ai_debloat_state.json'
$TASK_PATH  = '\win_desloperf\'
$TASK_NAME  = 'AI Cleanup Check'

function Write-Info {
    param([string]$Message)
    Write-Host "    [INFO] $Message" -ForegroundColor DarkGray
}

function Write-Ok {
    param([string]$Message)
    Write-Host "    [OK]   $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    [WARN] $Message" -ForegroundColor Yellow
}

if (-not (Test-Path -LiteralPath $STATE_FILE)) {
    Write-Info 'No ai_debloat_state.json found, AI deep-debloat restore skipped'
    Write-Host '    Deep AI removals remain one-way by design.' -ForegroundColor Gray
    return
}

try {
    $state = Get-Content -LiteralPath $STATE_FILE -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Warn "Unable to read ai_debloat_state.json: $($_.Exception.Message)"
    return
}

try {
    Unregister-ScheduledTask -TaskPath $TASK_PATH -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Write-Ok 'Removed \win_desloperf\AI Cleanup Check'
} catch {
    Write-Warn "Unable to remove AI Cleanup Check task: $($_.Exception.Message)"
}

if (-not [string]::IsNullOrWhiteSpace($state.InstalledCabPackage)) {
    try {
        Remove-WindowsPackage -Online -PackageName $state.InstalledCabPackage -NoRestart -ErrorAction Stop | Out-Null
        Write-Ok 'Removed custom AI anti-reinstall package'
    } catch {
        Write-Warn "Unable to remove custom AI anti-reinstall package: $($_.Exception.Message)"
    }
}

if (-not [string]::IsNullOrWhiteSpace($state.RegionPolicyBackup) -and (Test-Path -LiteralPath $state.RegionPolicyBackup)) {
    try {
        Copy-Item -LiteralPath $state.RegionPolicyBackup -Destination (Join-Path $env:windir 'System32\IntegratedServicesRegionPolicySet.json') -Force
        Write-Ok 'Restored IntegratedServicesRegionPolicySet.json backup'
    } catch {
        Write-Warn "Unable to restore IntegratedServicesRegionPolicySet.json: $($_.Exception.Message)"
    }
}

if (-not [string]::IsNullOrWhiteSpace($state.XboxSettingsBackup) -and (Test-Path -LiteralPath $state.XboxSettingsBackup)) {
    $target = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.XboxGamingOverlay_8wekyb3d8bbwe\LocalState\profileDataSettings.txt'
    try {
        Copy-Item -LiteralPath $state.XboxSettingsBackup -Destination $target -Force
        Write-Ok 'Restored Xbox Game Bar settings backup'
    } catch {
        Write-Warn "Unable to restore Xbox Game Bar settings: $($_.Exception.Message)"
    }
}

Write-Host '    Deep AI AppX/CBS/file removals are not reinstalled automatically.' -ForegroundColor Gray
Write-Host '    Keep the system restore point if you need a fuller rollback.' -ForegroundColor Gray
