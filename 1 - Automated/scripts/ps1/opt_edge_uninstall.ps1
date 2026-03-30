# opt_edge_uninstall.ps1 - Microsoft Edge uninstall
# OPTIONAL - called only if confirmed by the user in run_all.ps1
#
# Uninstall strategy (WinUtil method, Jan 2026+):
#   Microsoft protects Chromium Edge from being uninstalled by its own setup.exe
#   using two mechanisms:
#     1. The uninstall registry key has a NoRemove=1 flag.
#     2. The setup.exe checks for the presence of the legacy UWP Edge binary
#        (C:\Windows\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\MicrosoftEdge.exe)
#        before allowing itself to proceed.
#
#   This script:
#     a. Clears NoRemove and experiment_control_labels flags from the uninstall key.
#     b. Creates AllowUninstall='' in EdgeUpdateDev registry keys to unlock removal.
#     c. Creates a zero-byte dummy file at the legacy UWP Edge path -- Edge's
#        Chromium installer interprets this as "legacy UWP Edge is present" and
#        allows itself to be uninstalled. The dummy file is intentionally left in
#        place after removal (same behavior as WinUtil); opt_edge_restore.ps1 deletes
#        it during rollback.
#     d. Attempts MSI-based uninstall, then setup.exe --force-uninstall, then
#        enumerates all setup.exe candidates as a fallback.
#
# WebView2 Runtime is NOT touched by this script. See opt_webview2_uninstall.ps1
# for optional WebView2 removal (separate step, default off in run_all).
#
# Rollback: restore\opt_edge_restore.ps1 reinstalls Edge via winget.

$edgeRoots = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"
    "$env:ProgramFiles\Microsoft\Edge\Application"
    "$env:LOCALAPPDATA\Microsoft\Edge\Application"
    # EdgeCore split-install layout introduced in recent Windows 11 builds:
    # Microsoft moved versioned binaries (msedge.exe) out of Edge\Application
    # into a sibling EdgeCore\ directory, leaving Edge\Application empty/absent.
    "${env:ProgramFiles(x86)}\Microsoft\EdgeCore"
    "$env:ProgramFiles\Microsoft\EdgeCore"
    "$env:LOCALAPPDATA\Microsoft\EdgeCore"
)
$edgeUninstallKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
)
$edgeUpdateDevKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev'
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev'
)
$edgeUpdateRoots = @(
    "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate"
    "$env:ProgramFiles\Microsoft\EdgeUpdate"
    "$env:LOCALAPPDATA\Microsoft\EdgeUpdate"
)
$dummyEdgePath = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
$dummyEdgeExe  = Join-Path $dummyEdgePath 'MicrosoftEdge.exe'

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

function Test-EdgeInstalled {
    return (@(Get-EdgePresenceEvidence).Count -gt 0)
}

function Get-EdgeUninstallInfo {
    foreach ($key in $edgeUninstallKeys) {
        if (-not (Test-Path $key)) { continue }

        try {
            $props = Get-ItemProperty -Path $key -ErrorAction Stop
        } catch {
            continue
        }

        if ($props.UninstallString) {
            return [PSCustomObject]@{
                Key             = $key
                UninstallString = [string]$props.UninstallString
            }
        }
    }

    return $null
}

function Get-EdgeSetupCandidates {
    $patterns = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\*\Installer\setup.exe"
        "$env:ProgramFiles\Microsoft\Edge\Application\*\Installer\setup.exe"
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\*\Installer\setup.exe"
        # EdgeCore split-install layout
        "${env:ProgramFiles(x86)}\Microsoft\EdgeCore\*\Installer\setup.exe"
        "$env:ProgramFiles\Microsoft\EdgeCore\*\Installer\setup.exe"
        "$env:LOCALAPPDATA\Microsoft\EdgeCore\*\Installer\setup.exe"
    )

    return Get-ChildItem -Path $patterns -ErrorAction SilentlyContinue |
        Sort-Object FullName -Unique
}

function Get-EdgePresenceEvidence {
    $evidence = [System.Collections.Generic.List[string]]::new()

    foreach ($root in $edgeRoots) {
        if (-not (Test-Path $root)) { continue }

        if (Test-Path (Join-Path $root 'msedge.exe')) {
            $evidence.Add("launcher under $root")
        }

        $exe = Get-ChildItem -Path $root -Filter 'msedge.exe' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($exe) {
            $evidence.Add("binary $($exe.FullName)")
        }
    }

    foreach ($root in $edgeUpdateRoots) {
        if (Test-Path (Join-Path $root 'MicrosoftEdgeUpdate.exe')) {
            $evidence.Add("update files under $root")
        }
    }

    foreach ($setup in Get-EdgeSetupCandidates) {
        $evidence.Add("installer $($setup.FullName)")
    }

    foreach ($key in Get-EdgeClientKeys) {
        $evidence.Add("client key $key")
    }

    if (Get-UninstallEntryByName -DisplayNamePattern 'Microsoft Edge*') {
        $evidence.Add('uninstall entry Microsoft Edge')
    }

    return @($evidence | Select-Object -Unique)
}


