# 10_timer.ps1 - Add SetTimerResolution to Windows startup (shell:startup)

$ROOT     = Split-Path $PSScriptRoot
$timerExe = Join-Path $ROOT "tools\SetTimerResolution.exe"

if (-not (Test-Path $timerExe)) {
    Write-Host "    SetTimerResolution.exe not found: $timerExe" -ForegroundColor Yellow
    return
}

$startupDir   = [System.Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDir "SetTimerResolution.lnk"

$wsh      = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath       = $timerExe
$shortcut.Arguments        = "--resolution 5200 --no-console"
$shortcut.WorkingDirectory = Split-Path $timerExe
$shortcut.Description      = "SetTimerResolution - Opti Pack"
$shortcut.Save()

Write-Host "    Shortcut created: $shortcutPath"
Write-Host "    Arguments      : --resolution 5200 --no-console"
Write-Host "    Tip            : use MeasureSleep.exe to verify the actual resolution"
Write-Host "                     (adjust value if needed: 5000, 5100, 5200...)"
