# restore\opt_edge_restore.ps1 - Reinstall Microsoft Edge + WebView2 Runtime

$webView2AppGuid       = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
$webView2PolicyPath    = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
$webView2InstallPolicy = "Install$webView2AppGuid"
$webView2UpdatePolicy  = "Update$webView2AppGuid"

# Remove dummy UWP Edge file created by the uninstall flow
$dummyEdgePath = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
if (Test-Path $dummyEdgePath) {
    Remove-Item -Path $dummyEdgePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "    Dummy UWP file : removed."
}

# Remove reinstallation block
$noEdge = 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate'
if (Test-Path $noEdge) {
    Remove-ItemProperty -Path $noEdge -Name 'DoNotUpdateToEdgeWithChromium' -ErrorAction SilentlyContinue
    Write-Host "    Edge reinstallation block removed."
}

foreach ($path in @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev'
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev'
)) {
    if (Test-Path $path) {
        Remove-ItemProperty -Path $path -Name 'AllowUninstall' -ErrorAction SilentlyContinue
    }
}

# Remove WebView2 install/update blocks
if (Test-Path $webView2PolicyPath) {
    Remove-ItemProperty -Path $webView2PolicyPath -Name $webView2InstallPolicy -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $webView2PolicyPath -Name $webView2UpdatePolicy -ErrorAction SilentlyContinue
    Write-Host "    WebView2 reinstallation block removed."
}

# Attempt reinstallation via winget
Write-Host "    Reinstalling Microsoft Edge via winget..."
$result = winget install --id Microsoft.Edge --silent --accept-package-agreements --accept-source-agreements 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "    [OK] Edge reinstalled."
} else {
    Write-Host "    winget returned: $LASTEXITCODE" -ForegroundColor Yellow
    Write-Host "    Download Edge manually: https://www.microsoft.com/edge" -ForegroundColor Gray
}

Write-Host "    Reinstalling Microsoft Edge WebView2 Runtime via winget..."
$result = winget install --id Microsoft.EdgeWebView2Runtime --silent --accept-package-agreements --accept-source-agreements 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "    [OK] WebView2 Runtime reinstalled."
} else {
    Write-Host "    winget returned: $LASTEXITCODE" -ForegroundColor Yellow
    Write-Host "    Download WebView2 manually: https://developer.microsoft.com/microsoft-edge/webview2/" -ForegroundColor Gray
}
