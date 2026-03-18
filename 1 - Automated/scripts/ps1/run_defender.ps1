#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$CalledFromRunAll,
    [string]$LogFile
)

$ErrorActionPreference = 'Stop'
$PACK_ROOT = Split-Path (Split-Path (Split-Path $PSScriptRoot))
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Disable Defender and Return to Normal Mode.lnk'
$legacyHelperPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Disable Defender and Return to Normal Mode.bat'
$defenderBatch = Join-Path $PACK_ROOT '2 - Windows Defender\run_defender.bat'
$defenderScript = Join-Path $PSScriptRoot '1 - DisableDefender.ps1'

function Write-DefenderLog {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )

    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        return
    }

    $line = "[{0}] [{1,-5}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function New-DefenderDesktopShortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath
    )

    $shell = $null
    $shortcut = $null

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($ShortcutPath)
        $shortcut.TargetPath = $TargetPath
        $shortcut.WorkingDirectory = Split-Path $TargetPath -Parent
        $shortcut.Description = 'Disable Windows Defender in Safe Mode and return to normal Windows'
        $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,71"
        $shortcut.Save()
    } finally {
        if ($null -ne $shortcut) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shortcut)
        }
        if ($null -ne $shell) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
        }
    }
}

Write-DefenderLog 'Defender Safe Mode launcher opened.' 'INFO'

if (-not (Test-Path $defenderBatch)) {
    Write-Host ''
    Write-Host '  ERROR: Defender batch launcher not found.' -ForegroundColor Red
    Write-Host "    Expected: $defenderBatch" -ForegroundColor White
    Write-DefenderLog "Missing Defender batch launcher: $defenderBatch" 'ERROR'
    throw 'Missing Defender batch launcher.'
}

if (-not (Test-Path $defenderScript)) {
    Write-Host ''
    Write-Host '  ERROR: Defender script not found.' -ForegroundColor Red
    Write-Host "    Expected: $defenderScript" -ForegroundColor White
    Write-DefenderLog "Missing Defender script: $defenderScript" 'ERROR'
    throw 'Missing Defender script.'
}

if (-not $CalledFromRunAll) {
    Write-Host ''
    Write-Host '  WINDOWS DEFENDER SAFE MODE STEP' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  This will:' -ForegroundColor White
    Write-Host '    1. Configure Safe Mode (minimal)' -ForegroundColor White
    Write-Host "    2. Create a Desktop shortcut: 'Disable Defender and Return to Normal Mode'" -ForegroundColor White
    Write-Host '    3. Reboot into Safe Mode' -ForegroundColor White
    Write-Host ''
    Write-Host '  In Safe Mode, run the Desktop shortcut. It uses the static launcher' -ForegroundColor DarkGray
    Write-Host '  from the pack, disables Defender, removes Safe Boot and reboots.' -ForegroundColor DarkGray
    Write-Host ''

    $answer = Read-Host 'Continue? (Y/N) [default: Y]'
    if ([string]::IsNullOrWhiteSpace($answer)) { $answer = 'Y' }
    if ($answer -notin @('Y', 'y')) {
        Write-Host '  Cancelled.' -ForegroundColor Yellow
        Write-DefenderLog 'Manual Defender Safe Mode step cancelled by user.' 'INFO'
        return
    }
}

Write-DefenderLog 'Configuring Safe Mode for Defender step.' 'INFO'
bcdedit /set '{current}' safeboot minimal | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-DefenderLog 'Failed to enable Safe Mode in BCD.' 'ERROR'
    throw 'Failed to enable Safe Mode in BCD.'
}

if (Test-Path $legacyHelperPath) {
    try {
        Remove-Item -LiteralPath $legacyHelperPath -Force -ErrorAction Stop
        Write-DefenderLog "Removed legacy Desktop batch helper: $legacyHelperPath" 'INFO'
    } catch {
        Write-DefenderLog ("Unable to remove legacy Desktop batch helper {0}: {1}" -f $legacyHelperPath, $_.Exception.Message) 'WARN'
    }
}

New-DefenderDesktopShortcut -ShortcutPath $shortcutPath -TargetPath $defenderBatch
Write-DefenderLog "Desktop shortcut created at $shortcutPath" 'INFO'
Write-Host ''
Write-Host '  Safe Mode is now configured.' -ForegroundColor Yellow
Write-Host ''
Write-Host '  WHAT TO DO IN SAFE MODE:' -ForegroundColor Cyan
Write-Host "    Run the shortcut on your Desktop: 'Disable Defender and Return to Normal Mode'" -ForegroundColor White
Write-Host '    It points to the static launcher in 2 - Windows Defender\run_defender.bat' -ForegroundColor DarkGray
Write-Host '    (disables Defender, removes Safe Boot, reboots automatically)' -ForegroundColor DarkGray
Write-Host ''

if ($CalledFromRunAll) {
    Write-DefenderLog 'Safe Mode configured from run_all; caller will handle final reboot.' 'INFO'
    return
}

Read-Host '  Press Enter to reboot into Safe Mode'
Write-DefenderLog 'Rebooting into Safe Mode for Defender step.' 'INFO'
Restart-Computer -Force