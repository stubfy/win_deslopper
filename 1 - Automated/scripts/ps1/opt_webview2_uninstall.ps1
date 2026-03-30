# opt_webview2_uninstall.ps1 - WebView2 Runtime uninstall
# OPTIONAL - separate from Edge uninstall, default OFF in run_all.ps1
#
# WARNING: SearchHost.exe (Start menu search) uses WebView2 for rendering on some
# machines (IsWebView2=1). Removing WebView2 causes an infinite loading loop in
# Start menu search after reboot. Only enable if you are certain your machine does
# not use WebView2 for search.
#
# Fix if broken: Tools\fix_webview2.bat
# Rollback: restore\opt_edge_restore.ps1 can reinstall WebView2 via winget.
#
# WebView2 is distributed both as a Win32 package (setup.exe) and as an AppX
# package (Win32WebViewHost). This script:
#   a. Uses DISM to mark Win32WebViewHost as removable (clears non-removable flag).
#   b. Directly deletes the WebView2 file tree using takeown + icacls to override
#      any access restrictions.
#   c. Cleans up EdgeUpdate client registry keys and uninstall entries.
#   d. Applies a reinstall block (EdgeUpdate policy values Install=0, Update=0).

$webView2DisplayName = 'Microsoft Edge WebView2 Runtime'
$webView2AppGuid     = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
$webView2Roots = @(
    "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application"
    "$env:ProgramFiles\Microsoft\EdgeWebView\Application"
    "$env:LOCALAPPDATA\Microsoft\EdgeWebView\Application"
)
$webView2ClientKeys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$webView2AppGuid"
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$webView2AppGuid"
    "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$webView2AppGuid"
)
$webView2BlockPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
$webView2InstallPolicy   = "Install$webView2AppGuid"
$webView2UpdatePolicy    = "Update$webView2AppGuid"

function Get-UninstallEntries {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue
}

function Get-UninstallEntryByName {
    param([Parameter(Mandatory = $true)][string]$DisplayNamePattern)
    Get-UninstallEntries |
        Where-Object { $_.DisplayName -like $DisplayNamePattern } |
        Select-Object -First 1
}

function Get-WebView2PresenceEvidence {
    $evidence = [System.Collections.Generic.List[string]]::new()

    foreach ($key in $webView2ClientKeys) {
        if (-not (Test-Path $key)) { continue }
        try { $version = [string](Get-ItemPropertyValue -Path $key -Name 'pv' -ErrorAction Stop) } catch { $version = $null }
        if ($version -and $version -ne '0.0.0.0') { $evidence.Add("client key $key (pv=$version)") }
    }

    foreach ($root in $webView2Roots) {
        if (-not (Test-Path $root)) { continue }
        if (Test-Path (Join-Path $root 'msedgewebview2.exe')) { $evidence.Add("files under $root"); continue }
        $exe = Get-ChildItem -Path $root -Filter 'msedgewebview2.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) { $evidence.Add("files under $root") }
    }

    try {
        $appxPackages = @(Get-AppxPackage -AllUsers -Name '*Win32WebViewHost*' -ErrorAction Stop)
        foreach ($pkg in $appxPackages) {
            $loc = [string]$pkg.InstallLocation
            if ($loc -and (Test-Path -LiteralPath $loc)) { $evidence.Add("AppX $($pkg.PackageFullName)") }
        }
    } catch {}

    try {
        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Win32WebViewHost*' })
        foreach ($pkg in $provisioned) { $evidence.Add("provisioned $($pkg.PackageName)") }
    } catch {}

    if (Get-UninstallEntryByName -DisplayNamePattern "$webView2DisplayName*") { $evidence.Add("uninstall entry $webView2DisplayName") }
    return @($evidence | Select-Object -Unique)
}

function Test-WebView2Installed { return (@(Get-WebView2PresenceEvidence).Count -gt 0) }

