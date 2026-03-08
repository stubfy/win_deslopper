# 03_services.ps1 - Desactive les services inutiles pour le gaming

$services = [ordered]@{
    'SysMain'            = 'Superfetch - I/O disque constant, inutile sur SSD'
    'DPS'                = 'Diagnostic Policy Service - diagnostic systeme non necessaire'
    'Spooler'            = 'Print Spooler - impression (desactiver si pas d imprimante)'
    'TabletInputService' = 'Clavier tactile et panneau ecriture manuscrite'
    'RmSvc'              = 'Radio Management Service'
    'DiagTrack'          = 'Telemetrie Connected User Experiences'
    'dmwappushservice'   = 'Push telemetrie WAP'
    'WSearch'            = 'Indexeur Windows Search - I/O disque constant en arriere plan'
    'WerSvc'             = 'Windows Error Reporting - envoi rapports erreurs Microsoft'
    'DoSvc'              = 'Delivery Optimization - partage P2P des mises a jour'
    'PhoneSvc'           = 'Service telephonique (Bluetooth calls, inutile en gaming pur)'
    'SCardSvr'           = 'Smart Card - inutile sans lecteur de carte a puce'
    'ScDeviceEnum'       = 'Smart Card Device Enumeration Service'
    'SEMgrSvc'           = 'Paiements NFC / SE Manager'
    'WpcMonSvc'          = 'Controle parental Windows'
    'lfsvc'              = 'Service de geolocalisation (GPS/localisation apps)'
    'MapsBroker'         = 'Gestionnaire des cartes telechargees'
    'RetailDemo'         = 'Mode demonstration (PC boutique - sans effet si non present)'
    'RemoteRegistry'     = 'Registre a distance - risque de securite'
    'SharedAccess'       = 'Partage de connexion Internet (ICS)'
}

foreach ($svc in $services.Keys) {
    $s = Get-Service $svc -ErrorAction SilentlyContinue
    if ($s) {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Set-Service  $svc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "    [DESACTIVE] $svc"
    } else {
        Write-Host "    [ABSENT]    $svc" -ForegroundColor Gray
    }
}

# --- Services passes en Manuel (demarrent a la demande, pas au boot) ---
# Source : Chris Titus WinUtil - services non couverts par le pack
$servicesManual = [ordered]@{
    'CDPSvc'       = 'Connected Devices Platform - synchronisation entre appareils'
    'InventorySvc' = 'Inventory and Compatibility Appraisal - telemetrie materielle'
    'PcaSvc'       = 'Program Compatibility Assistant - detection problemes compat'
    'StorSvc'      = 'Storage Service - Storage Sense (demarre a la demande si besoin)'
    'UsoSvc'       = 'Update Session Orchestrator - updates automatiques en arriere-plan'
    'WpnService'   = 'Windows Push Notifications - toasts et interruptions'
    'camsvc'       = 'Capability Access Manager - acces apps UWP camera/micro'
    'edgeupdate'   = 'Microsoft Edge Update - MAJ automatiques Edge'
    'edgeupdatem'  = 'Microsoft Edge Update (tache planifiee)'
    'BITS'         = 'Background Intelligent Transfer - transferts arriere-plan'
    'WSAIFabricSvc'= 'Windows AI Fabric - runtime IA (Recall, Copilot runtime)'
}

foreach ($svc in $servicesManual.Keys) {
    $s = Get-Service $svc -ErrorAction SilentlyContinue
    if ($s) {
        Set-Service $svc -StartupType Manual -ErrorAction SilentlyContinue
        Write-Host "    [MANUEL]    $svc"
    } else {
        Write-Host "    [ABSENT]    $svc" -ForegroundColor Gray
    }
}

# --- Kiosk mode (inutile sur PC gaming) ---
$s = Get-Service 'AssignedAccessManagerSvc' -ErrorAction SilentlyContinue
if ($s) {
    Stop-Service 'AssignedAccessManagerSvc' -Force -ErrorAction SilentlyContinue
    Set-Service  'AssignedAccessManagerSvc' -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "    [DESACTIVE] AssignedAccessManagerSvc"
} else {
    Write-Host "    [ABSENT]    AssignedAccessManagerSvc" -ForegroundColor Gray
}
