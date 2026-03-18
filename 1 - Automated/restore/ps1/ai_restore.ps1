# restore\ai_restore.ps1 - Remove AI / Recall / Copilot policies

$paths = @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
    'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\ChatIcon'
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
    # Additional Copilot keys
    'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot\BingChat'
    # Paint and Notepad AI settings (user-level, safe to delete entire key)
    'HKCU:\Software\Microsoft\MSPaint\Settings'
    'HKCU:\Software\Microsoft\Notepad\Settings'
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "    [REMOVED]   $path"
    } else {
        Write-Host "    [NOT FOUND] $path" -ForegroundColor Gray
    }
}

# Remove individual values (shared keys - do not delete the entire path)
$values = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\Shell\Copilot';             Name = 'IsCopilotAvailable'  }
    @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsCopilot'; Name = 'AllowCopilotRuntime' }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';           Name = 'EnableCdp'           }
    # Click to Do user-level key (HKCU shared path - remove value only)
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ClickToDo'; Name = 'DisableClickToDo' }
    # Edge AI features (shared key - remove individual values only, not the entire key)
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'CopilotCDPPageContext'               }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'CopilotPageContext'                  }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'HubsSidebarEnabled'                  }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeEntraCopilotPageContext'          }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'EdgeHistoryAISearchEnabled'           }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'ComposeInlineEnabled'                }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'GenAILocalFoundationalModelSettings' }
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'NewTabPageBingChatEnabled'           }
)
foreach ($v in $values) {
    if (Test-Path $v.Path) {
        Remove-ItemProperty -Path $v.Path -Name $v.Name -ErrorAction SilentlyContinue
        Write-Host "    [REMOVED]   $($v.Name)  ($($v.Path))"
    }
}

# Remove the Copilot shell extension block
$blockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
$clsid = "{CB5571B1-A131-4C41-BFEF-57696FCE7CA2}"
if ((Test-Path $blockedPath) -and (Get-ItemProperty -Path $blockedPath -Name $clsid -ErrorAction SilentlyContinue)) {
    Remove-ItemProperty -Path $blockedPath -Name $clsid -ErrorAction SilentlyContinue
    Write-Host "    [REMOVED]   Copilot shell extension unblocked"
}
