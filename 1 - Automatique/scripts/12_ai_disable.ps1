# 12_ai_disable.ps1 - Desactive les fonctionnalites IA / Recall / Copilot (Windows 11 25H2)

$policies = @{
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' = @{
        'DisableAIDataAnalysis' = 1   # Desactive Recall (enregistrement ecran IA)
        'AllowRecallEnablement' = 0   # Empeche l'activation de Recall
    }
    'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' = @{
        'TurnOffWindowsCopilot' = 1
    }
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' = @{
        'TurnOffWindowsCopilot' = 1
    }
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\ChatIcon' = @{
        'Show' = 3   # 3 = cacher l'icone Copilot de la barre des taches
    }
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' = @{
        'DODownloadMode' = 0   # Desactive le mode P2P des mises a jour
    }
    # Cles Copilot supplementaires (source : Chris Titus WinUtil)
    'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot' = @{
        'IsCopilotAvailable' = 0
    }
    'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat' = @{
        'IsUserEligible' = 0
    }
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsCopilot' = @{
        'AllowCopilotRuntime' = 0
    }
    # Cross-Device Resume (24H2+) - desactive la reprise d'activite entre appareils
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' = @{
        'EnableCdp' = 0
    }
}

foreach ($path in $policies.Keys) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -Force | Out-Null
    }
    foreach ($name in $policies[$path].Keys) {
        Set-ItemProperty -Path $path -Name $name -Value $policies[$path][$name] -Type DWord -ErrorAction SilentlyContinue
        Write-Host "    [SET] $name = $($policies[$path][$name])  ($path)"
    }
}

# Bloquer l'extension shell Copilot (CLSID WinUtil)
$blockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
if (-not (Test-Path $blockedPath)) { New-Item -Path $blockedPath -Force | Out-Null }
Set-ItemProperty -Path $blockedPath -Name "{CB5571B1-A131-4C41-BFEF-57696FCE7CA2}" -Value "Copilot Shell Extension" -Type String -ErrorAction SilentlyContinue
Write-Host "    [SET] Extension shell Copilot bloquee"
