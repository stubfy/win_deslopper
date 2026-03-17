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

function Set-ClassicAltTab {
    $explorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    if (-not (Test-Path $explorerPath)) {
        New-Item -Path $explorerPath -Force | Out-Null
    }

    New-ItemProperty -Path $explorerPath -Name 'AltTabSettings' -PropertyType DWord -Value 1 -Force | Out-Null

    $policyPath = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
    if (Test-Path $policyPath) {
        Remove-ItemProperty -Path $policyPath -Name 'MultiTaskingAltTabFilter' -ErrorAction SilentlyContinue
        $remainingValues = (Get-Item -Path $policyPath -ErrorAction SilentlyContinue).Property
        if (-not $remainingValues -or $remainingValues.Count -eq 0) {
            Remove-Item -Path $policyPath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "    [SET] Classic Alt+Tab enabled"
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

    if (-not ('WinDeslopper.WallpaperNativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace WinDeslopper {
    public static class WallpaperNativeMethods {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetSysColors(int cElements, int[] lpaElements, int[] lpaRgbValues);
    }
}
'@
    }

    $themePath = Join-Path $env:APPDATA 'Microsoft\Windows\Themes'
    $cachedFilesPath = Join-Path $themePath 'CachedFiles'
    $transcodedWallpaper = Join-Path $themePath 'TranscodedWallpaper'

    Remove-Item -LiteralPath $transcodedWallpaper -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $cachedFilesPath -Recurse -Force -ErrorAction SilentlyContinue

    [uint32]$SPI_SETDESKWALLPAPER = 0x0014
    [uint32]$SPIF_UPDATEINIFILE   = 0x0001
    [uint32]$SPIF_SENDCHANGE      = 0x0002

    [WinDeslopper.WallpaperNativeMethods]::SystemParametersInfo(
        $SPI_SETDESKWALLPAPER,
        0,
        $Path,
        $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE
    ) | Out-Null

    if ([string]::IsNullOrEmpty($Path)) {
        [int[]]$desktopElement = 1   # COLOR_DESKTOP
        [int[]]$blackColor     = 0   # RGB(0,0,0)
        [WinDeslopper.WallpaperNativeMethods]::SetSysColors(1, $desktopElement, $blackColor) | Out-Null
    }

    Write-Host "    [SET] Desktop background forced to solid black"
}

function Refresh-UserShell {
    Start-Process -FilePath "$env:SystemRoot\System32\rundll32.exe" `
        -ArgumentList 'user32.dll,UpdatePerUserSystemParameters' `
        -WindowStyle Hidden `
        -Wait
    Write-Host "    [SET] User shell parameters refreshed"
}

Set-ClassicAltTab
Set-QuietHoursPolicyDisabled
Refresh-UserPolicy
Set-DesktopWallpaper -Path ''
Refresh-UserShell
Write-Host "    [NOTE] Some taskbar/theme changes may fully apply after Explorer restart or reboot" -ForegroundColor DarkGray
