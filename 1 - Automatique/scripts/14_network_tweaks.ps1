# 14_network_tweaks.ps1 - Tweaks reseau complementaires (source : Chris Titus WinUtil)

# Desactiver Teredo (tunnel IPv6-over-IPv4 inutile en gaming, peut causer de la latence)
netsh interface teredo set state disabled 2>&1 | ForEach-Object { Write-Host "    $_" }
Write-Host "    Teredo desactive"
