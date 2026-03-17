# 20_personal_settings.ps1 - Subjective shell/theme preferences
# Keeps user-specific UI taste separate from optimization/privacy tweaks.

$REG = Join-Path $PSScriptRoot "personal_settings.reg"

if (-not (Test-Path $REG)) {
    Write-Host "    [ERROR] personal_settings.reg not found: $REG"
    exit 1
}

$result = Start-Process regedit.exe -ArgumentList "/s `"$REG`"" -Wait -PassThru
if ($result.ExitCode -eq 0) {
    Write-Host "    [OK] personal_settings.reg imported"
} else {
    Write-Host "    [WARN] regedit exit code: $($result.ExitCode)"
}

function Set-QuietHoursPolicyDisabled {
    $policyPath = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\QuietHours'
    if (-not (Test-Path $policyPath)) {
        New-Item -Path $policyPath -Force | Out-Null
    }

    # NoQuietHours policy: 1 disables automatic Do Not Disturb / Quiet Hours behavior.
    New-ItemProperty -Path $policyPath -Name 'Enable' -PropertyType DWord -Value 1 -Force | Out-Null
    Write-Host "    [SET] Automatic Do Not Disturb rules disabled via QuietHours policy"
}

function Refresh-UserPolicy {
    $result = Start-Process -FilePath "$env:SystemRoot\System32\gpupdate.exe" `
        -ArgumentList '/target:user /force' `
        -WindowStyle Hidden `
        -Wait `
        -PassThru

    if ($result.ExitCode -eq 0) {
        Write-Host "    [SET] User policy refreshed"
    } else {
        Write-Host "    [WARN] gpupdate exit code: $($result.ExitCode)"
    }
}

function Set-DesktopWallpaper {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path
    )

    if (-not ('WinDeslopper.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace WinDeslopper {
    public static class NativeMethods {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool SystemParametersInfo(int uiAction, int uiParam, string pvParam, int fWinIni);
    }
}
'@
    }

    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE   = 0x0001
    $SPIF_SENDCHANGE      = 0x0002

    [WinDeslopper.NativeMethods]::SystemParametersInfo(
        $SPI_SETDESKWALLPAPER,
        0,
        $Path,
        $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE
    ) | Out-Null

    Write-Host "    [SET] Desktop background forced to solid black"
}

function Refresh-UserShell {
    Start-Process -FilePath "$env:SystemRoot\System32\rundll32.exe" `
        -ArgumentList 'user32.dll,UpdatePerUserSystemParameters' `
        -WindowStyle Hidden `
        -Wait
    Write-Host "    [SET] User shell parameters refreshed"
}

Set-QuietHoursPolicyDisabled
Refresh-UserPolicy
Set-DesktopWallpaper -Path ''
Refresh-UserShell
Write-Host "    [NOTE] Some taskbar/theme changes may fully apply after Explorer restart or reboot" -ForegroundColor DarkGray
