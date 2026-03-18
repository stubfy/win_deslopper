# personal_settings.ps1 - Subjective shell/theme preferences
# Keeps user-specific UI taste separate from optimization/privacy tweaks.

$REG = Join-Path $PSScriptRoot "personal_settings.reg"
$QuietHoursCommon = Join-Path $PSScriptRoot 'quiet_hours_common.ps1'

if (-not (Test-Path $REG)) {
    Write-Host "    [ERROR] personal_settings.reg not found: $REG"
    exit 1
}

if (-not (Test-Path $QuietHoursCommon)) {
    Write-Host "    [ERROR] quiet_hours_common.ps1 not found: $QuietHoursCommon"
    exit 1
}

. $QuietHoursCommon

$result = Start-Process regedit.exe -ArgumentList "/s `"$REG`"" -Wait -PassThru
if ($result.ExitCode -eq 0) {
    Write-Host "    [OK] personal_settings.reg imported"
} else {
    Write-Host "    [WARN] regedit exit code: $($result.ExitCode)"
}

function Disable-AutoDndRules {
    $result = Disable-DoNotDisturbAutomation

    try {
        $serviceResult = Restart-DoNotDisturbNotificationServices
        if ($serviceResult.Found) {
            Write-Host "    [OK] Do Not Disturb forced off and automatic rules disabled ($($result.AutoRuleCount)/4 rules, WpnUserService restarted)"
        } else {
            Write-Host "    [OK] Do Not Disturb forced off and automatic rules disabled ($($result.AutoRuleCount)/4 rules)"
            Write-Host "    [WARN] WpnUserService not found during refresh -- changes apply after sign-out or reboot"
        }
    } catch {
        Write-Host "    [OK] Do Not Disturb forced off and automatic rules disabled ($($result.AutoRuleCount)/4 rules)"
        Write-Host "    [WARN] Could not restart WpnUserService: $_ -- changes apply after reboot"
    }
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

function Warn-WallpaperOverrides {
    $wallpaperProcesses = Get-Process -Name 'wallpaper64', 'wallpaperservice32' -ErrorAction SilentlyContinue
    $wallpaperService = Get-Service -Name 'Wallpaper Engine Service' -ErrorAction SilentlyContinue

    if ($wallpaperProcesses -or ($wallpaperService -and $wallpaperService.Status -eq 'Running')) {
        Write-Host "    [WARN] Wallpaper Engine is running and may immediately override desktop background changes" -ForegroundColor Yellow
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
    $wallpapersPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers'
    $desktopPath = 'HKCU:\Control Panel\Desktop'
    $colorsPath = 'HKCU:\Control Panel\Colors'

    Remove-Item -LiteralPath $transcodedWallpaper -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $cachedFilesPath -Recurse -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $wallpapersPath)) {
        New-Item -Path $wallpapersPath -Force | Out-Null
    }

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
        Set-ItemProperty -Path $wallpapersPath -Name 'BackgroundType' -Value 1 -Type DWord
        Set-ItemProperty -Path $desktopPath -Name 'WallPaper' -Value ''
        Set-ItemProperty -Path $desktopPath -Name 'WallpaperStyle' -Value '0'
        Set-ItemProperty -Path $desktopPath -Name 'TileWallpaper' -Value '0'
        Set-ItemProperty -Path $colorsPath -Name 'Background' -Value '0 0 0'
        [int[]]$desktopElement = 1   # COLOR_DESKTOP
        [int[]]$blackColor     = 0   # RGB(0,0,0)
        [WinDeslopper.WallpaperNativeMethods]::SetSysColors(1, $desktopElement, $blackColor) | Out-Null
    } else {
        Set-ItemProperty -Path $wallpapersPath -Name 'BackgroundType' -Value 0 -Type DWord
        Set-ItemProperty -Path $desktopPath -Name 'WallPaper' -Value $Path
        Set-ItemProperty -Path $desktopPath -Name 'WallpaperStyle' -Value '10'
        Set-ItemProperty -Path $desktopPath -Name 'TileWallpaper' -Value '0'
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
Disable-AutoDndRules
Refresh-UserPolicy
Warn-WallpaperOverrides
Set-DesktopWallpaper -Path ''
Refresh-UserShell
Write-Host "    [NOTE] Some taskbar/theme changes may fully apply after Explorer restart or reboot" -ForegroundColor DarkGray