function Get-WebView2UninstallInfo {
    $entry = Get-UninstallEntryByName -DisplayNamePattern "$webView2DisplayName*"
    if (-not $entry) { return $null }
    $uninstallString = if ($entry.QuietUninstallString) { [string]$entry.QuietUninstallString } else { [string]$entry.UninstallString }
    if (-not $uninstallString) { return $null }
    return [PSCustomObject]@{ DisplayName = [string]$entry.DisplayName; Key = [string]$entry.PSPath; UninstallString = $uninstallString }
}

function Get-WebView2SetupCandidates {
    $patterns = @(
        "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application\*\Installer\setup.exe"
        "$env:ProgramFiles\Microsoft\EdgeWebView\Application\*\Installer\setup.exe"
        "$env:LOCALAPPDATA\Microsoft\EdgeWebView\Application\*\Installer\setup.exe"
    )
    return Get-ChildItem -Path $patterns -ErrorAction SilentlyContinue | Sort-Object FullName -Unique
}

function Remove-OwnedTree {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Write-Host "    Deleting $Label : $Path"
    & takeown.exe /f "$Path" /r /d y 2>$null | Out-Null
    & icacls.exe "$Path" /grant '*S-1-5-32-544:(F)' /t /c /q 2>$null | Out-Null
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $Path) {
        Write-Host "    [WARNING] Could not fully remove : $Path" -ForegroundColor Yellow
    } else {
        Write-Host "    Deleted        : $Path"
    }
}

function Invoke-InstallerCommand {
    param([Parameter(Mandatory = $true)][string]$CommandLine)
    $trimmed = $CommandLine.Trim()
    $exePath = $null
    $arguments = ''
    if ($trimmed.StartsWith('"')) {
        $endQuote = $trimmed.IndexOf('"', 1)
        if ($endQuote -gt 1) {
            $exePath = $trimmed.Substring(1, $endQuote - 1)
            $arguments = $trimmed.Substring($endQuote + 1).Trim()
        }
    } else {
        $match = [regex]::Match($trimmed, '^(?<exe>\S+\.exe)\s*(?<args>.*)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $exePath = $match.Groups['exe'].Value
            $arguments = $match.Groups['args'].Value.Trim()
        }
    }
    if (-not $exePath) { throw "Unable to parse installer command line: $CommandLine" }
    if (-not (Test-Path -LiteralPath $exePath)) { throw "Installer not found: $exePath" }
    Start-Process -FilePath $exePath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
}

# --- Main ---

$webView2Installed = Test-WebView2Installed
if (-not $webView2Installed) {
    Write-Host "    WebView2 Runtime not found (already removed)." -ForegroundColor Gray
    return
}

Write-Host "    Looking for Microsoft Edge WebView2 Runtime..."

# Kill lingering processes
Get-Process -Name @('msedgewebview2', 'MicrosoftEdgeUpdate', 'widgets') -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

