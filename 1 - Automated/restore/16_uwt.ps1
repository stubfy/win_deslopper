# restore\16_uwt.ps1 - Restore defaults for UWT-equivalent tweaks

$REG = Join-Path $PSScriptRoot "uwt_defaults.reg"

if (-not (Test-Path $REG)) {
    Write-Host "    [ERROR] uwt_defaults.reg not found: $REG"
    exit 1
}

$result = Start-Process regedit.exe -ArgumentList "/s `"$REG`"" -Wait -PassThru
if ($result.ExitCode -eq 0) {
    Write-Host "    [OK] uwt_defaults.reg imported"
} else {
    Write-Host "    [WARN] regedit exit code: $($result.ExitCode)"
}

if (-not ('WinDeslopper.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace WinDeslopper {
    [StructLayout(LayoutKind.Sequential)]
    public struct STICKYKEYS {
        public uint cbSize;
        public uint dwFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ANIMATIONINFO {
        public uint cbSize;
        public int iMinAnimate;
    }

    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref STICKYKEYS pvParam, uint fWinIni);

        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref ANIMATIONINFO pvParam, uint fWinIni);

        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
    }
}
"@
}

$SPI_SETDRAGFULLWINDOWS     = 0x0025
$SPI_SETSTICKYKEYS          = 0x003B
$SPI_SETANIMATION           = 0x0049
$SPI_SETFONTSMOOTHING       = 0x004B
$SPI_SETUIEFFECTS           = 0x103F
$SPI_SETCLIENTAREAANIMATION = 0x1043
$SPIF_SENDCHANGE            = 0x02
$SPIF_UPDATEINIFILE         = 0x01
$SPI_FLAGS                  = $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE
$SKF_DEFAULT_OFF            = 0x000001FE

function Invoke-SpiBool {
    param(
        [uint32]$Action,
        [bool]$Enabled,
        [string]$Label
    )

    $ok = [WinDeslopper.NativeMethods]::SystemParametersInfo(
        $Action,
        [uint32]([int]$Enabled),
        [IntPtr]::Zero,
        [uint32]$SPI_FLAGS
    )

    if ($ok) {
        Write-Host "    [SET] $Label"
    } else {
        Write-Host "    [WARN] Unable to set $Label" -ForegroundColor Yellow
    }
}

function Restore-StickyKeysDefaults {
    $key = 'HKCU:\Control Panel\Accessibility\StickyKeys'
    if (-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }

    New-ItemProperty -Path $key -Name Flags -PropertyType String -Value '510' -Force | Out-Null

    $sticky = New-Object WinDeslopper.STICKYKEYS
    $sticky.cbSize = [Runtime.InteropServices.Marshal]::SizeOf([type]([WinDeslopper.STICKYKEYS]))
    $sticky.dwFlags = $SKF_DEFAULT_OFF
    $ok = [WinDeslopper.NativeMethods]::SystemParametersInfo(
        $SPI_SETSTICKYKEYS,
        0,
        [ref]$sticky,
        [uint32]$SPI_FLAGS
    )

    if ($ok) {
        Write-Host "    [SET] Sticky Keys restored to default off"
    } else {
        Write-Host "    [WARN] Unable to restore Sticky Keys defaults" -ForegroundColor Yellow
    }
}

function Restore-VisualEffectsDefaults {
    $desktop = 'HKCU:\Control Panel\Desktop'
    $metrics = 'HKCU:\Control Panel\Desktop\WindowMetrics'

    if (-not (Test-Path $desktop)) { New-Item -Path $desktop -Force | Out-Null }
    if (-not (Test-Path $metrics)) { New-Item -Path $metrics -Force | Out-Null }

    New-ItemProperty -Path $desktop -Name DragFullWindows -PropertyType String -Value '1' -Force | Out-Null
    New-ItemProperty -Path $desktop -Name FontSmoothing -PropertyType String -Value '2' -Force | Out-Null
    New-ItemProperty -Path $metrics -Name MinAnimate -PropertyType String -Value '1' -Force | Out-Null

    Invoke-SpiBool -Action $SPI_SETDRAGFULLWINDOWS -Enabled $true -Label 'Visual Effects: show window contents while dragging = on'
    Invoke-SpiBool -Action $SPI_SETUIEFFECTS -Enabled $true -Label 'Visual Effects: UI effects = on'
    Invoke-SpiBool -Action $SPI_SETCLIENTAREAANIMATION -Enabled $true -Label 'Visual Effects: client area animations = on'
    Invoke-SpiBool -Action $SPI_SETFONTSMOOTHING -Enabled $true -Label 'Visual Effects: font smoothing = on'

    $anim = New-Object WinDeslopper.ANIMATIONINFO
    $anim.cbSize = [Runtime.InteropServices.Marshal]::SizeOf([type]([WinDeslopper.ANIMATIONINFO]))
    $anim.iMinAnimate = 1
    $ok = [WinDeslopper.NativeMethods]::SystemParametersInfo(
        $SPI_SETANIMATION,
        $anim.cbSize,
        [ref]$anim,
        [uint32]$SPI_FLAGS
    )

    if ($ok) {
        Write-Host "    [SET] Visual Effects: minimize/maximize animations = on"
    } else {
        Write-Host "    [WARN] Unable to restore minimize/maximize animations" -ForegroundColor Yellow
    }
}

function Refresh-UserShell {
    Start-Process -FilePath "$env:SystemRoot\System32\rundll32.exe" `
        -ArgumentList 'user32.dll,UpdatePerUserSystemParameters' `
        -WindowStyle Hidden `
        -Wait
    Write-Host "    [SET] User shell parameters refreshed"
}

Restore-StickyKeysDefaults
Restore-VisualEffectsDefaults
Refresh-UserShell

# wscsvc is restored automatically via restore\02_services.ps1 (JSON backup)
