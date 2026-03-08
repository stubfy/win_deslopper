# restore\09_ai_restore.ps1 - Supprime les politiques IA / Recall / Copilot

$paths = @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\ChatIcon'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
    # Cles Copilot supplementaires
    'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat'
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    [SUPPRIME] $path"
    } else {
        Write-Host "    [ABSENT]   $path" -ForegroundColor Gray
    }
}

# Supprimer les valeurs individuelles (cles partagees - ne pas supprimer le chemin entier)
$values = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot';             Name = 'IsCopilotAvailable'  }
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsCopilot'; Name = 'AllowCopilotRuntime' }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';           Name = 'EnableCdp'           }
)
foreach ($v in $values) {
    if (Test-Path $v.Path) {
        Remove-ItemProperty -Path $v.Path -Name $v.Name -ErrorAction SilentlyContinue
        Write-Host "    [SUPPRIME] $($v.Name)  ($($v.Path))"
    }
}

# Retirer le blocage de l'extension shell Copilot
$blockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
$clsid = "{CB5571B1-A131-4C41-BFEF-57696FCE7CA2}"
if ((Test-Path $blockedPath) -and (Get-ItemProperty -Path $blockedPath -Name $clsid -ErrorAction SilentlyContinue)) {
    Remove-ItemProperty -Path $blockedPath -Name $clsid -ErrorAction SilentlyContinue
    Write-Host "    [SUPPRIME] Extension shell Copilot debloquee"
}
