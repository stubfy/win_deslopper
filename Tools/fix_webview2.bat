@echo off
:: fix_webview2.bat - Restores WebView2 Runtime and fixes Start menu search
:: Use this on machines where a previous version of the pack removed WebView2,
:: causing an infinite loading loop in Start menu search after reboot.
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================
echo  Fix WebView2 - Restore Start menu search
echo ============================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$guid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';" ^
 "" ^
 "Write-Host '[1/3] Removing WebView2 reinstall block policies...';" ^
 "$hives = @('HKLM:\SOFTWARE', 'HKLM:\SOFTWARE\WOW6432Node', 'HKCU:\Software');" ^
 "foreach ($sw in $hives) {" ^
 "  $p = \"$sw\Microsoft\EdgeUpdate\";" ^
 "  if (Test-Path $p) {" ^
 "    Remove-ItemProperty -Path $p -Name \"Install$guid\" -ErrorAction SilentlyContinue;" ^
 "    Remove-ItemProperty -Path $p -Name \"Update$guid\" -ErrorAction SilentlyContinue;" ^
 "    Write-Host \"    Cleared: $p\";" ^
 "  }" ^
 "}" ^
 "$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate';" ^
 "if (Test-Path $pol) {" ^
 "  Remove-ItemProperty -Path $pol -Name \"Install$guid\" -ErrorAction SilentlyContinue;" ^
 "  Remove-ItemProperty -Path $pol -Name \"Update$guid\" -ErrorAction SilentlyContinue;" ^
 "  Write-Host \"    Cleared: $pol\";" ^
 "}" ^
 "" ^
 "Write-Host '';" ^
 "Write-Host '[2/3] Re-registering Win32WebViewHost AppX package...';" ^
 "$pkg = Get-AppxPackage -AllUsers -Name '*Win32WebViewHost*' -ErrorAction SilentlyContinue;" ^
 "if ($pkg) {" ^
 "  Write-Host \"    Already registered: $($pkg.PackageFullName)\";" ^
 "} else {" ^
 "  $manifest = Get-ChildItem 'C:\Windows\SystemApps' -Filter 'AppxManifest.xml' -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'WebView' } | Select-Object -First 1;" ^
 "  if ($manifest) {" ^
 "    Write-Host \"    Re-registering from: $($manifest.FullName)\";" ^
 "    Add-AppxPackage -Register $manifest.FullName -DisableDevelopmentMode -ErrorAction SilentlyContinue;" ^
 "  } else {" ^
 "    Write-Host '    WebView2 AppX not found locally. Download required (step 3).';" ^
 "  }" ^
 "}" ^
 "" ^
 "Write-Host '';" ^
 "Write-Host '[3/3] Downloading WebView2 Evergreen Runtime...';" ^
 "$installer = Join-Path $env:TEMP 'MicrosoftEdgeWebView2Setup.exe';" ^
 "try {" ^
 "  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
 "  Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $installer -UseBasicParsing;" ^
 "  Write-Host '    Downloaded. Installing...';" ^
 "  Start-Process -FilePath $installer -ArgumentList '/silent /install' -Wait;" ^
 "  Write-Host '    WebView2 Runtime installed.';" ^
 "  Remove-Item $installer -Force -ErrorAction SilentlyContinue;" ^
 "} catch {" ^
 "  Write-Host \"    Download failed: $($_.Exception.Message)\" -ForegroundColor Yellow;" ^
 "  Write-Host '    Download WebView2 manually from another PC and run the installer.' -ForegroundColor Yellow;" ^
 "}"

echo.
echo ============================================
echo  Done. Reboot the PC, then test Start menu
echo  search by pressing Start and typing "uac".
echo ============================================
pause
