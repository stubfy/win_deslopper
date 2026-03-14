# opt_edge_uninstall.ps1 - Microsoft Edge uninstall (WinUtil-aligned method)
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
$edgeClientStateKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
)
$edgeUpdateDevKeys = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev'
    'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev'
)
$policyFile = Join-Path $env:SystemRoot 'System32\IntegratedServicesRegionPolicySet.json'
$policyBackup = "$policyFile.win_deslopper.bak"

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

function Get-EdgeUninstallMetadata {
    foreach ($key in $edgeClientStateKeys) {
        if (-not (Test-Path $key)) { continue }

        try {
            $props = Get-ItemProperty -Path $key -ErrorAction Stop
        } catch {
            continue
        }

        if ($props.UninstallString) {
            $filePath = ([string]$props.UninstallString).Trim('"')
            if (Test-Path $filePath) {
                return [PSCustomObject]@{
                    Key       = $key
                    FilePath  = $filePath
                    Arguments = [string]$props.UninstallArguments
                }
            }
        }
    }

    foreach ($root in $edgeRoots) {
        if (-not (Test-Path $root)) { continue }

        $setup = Get-ChildItem -Path (Join-Path $root '*\Installer\setup.exe') -ErrorAction SilentlyContinue |
                 Sort-Object { [version]($_.Directory.Parent.Name) } -Descending |
                 Select-Object -First 1
        if ($setup) {
            return [PSCustomObject]@{
                Key       = $null
                FilePath  = $setup.FullName
                Arguments = '--uninstall --msedge --system-level --force-uninstall --delete-profile'
            }
        }
    }

    return $null
}

function Get-JsonFileAclWritable {
    param([Parameter(Mandatory = $true)][string]$Path)

    $originalAcl = Get-Acl -Path $Path
    $adminAccount = ([System.Security.Principal.SecurityIdentifier]'S-1-5-32-544').Translate([System.Security.Principal.NTAccount]).Value

    $tempAcl = New-Object System.Security.AccessControl.FileSecurity
    $tempAcl.SetSecurityDescriptorSddlForm($originalAcl.Sddl)
    $tempAcl.SetOwner([System.Security.Principal.NTAccount]$adminAccount)
    $tempAcl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($adminAccount, 'FullControl', 'Allow')))
    Set-Acl -Path $Path -AclObject $tempAcl

    return $originalAcl
}

function Restore-JsonFileAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Acl
    )

    if (Test-Path $Path) {
        Set-Acl -Path $Path -AclObject $Acl -ErrorAction SilentlyContinue
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

Write-Host "    Looking for Microsoft Edge..."

if (-not (Test-EdgeInstalled)) {
    Write-Host "    Edge not found (already removed or non-standard path)." -ForegroundColor Gray
    return
}

$metadata = Get-EdgeUninstallMetadata
if (-not $metadata) {
    Write-Host "    Unable to locate Edge uninstall metadata." -ForegroundColor Yellow
    return
}

$originalNoRemove = @{}
$policyAcl = $null
$policyPatched = $false

try {
    foreach ($procName in @('msedge', 'MicrosoftEdgeUpdate', 'widgets', 'msedgewebview2')) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    foreach ($key in $edgeUpdateDevKeys) {
        if (-not (Test-Path $key)) {
            New-Item -Path $key -Force | Out-Null
        }

        # WinUtil uses an empty string value here, not a DWORD.
        Set-ItemProperty -Path $key -Name AllowUninstall -Value '' -Type String -Force
    }

    foreach ($key in $edgeUninstallKeys) {
        if (-not (Test-Path $key)) { continue }

        try {
            $props = Get-ItemProperty -Path $key -ErrorAction Stop
            if ($null -ne $props.NoRemove) {
                $originalNoRemove[$key] = [int]$props.NoRemove
            }
        } catch {}

        Set-ItemProperty -Path $key -Name NoRemove -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $policyBackup) {
        Remove-Item -Path $policyBackup -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $policyFile) {
        $policyAcl = Get-JsonFileAclWritable -Path $policyFile
        Copy-Item -Path $policyFile -Destination $policyBackup -Force

        $policyJson = Get-Content -Path $policyFile -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($policy in $policyJson.policies) {
            if ($policy.guid -eq '{1bca2783-0de6-4269-b2b2-4bfdd4e492e5}') {
                $policy.defaultState = 'enabled'
            }
        }

        $policyJson | ConvertTo-Json -Depth 100 | Set-Content -Path $policyFile -Encoding UTF8
        $policyPatched = $true
        Write-Host "    Policy file   : Edge uninstall region gate patched"
    }

    if ($metadata.Key) {
        Remove-ItemProperty -Path $metadata.Key -Name experiment_control_labels -ErrorAction SilentlyContinue
    }

    $arguments = [string]$metadata.Arguments
    if ($arguments -notmatch '(?i)--force-uninstall') {
        $arguments = ($arguments + ' --force-uninstall').Trim()
    }
    if ($arguments -notmatch '(?i)--delete-profile') {
        $arguments = ($arguments + ' --delete-profile').Trim()
    }

    # WinUtil uses cmd /c start /wait so the Edge bootstrapper behaves like an interactive uninstall.
    $escaped = '"' + $metadata.FilePath.Replace('"', '\"') + '" ' + $arguments
    Write-Host "    Launching Edge uninstall..."
    $proc = Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" `
        -ArgumentList "/c start /wait `"EdgeUninstall`" $escaped" `
        -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
    Write-Host "    Exit code      : $($proc.ExitCode)"
} catch {
    Write-Host "    [WARNING] Edge uninstall hit an error: $($_.Exception.Message)" -ForegroundColor Yellow
} finally {
    if ($policyPatched -and (Test-Path $policyBackup)) {
        Copy-Item -Path $policyBackup -Destination $policyFile -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $policyBackup -Force -ErrorAction SilentlyContinue
    }

    if ($policyAcl) {
        Restore-JsonFileAcl -Path $policyFile -Acl $policyAcl
    }

    foreach ($key in $originalNoRemove.Keys) {
        Set-ItemProperty -Path $key -Name NoRemove -Value $originalNoRemove[$key] -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

if (Test-EdgeInstalled) {
    Write-Host "    [WARNING] Edge is still present after the WinUtil-aligned uninstall flow." -ForegroundColor Yellow
    Write-Host "              The uninstall gate was opened correctly; retrying from Settings may now work." -ForegroundColor Yellow
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