function Uninstall-MsiexecAppByName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $apps = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $Name -and $_.UninstallString -match 'MsiExec\.exe' }

    foreach ($app in $apps) {
        Write-Host "    MSI uninstall : $($app.DisplayName)"
        Start-Process -FilePath msiexec.exe -ArgumentList "/X$($app.PSChildName) /quiet" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
}

function Remove-EdgeShortcuts {
    $shortcutPaths = @(
        (Join-Path $env:PUBLIC        'Desktop\Microsoft Edge.lnk')
        (Join-Path $env:USERPROFILE   'Desktop\Microsoft Edge.lnk')
        (Join-Path $env:ProgramData   'Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk')
        (Join-Path $env:APPDATA       'Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk')
        (Join-Path $env:APPDATA       'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk')
    )

    foreach ($path in $shortcutPaths) {
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            Write-Host "    Shortcut removed: $path"
        }
    }
}

function Get-EdgeClientKeys {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\*'
        'HKCU:\Software\Microsoft\EdgeUpdate\Clients\*'
    )

    return @(Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.name -in @('Microsoft Edge', 'Microsoft Edge Update') } |
        Select-Object -ExpandProperty PSPath -Unique)
}

function Remove-RegistryKeys {
    param([Parameter(Mandatory = $true)][string[]]$Keys)

    foreach ($key in $Keys | Select-Object -Unique) {
        if (-not $key) { continue }
        if (Test-Path -LiteralPath $key) {
            Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    Reg removed    : $key"
        }
    }
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

    if (-not $exePath) {
        throw "Unable to parse installer command line: $CommandLine"
    }
    if (-not (Test-Path -LiteralPath $exePath)) {
        throw "Installer not found: $exePath"
    }

    Start-Process -FilePath $exePath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
}

