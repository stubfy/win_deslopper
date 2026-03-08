# restore\14_network_tweaks.ps1 - Restaure les tweaks reseau complementaires

# Restaurer Teredo a son etat par defaut Windows
netsh interface teredo set state default 2>&1 | ForEach-Object { Write-Host "    $_" }
Write-Host "    Teredo restaure (etat par defaut)"
