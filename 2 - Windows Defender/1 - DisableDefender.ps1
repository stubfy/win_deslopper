#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services'
$services = @(
    'WinDefend',
    'Sense',
    'WdFilter',
    'WdNisDrv',
    'WdNisSvc',
    'WdBoot'
)

$updated = 0

foreach ($service in $services) {
    $path = Join-Path $regPath $service
    if (-not (Test-Path $path)) {
        Write-Host "Skipping $service (service key not found)." -ForegroundColor Yellow
        continue
    }

    Set-ItemProperty -Path $path -Name Start -Value 4 -Type DWord
    Write-Host "Disabled $service (Start=4)." -ForegroundColor Green
    $updated++
}

if ($updated -eq 0) {
    throw "No Defender service keys were updated."
}

Write-Host ""
Write-Host "Windows Defender service startup values updated." -ForegroundColor Cyan