function Uninstall-Edge {
    $uninstallInfo = Get-EdgeUninstallInfo
    $msiChecked = $false
    $edgeExitCodes = [System.Collections.Generic.List[int]]::new()

    try {
        foreach ($key in $edgeUpdateDevKeys) {
            if (-not (Test-Path $key)) {
                New-Item -Path $key -Force | Out-Null
            }

            Set-ItemProperty -Path $key -Name AllowUninstall -Value '' -Type String -Force
        }

        foreach ($key in $edgeUninstallKeys) {
            if (Test-Path $key) {
                Set-ItemProperty -Path $key -Name NoRemove -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
        }

        if ($uninstallInfo) {
            Remove-ItemProperty -Path $uninstallInfo.Key -Name experiment_control_labels -ErrorAction SilentlyContinue
        }

        # Create a dummy legacy UWP Edge file to unlock the Chromium Edge uninstaller (WinUtil method)
        if (-not (Test-Path $dummyEdgePath)) {
            New-Item -Path $dummyEdgePath -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path $dummyEdgeExe)) {
            New-Item -Path $dummyEdgeExe -ItemType File -Force | Out-Null
            Write-Host "    Dummy UWP file : created to unlock Edge uninstaller"
        }

        Uninstall-MsiexecAppByName -Name 'Microsoft Edge'
        $msiChecked = $true

        if ($uninstallInfo -and (Test-EdgeInstalled)) {
            $commandLine = $uninstallInfo.UninstallString
            if ($commandLine -notmatch '(?i)--force-uninstall') {
                $commandLine += ' --force-uninstall'
            }
            if ($commandLine -notmatch '(?i)--delete-profile') {
                $commandLine += ' --delete-profile'
            }

            Write-Host "    Launching Edge uninstall..."
            $proc = Invoke-InstallerCommand -CommandLine $commandLine
            $edgeExitCodes.Add([int]$proc.ExitCode)
            Write-Host "    Exit code      : $($proc.ExitCode)"
            # Cancel any pending OS reboot that setup.exe may have scheduled so the
            # parent script can continue to the Defender prompt at the end.
            & shutdown.exe /a 2>$null
        }

        if (Test-EdgeInstalled) {
            foreach ($setup in Get-EdgeSetupCandidates) {
                $scope = if ($setup.FullName -like "$env:LOCALAPPDATA*") { '--user-level' } else { '--system-level' }
                $commandLine = "`"$($setup.FullName)`" --uninstall --force-uninstall $scope --verbose-logging --delete-profile --msedge --channel=stable"

                Write-Host "    Fallback setup : $($setup.FullName)"
                $proc = Invoke-InstallerCommand -CommandLine $commandLine
                $edgeExitCodes.Add([int]$proc.ExitCode)
                Write-Host "    Exit code      : $($proc.ExitCode)"
                & shutdown.exe /a 2>$null

                if (-not (Test-EdgeInstalled)) {
                    break
                }
            }
        }

        Get-Process -Name @('msedge', 'MicrosoftEdgeUpdate', 'widgets', 'msedgewebview2') -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue

        foreach ($dir in $edgeRoots) {
            Remove-OwnedTree -Path $dir -Label 'Edge files'
        }
        foreach ($dir in $edgeUpdateRoots) {
            Remove-OwnedTree -Path $dir -Label 'EdgeUpdate files'
        }

        Remove-RegistryKeys -Keys $edgeUninstallKeys
        $clientKeys = @(Get-EdgeClientKeys)
        if ($clientKeys.Count -gt 0) { Remove-RegistryKeys -Keys $clientKeys }
        Unregister-ScheduledTask -TaskName 'MicrosoftEdgeUpdate*' -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        Write-Host "    [WARNING] Edge uninstall hit an error: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if (Test-EdgeInstalled) {
        Write-Host "    [WARNING] Edge is still present after the uninstall flow." -ForegroundColor Yellow
        if (-not $msiChecked) {
            Write-Host "              MSI-based uninstall was not attempted." -ForegroundColor Yellow
        }
        if ($edgeExitCodes.Count -gt 0 -and ($edgeExitCodes | Select-Object -Unique) -contains 0) {
            Write-Host "              Installer exited 0, but Edge is still detected." -ForegroundColor Yellow
        }

        $presenceEvidence = @(Get-EdgePresenceEvidence)
        foreach ($item in ($presenceEvidence | Select-Object -First 3)) {
            Write-Host "              Still detected via: $item" -ForegroundColor Yellow
        }
        if ($presenceEvidence.Count -gt 3) {
            Write-Host "              (+$($presenceEvidence.Count - 3) more evidence point(s))" -ForegroundColor Yellow
        }

        Write-Host "              You can retry removal manually from Settings > Apps." -ForegroundColor Yellow
        return $false
    }

    $edgeUpdatePath = 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate'
    if (-not (Test-Path $edgeUpdatePath)) {
        New-Item -Path $edgeUpdatePath -Force | Out-Null
    }
    Set-ItemProperty -Path $edgeUpdatePath -Name 'DoNotUpdateToEdgeWithChromium' -Value 1 -Type DWord -ErrorAction SilentlyContinue

    Write-Host "    Edge removed   : Microsoft Edge is no longer detected."
    Write-Host "    Reinstall block: best-effort EdgeUpdate registry key applied."
    return $true
}


foreach ($procName in @('msedge', 'MicrosoftEdgeUpdate', 'widgets')) {
    Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Stop EdgeUpdate services so they cannot re-protect files or restart processes during uninstall
foreach ($svcName in @('edgeupdate', 'edgeupdatem')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "    Service stopped: $svcName"
    }
}

# Apply EdgeUpdate blocking policies early so they survive a reboot triggered by Edge's setup.exe.
# If setup.exe reboots the system mid-uninstall, these policies prevent Edge/WebView2 from
# reinstalling on the next boot before the script can complete.
$edgeUpdatePath = 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate'
if (-not (Test-Path $edgeUpdatePath)) { New-Item -Path $edgeUpdatePath -Force | Out-Null }
Set-ItemProperty -Path $edgeUpdatePath -Name 'DoNotUpdateToEdgeWithChromium' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

foreach ($key in $edgeUpdateDevKeys) {
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name AllowUninstall -Value '' -Type String -Force -ErrorAction SilentlyContinue
}

Write-Host "    Reinstall block : EdgeUpdate policies applied."

$edgeInstalled = Test-EdgeInstalled

if (-not $edgeInstalled) {
    Write-Host "    Edge not found (already removed or non-standard path)." -ForegroundColor Gray
    return
}

Write-Host "    Looking for Microsoft Edge..."
$edgeOk = Uninstall-Edge

Remove-EdgeShortcuts

Write-Host "    WebView2 Runtime: preserved (required by Start menu search on some machines)."

if (-not $edgeOk) {
    throw 'Edge uninstall incomplete.'
}

