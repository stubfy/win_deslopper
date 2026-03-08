# restore\03_bcdedit.ps1 - Restore default boot configuration

bcdedit /deletevalue disabledynamictick 2>&1 | Out-Null
Write-Host "    disabledynamictick removed (dynamic tick re-enabled)"

bcdedit /set bootmenupolicy standard 2>&1 | Out-Null
Write-Host "    bootmenupolicy = standard (graphical recovery options restored)"

bcdedit /deletevalue useplatformclock 2>&1 | Out-Null
Write-Host "    useplatformclock removed (HPET managed automatically by Windows)"
