# 04_bcdedit.ps1 - Boot configuration to reduce latency

# Force constant TSC tick (reduces timer latency in games)
bcdedit /set disabledynamictick yes 2>&1 | Out-Null
Write-Host "    disabledynamictick = yes"

# Classic boot menu (faster boot)
# WARNING: disables access to graphical recovery options (F8 still works)
bcdedit /set bootmenupolicy legacy 2>&1 | Out-Null
Write-Host "    bootmenupolicy = legacy"

# Disable HPET (High Precision Event Timer) - may reduce DPC latency on some systems
bcdedit /set useplatformclock false 2>&1 | Out-Null
Write-Host "    useplatformclock = false (HPET disabled)"
