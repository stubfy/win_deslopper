#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Remove Microsoft Edge using the vendored WinUtil uninstall flow.

.DESCRIPTION
    Loads the upstream WinUtil function and executes it as-is.
    WebView2 Runtime is not touched by this script.

    Rollback: restore\opt_edge_restore.ps1 reinstalls Edge via winget.
#>

$VendorFunction = Join-Path $PSScriptRoot 'vendor\winutil\Invoke-WinUtilRemoveEdge.ps1'
if (-not (Test-Path -LiteralPath $VendorFunction)) {
    throw "Missing vendored WinUtil function: $VendorFunction"
}

. $VendorFunction
Invoke-WinUtilRemoveEdge

Write-Host 'WebView2 Runtime: preserved (handled separately by opt_webview2_uninstall.ps1).' -ForegroundColor DarkGray
