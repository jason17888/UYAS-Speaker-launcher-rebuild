<#
.SYNOPSIS
  Undo changes. Default: uninstall UYAS X, re-enable the vendor StartupActivity.
  -WebView additionally restores the stock WebView 61 from backup\webview-stock.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\90-restore.ps1 -Device 192.168.1.50:5555 -DryRun
#>
param(
    [Parameter(Mandatory=$true)][string]$Device,
    [string]$Adb,
    [switch]$WebView,
    [switch]$DryRun,
    [switch]$Yes
)
. "$PSScriptRoot\common.ps1"
$root   = Split-Path $PSScriptRoot -Parent
$backup = Join-Path $root 'backup\webview-stock'

function Invoke-Act { param([string]$Desc, [scriptblock]$Act)
    if ($DryRun) { Write-Host "  [dry-run] $Desc" -ForegroundColor DarkGray; return $null }
    Write-Host "  $Desc"
    & $Act
}

Connect-Device -Device $Device -Adb $Adb

if ($WebView) {
    if (-not (Test-Path "$backup\webview.apk") -or -not (Test-Path "$backup\SHA256")) {
        throw "No verified WebView backup in $backup. It is created by 03-upgrade-webview.ps1 on the same PC."
    }
    $expect = ((Get-Content "$backup\SHA256" -Raw) -split '\s+')[0].ToLower()
    if ((Get-LocalSha256 "$backup\webview.apk") -ne $expect) { throw 'Backup file is corrupted (checksum mismatch).' }
}

Write-Step 'Plan'
Write-Host '  - pm enable vendor StartupActivity'
Write-Host '  - uninstall UYAS X (clears its settings and Spotify login)'
if ($WebView) { Write-Host '  - restore stock WebView from backup (modifies /system) and reboot' }
if (-not $DryRun) { Confirm-Continue 'Continue?' -Yes:$Yes }

Write-Step 'Vendor launcher'
$null = Invoke-Act 'pm enable StartupActivity' { Invoke-Su "pm enable $Global:UX_STARTUP" | Write-Host }
$null = Invoke-Act 'adb uninstall UYAS X' { Invoke-Adb uninstall $Global:UX_PKG | Write-Host }

if ($WebView) {
    Write-Step 'Restore stock WebView'
    $null = Invoke-Act 'push backup + swap in /system' {
        $null = Invoke-Adb push "$backup\webview.apk" /data/local/tmp/webview-stock.apk
        if ((Get-DeviceSha256 '/data/local/tmp/webview-stock.apk') -ne $expect) { throw 'Transfer checksum mismatch. /system untouched.' }
        if (Test-Path "$backup\oat") { $null = Invoke-Adb push "$backup\oat" /data/local/tmp/webview-stock-oat }
        foreach ($c in @(
            'mount -o remount,rw /system',
            'cp /data/local/tmp/webview-stock.apk /system/app/webview/webview.apk.restore',
            'mv /system/app/webview/webview.apk.restore /system/app/webview/webview.apk',
            'rm -rf /system/app/webview/oat',
            'cp -r /data/local/tmp/webview-stock-oat /system/app/webview/oat',
            'chown -R root:root /system/app/webview',
            'chmod 755 /system/app/webview /system/app/webview/oat /system/app/webview/oat/arm /system/app/webview/oat/arm64',
            'chmod 644 /system/app/webview/webview.apk',
            'restorecon -R /system/app/webview',
            'sync')) { $null = Invoke-Su $c }
        $null = Invoke-Su 'chmod 644 /system/app/webview/oat/arm/* /system/app/webview/oat/arm64/*'
        $null = Invoke-Su 'restorecon -R /system/app/webview'
        $null = Invoke-Su 'mount -o remount,ro /system'
        $null = Invoke-Adbshell 'rm -rf /data/local/tmp/webview-stock.apk /data/local/tmp/webview-stock-oat'
        if ((Get-DeviceSha256 '/system/app/webview/webview.apk' -Root) -ne $expect) { throw 'Restored file checksum mismatch.' }
        Write-Host '    restored and verified, rebooting'
        $null = Invoke-Adbshell 'sync; su 0 reboot'
    }
    if (-not $DryRun) {
        if (Wait-Boot) { Start-Sleep -Seconds 10; Write-Host "  WebView version: $(Get-WebViewVersion)  (expect 61.x)" }
        else { Write-Host '  Speaker did not reconnect yet. Check later: adb shell dumpsys webviewupdate' -ForegroundColor Yellow }
    }
}
Write-Host "`nDone." -ForegroundColor Green