# Step 1: Try uninstall via registered uninstaller
$webView2Info = Get-WebView2UninstallInfo
if ($webView2Info) {
    $commandLine = $webView2Info.UninstallString
    if ($commandLine -notmatch '(?i)--force-uninstall') { $commandLine += ' --force-uninstall' }
    Write-Host "    Launching WebView2 uninstall..."
    try {
        $proc = Invoke-InstallerCommand -CommandLine $commandLine
        Write-Host "    Exit code      : $($proc.ExitCode)"
        & shutdown.exe /a 2>$null
    } catch {
        Write-Host "    [WARNING] WebView2 uninstall hit an error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Step 2: Fallback via setup.exe candidates
if (Test-WebView2Installed) {
    foreach ($setup in Get-WebView2SetupCandidates) {
        $scope = if ($setup.FullName -like "$env:LOCALAPPDATA*") { '--user-level' } else { '--system-level' }
        $commandLine = "`"$($setup.FullName)`" --uninstall --force-uninstall $scope --verbose-logging --msedgewebview"
        Write-Host "    Fallback setup : $($setup.FullName)"
        $proc = Invoke-InstallerCommand -CommandLine $commandLine
        Write-Host "    Exit code      : $($proc.ExitCode)"
        & shutdown.exe /a 2>$null
        if (-not (Test-WebView2Installed)) { break }
    }
}

# Step 3: DISM unlock + AppX removal
try {
    $packages = @(Get-AppxPackage -AllUsers -Name '*Win32WebViewHost*' -ErrorAction Stop)
    foreach ($pkg in $packages) {
        Write-Host "    AppX found     : $($pkg.PackageFullName)"
        $dismArgs = "/online /set-nonremovableapppolicy /packagefamily:$($pkg.PackageFamilyName) /nonremovable:0"
        $dismProc = Start-Process -FilePath dism.exe -ArgumentList $dismArgs -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
        if ($dismProc.ExitCode -eq 0) { Write-Host "    DISM unlock    : OK" }
        else { Write-Host "    DISM unlock    : exit $($dismProc.ExitCode)" -ForegroundColor Yellow }

        try {
            $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Win32WebViewHost*' }
            foreach ($p in $prov) {
                Remove-AppxProvisionedPackage -PackageName $p.PackageName -Online -AllUsers -ErrorAction SilentlyContinue | Out-Null
                Write-Host "    Deprovisioned  : $($p.PackageName)"
            }
        } catch {}

        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Host "    AppX removed   : $($pkg.PackageFullName)"
        } catch {
            Write-Host "    AppX removal   : still registered (system app or pending reboot)" -ForegroundColor DarkGray
        }

        $installLocation = [string]$pkg.InstallLocation
        if ($installLocation) { Remove-OwnedTree -Path $installLocation -Label 'WebView2 AppX files' }
    }
} catch {}

# Step 4: Direct file deletion
foreach ($dir in $webView2Roots) {
    Remove-OwnedTree -Path $dir -Label 'WebView2 files'
}

# Step 5: Registry cleanup
foreach ($key in $webView2ClientKeys) {
    if (Test-Path $key) { Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "    Reg removed    : $key" }
}
foreach ($key in @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView'
)) {
    if (Test-Path $key) { Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "    Reg removed    : $key" }
}
Unregister-ScheduledTask -TaskName 'MicrosoftEdgeUpdate*' -Confirm:$false -ErrorAction SilentlyContinue

# Step 6: Apply reinstall block
$allHives = @('HKLM:\SOFTWARE', 'HKLM:\SOFTWARE\WOW6432Node', 'HKCU:\Software')
foreach ($sw in $allHives) {
    $euPath = "$sw\Microsoft\EdgeUpdate"
    if (-not (Test-Path $euPath)) { New-Item -Path $euPath -Force | Out-Null }
    Set-ItemProperty -Path $euPath -Name "Install$webView2AppGuid" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $euPath -Name "Update$webView2AppGuid" -Value 2 -Type DWord -Force
}
if (-not (Test-Path $webView2BlockPolicyPath)) { New-Item -Path $webView2BlockPolicyPath -Force | Out-Null }
Set-ItemProperty -Path $webView2BlockPolicyPath -Name $webView2InstallPolicy -Value 0 -Type DWord -Force
Set-ItemProperty -Path $webView2BlockPolicyPath -Name $webView2UpdatePolicy -Value 0 -Type DWord -Force

# Final check
$presenceEvidence = @(Get-WebView2PresenceEvidence)
if ($presenceEvidence.Count -gt 0) {
    Write-Host "    [WARNING] WebView2 Runtime is still present after the uninstall flow." -ForegroundColor Yellow
    foreach ($item in ($presenceEvidence | Select-Object -First 3)) { Write-Host "              Still detected via: $item" -ForegroundColor Yellow }
    if ($presenceEvidence.Count -gt 3) { Write-Host "              (+$($presenceEvidence.Count - 3) more evidence point(s))" -ForegroundColor Yellow }
    Write-Host "              You may need to retry after a reboot." -ForegroundColor Yellow
    throw 'WebView2 uninstall incomplete.'
}

Write-Host "    WebView2 removed: Microsoft Edge WebView2 Runtime is no longer detected."
Write-Host "    Reinstall block: EdgeUpdate policy values applied."
Write-Host "    If Start menu search breaks, run Tools\fix_webview2.bat to restore." -ForegroundColor Yellow
