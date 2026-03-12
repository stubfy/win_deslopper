# 17_mouse_accel.ps1 - MarkC mouse acceleration fix (1:1 scaling, auto-detect DPI)
# Detects current display scaling and imports the matching MarkC .reg file.
# Source: http://donewmouseaccel.blogspot.com/2010/03/markc-windows-7-mouse-acceleration-fix.html

$MOUSE_FIX_DIR = Join-Path $PSScriptRoot "mouse_fix"

# Map LogPixels value -> DPI scale percentage
$scaleMap = @{
    96  = '100'
    120 = '125'
    144 = '150'
    168 = '175'
    192 = '200'
    216 = '225'
    240 = '250'
    288 = '300'
    336 = '350'
}

# Detect display scaling from registry (LogPixels not set = 96 = 100%)
$logPixels = 96
try {
    $val = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'LogPixels' -ErrorAction Stop).LogPixels
    $logPixels = [int]$val
} catch {}

$scale = if ($scaleMap.ContainsKey($logPixels)) { $scaleMap[$logPixels] } else { '100' }
Write-Host "    Detected display scaling: $scale% (LogPixels=$logPixels)"

$regFile = Join-Path $MOUSE_FIX_DIR "Windows_10+8.x_MouseFix_ItemsSize=$scale%_Scale=1-to-1_@6-of-11.reg"

if (-not (Test-Path $regFile)) {
    Write-Host "    [WARN] No MarkC fix found for $scale%, falling back to 100%"
    $regFile = Join-Path $MOUSE_FIX_DIR "Windows_10+8.x_MouseFix_ItemsSize=100%_Scale=1-to-1_@6-of-11.reg"
}

if (-not (Test-Path $regFile)) {
    Write-Host "    [ERROR] MarkC fix .reg not found: $regFile" -ForegroundColor Red
    exit 1
}

$result = Start-Process regedit.exe -ArgumentList "/s `"$regFile`"" -Wait -PassThru
if ($result.ExitCode -eq 0) {
    Write-Host "    [OK] MarkC mouse fix applied (scale: $scale%)"
} else {
    Write-Host "    [WARN] regedit exit code: $($result.ExitCode)"
}
