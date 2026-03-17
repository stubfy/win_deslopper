# 07_edge.ps1 - Reserved placeholder
#
# Edge is no longer managed through registry policies in the automated flow.
# The optional Edge handling lives exclusively in opt_edge_uninstall.ps1
# (complete Edge + WebView2 removal) and opt_edge_restore.ps1.

Write-Host "    Edge step skipped: no Edge policies are applied by the pack."
Write-Host "    Use opt_edge_uninstall.ps1 if you want to remove Edge/WebView2."
