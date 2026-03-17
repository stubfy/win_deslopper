# restore\05_edge.ps1 - Reserved placeholder
#
# 07_edge.ps1 no longer writes any Edge registry policy keys, so there is
# nothing to roll back here. If the optional Edge uninstall was used, the
# matching rollback lives in restore\opt_edge_restore.ps1.

Write-Host "    Edge rollback skipped: 07_edge.ps1 applies no policies."
Write-Host "    Use opt_edge_restore.ps1 only if Edge/WebView2 was uninstalled."
