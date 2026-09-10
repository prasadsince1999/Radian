$adb = 'C:\Users\kpr25\AppData\Local\Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    $found = Get-Command adb -ErrorAction SilentlyContinue
    if ($found) { $adb = $found.Source }
}

Write-Host 'Capturing phone screen...' -ForegroundColor Cyan
$tmp = Join-Path $env:TEMP 'phone_snap.png'

cmd /c "`"$adb`" exec-out screencap -p > `"$tmp`""

if (Test-Path $tmp) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    try {
        $img = [System.Drawing.Image]::FromFile($tmp)
        [System.Windows.Forms.Clipboard]::SetImage($img)
        $img.Dispose()
        Write-Host 'Screen copied to clipboard! Just press Ctrl+V in Antigravity.' -ForegroundColor Green
    } catch {
        Write-Host 'Could not copy to clipboard.' -ForegroundColor Red
    }
} else {
    Write-Host 'Could not capture phone screen.' -ForegroundColor Red
}
