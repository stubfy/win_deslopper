#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Update profile configuration

.DESCRIPTION
    Three profiles available (ported from WinUtil / Chris Titus Tech):
      1 - Default  : restores the WinUtil out-of-box Windows Update configuration
      2 - Security : WinUtil recommended profile (365-day feature deferral, 4-day quality deferral, no drivers via WU)
      3 - Disabled : completely disables Windows Update

    The numeric interface stays stable for compatibility with run_all.ps1,
    standalone launchers, and saved options.

    Rollback: 1 - Automated\restore\windows_update.bat reapplies Profile 1 (Default).

.PARAMETER Profil
    1, 2 or 3. If omitted, an interactive menu is shown.

.EXAMPLE
    .\set_windows_update.ps1 -Profil 2
    .\set_windows_update.ps1          # interactive menu
#>

param(
    [ValidateSet('1','2','3')]
    [string]$Profil
)

$ErrorActionPreference = 'Continue'
$VendorRoot = Join-Path $PSScriptRoot 'vendor\winutil'
$VendorFiles = @(
    'Invoke-WPFUpdatesdefault.ps1'
    'Invoke-WPFUpdatessecurity.ps1'
    'Invoke-WPFUpdatesdisable.ps1'
)

foreach ($file in $VendorFiles) {
    $path = Join-Path $VendorRoot $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing vendored WinUtil function: $path"
    }

    . $path
}

function Remove-PackWindowsUpdateOverrides {
    $paths = @(
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata'
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching'
        'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization'
    )

    foreach ($path in $paths) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not $Profil) {
    Write-Host ''
    Write-Host '  WINDOWS UPDATE PROFILE' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  [1] Default   - Restore WinUtil out-of-box Windows Update settings' -ForegroundColor Green
    Write-Host '  [2] Security  - WinUtil recommended profile (365-day feature deferral, 4-day quality deferral)' -ForegroundColor Yellow
    Write-Host '  [3] Disabled  - Completely disable Windows Update' -ForegroundColor Red
    Write-Host ''

    do {
        $Profil = Read-Host '  Choice (1/2/3)'
    } while ($Profil -notin @('1','2','3'))
}

Remove-PackWindowsUpdateOverrides

switch ($Profil) {
    '1' {
        Write-Host ''
        Write-Host '  Profile [1] Default (WinUtil out-of-box settings)' -ForegroundColor Green
        Write-Host ''
        Invoke-WPFUpdatesdefault
    }

    '2' {
        Write-Host ''
        Write-Host '  Profile [2] Security (WinUtil recommended settings)' -ForegroundColor Yellow
        Write-Host ''
        # Start from WinUtil's default baseline so machines previously set to
        # Disabled in this pack do not keep stale services or scheduled tasks.
        Invoke-WPFUpdatesdefault
        Write-Host ''
        Invoke-WPFUpdatessecurity
    }

    '3' {
        Write-Host ''
        Write-Host '  Profile [3] Disabled (WinUtil disable-all profile)' -ForegroundColor Red
        Write-Host ''
        Invoke-WPFUpdatesdisable
    }
}

Write-Host ''
