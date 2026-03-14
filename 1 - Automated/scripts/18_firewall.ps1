# 18_firewall.ps1 - Disable Windows Firewall profiles

try {
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False -ErrorAction Stop
    Write-Host "    [OK] Windows Firewall disabled for Domain, Private and Public profiles"
} catch {
    Write-Host "    [ERROR] Unable to disable Windows Firewall profiles: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
