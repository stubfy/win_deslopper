# opt_edge_uninstall.ps1 - Microsoft Edge uninstall (WinUtil dummy-file method)
# OPTIONAL - called only if confirmed by the user in run_all.ps1

$edgeRoots = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"
    "$env:ProgramFiles\Microsoft\Edge\Application"
    "$env:LOCALAPPDATA\Microsoft\Edge\Application"
)
$edgeUninstallKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
)
$edgeUpdateDevKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev'
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev'
)
$dummyEdgePath = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
$dummyEdgeExe  = Join-Path $dummyEdgePath 'MicrosoftEdge.exe'

function Test-EdgeInstalled {
    foreach ($root in $edgeRoots) {
        if (-not (Test-Path $root)) { continue }

        if (Test-Path (Join-Path $root 'msedge.exe')) {
            return $true
        }

        $exe = Get-ChildItem -Path $root -Filter 'msedge.exe' -Recurse -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($exe) {
            return $true
        }
    }

    return $false
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
        "${env:ProgramFiles(x86)}\Microsoft\Edge*\Application\*\Installer\setup.exe"
        "$env:ProgramFiles\Microsoft\Edge*\Application\*\Installer\setup.exe"
        "$env:LOCALAPPDATA\Microsoft\Edge*\Application\*\Installer\setup.exe"
    )

    return Get-ChildItem -Path $patterns -ErrorAction SilentlyContinue |
        Sort-Object FullName -Unique
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
        (Join-Path $env:PUBLIC 'Desktop\Microsoft Edge.lnk')
        (Join-Path $env:USERPROFILE 'Desktop\Microsoft Edge.lnk')
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk')
    )

    foreach ($path in $shortcutPaths) {
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-EdgeUninstallCommand {
    param([Parameter(Mandatory = $true)][string]$CommandLine)

    Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
        -ArgumentList "/c start /wait `"`" $CommandLine" `
        -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
}

Write-Host "    Looking for Microsoft Edge..."

if (-not (Test-EdgeInstalled)) {
    Write-Host "    Edge not found (already removed or non-standard path)." -ForegroundColor Gray
    return
}

$uninstallInfo = Get-EdgeUninstallInfo
$msiChecked = $false

try {
    foreach ($procName in @('msedge', 'MicrosoftEdgeUpdate', 'widgets', 'msedgewebview2')) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

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
        $proc = Invoke-EdgeUninstallCommand -CommandLine $commandLine
        Write-Host "    Exit code      : $($proc.ExitCode)"
    }

    if (Test-EdgeInstalled) {
        foreach ($setup in Get-EdgeSetupCandidates) {
            $scope = if ($setup.FullName -like "$env:LOCALAPPDATA*") { '--user-level' } else { '--system-level' }
            $commandLine = "`"$($setup.FullName)`" --uninstall --force-uninstall $scope --verbose-logging --delete-profile --msedge --channel=stable"

            Write-Host "    Fallback setup : $($setup.FullName)"
            $proc = Invoke-EdgeUninstallCommand -CommandLine $commandLine
            Write-Host "    Exit code      : $($proc.ExitCode)"

            if (-not (Test-EdgeInstalled)) {
                break
            }
        }
    }
} catch {
    Write-Host "    [WARNING] Edge uninstall hit an error: $($_.Exception.Message)" -ForegroundColor Yellow
}

if (Test-EdgeInstalled) {
    Write-Host "    [WARNING] Edge is still present after the uninstall flow." -ForegroundColor Yellow
    if (-not $msiChecked) {
        Write-Host "              MSI-based uninstall was not attempted." -ForegroundColor Yellow
    }
    Write-Host "              You can retry removal manually from Settings > Apps." -ForegroundColor Yellow
} else {
    Remove-EdgeShortcuts

    $edgeUpdatePath = 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate'
    if (-not (Test-Path $edgeUpdatePath)) {
        New-Item -Path $edgeUpdatePath -Force | Out-Null
    }
    Set-ItemProperty -Path $edgeUpdatePath -Name 'DoNotUpdateToEdgeWithChromium' -Value 1 -Type DWord -ErrorAction SilentlyContinue

    Write-Host "    Edge removed   : Microsoft Edge is no longer detected."
    Write-Host "    Reinstall block: best-effort EdgeUpdate registry key applied."
}
