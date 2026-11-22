<#
.SYNOPSIS
  OPTIONAL and HIGH RISK: replace the system WebView (Chrome 61) with LineageOS WebView 138.
  Modifies /system. The original WebView is backed up to the PC first.
  Needs about 256 MB free on both /system and /data.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\03-upgrade-webview.ps1 -Device 192.168.1.50:5555 -DryRun
#>
param(
    [Parameter(Mandatory=$true)][string]$Device,
    [string]$Adb,
    [string]$WebViewApk,
    [switch]$DryRun,
    [switch]$Yes
)
. "$PSScriptRoot\common.ps1"
$root   = Split-Path $PSScriptRoot -Parent
$cache  = Join-Path $root 'cache'
$backup = Join-Path $root 'backup\webview-stock'
New-Item -ItemType Directory -Force -Path $cache | Out-Null

function Invoke-Act { param([string]$Desc, [scriptblock]$Act)
    if ($DryRun) { Write-Host "  [dry-run] $Desc" -ForegroundColor DarkGray; return $null }
    Write-Host "  $Desc"
    & $Act
}

Connect-Device -Device $Device -Adb $Adb
Write-Step 'Pre-check'
& "$PSScriptRoot\01-precheck.ps1" -Device $Device -Adb $Global:UX_ADB
if ($LASTEXITCODE -ne 0) { throw 'Pre-check failed. Nothing was changed.' }

$ver = Get-WebViewVersion
if ($ver -and $ver.StartsWith('138')) { Write-Host "WebView is already $ver. Nothing to do." -ForegroundColor Green; exit 0 }
if (-not ($ver -and $ver.StartsWith('61'))) { throw "Unexpected WebView version '$ver'. Expected stock 61.x. Aborting." }

$sysFree  = Get-FreeKB '/system'
$dataFree = Get-FreeKB '/data'
if ($sysFree  -lt 262144) { throw ("/system has only {0} MB free (need 256 MB). Aborting." -f [int]($sysFree/1024)) }
if ($dataFree -lt 262144) { throw ("/data has only {0} MB free (need 256 MB). Aborting." -f [int]($dataFree/1024)) }

Write-Step 'Get WebView 138 APK'
if (-not $WebViewApk) { $WebViewApk = Join-Path $cache $Global:UX_WV_NAME }
if (-not (Test-Path $WebViewApk)) {
    Write-Host "  downloading $Global:UX_WV_URL (about 245 MB)"
    if ($DryRun) { Write-Host '  [dry-run] download skipped' -ForegroundColor DarkGray }
    else { & curl.exe -L --fail -o $WebViewApk $Global:UX_WV_URL; if ($LASTEXITCODE -ne 0) { throw 'Download failed.' } }
}
if (Test-Path $WebViewApk) {
    $h = Get-LocalSha256 $WebViewApk
    if ($h -ne $Global:UX_WV_SHA256) { throw "WebView checksum mismatch: $h`nexpected:           $Global:UX_WV_SHA256`nDelete the file and try again." }
    Write-Host '  sha256 OK'
}

Write-Step 'Plan'
Write-Host "  1. back up stock WebView ($ver) to $backup"
Write-Host '  2. push WebView 138 to /data/local/tmp and verify checksum'
Write-Host '  3. remount /system rw, copy next to the old file, verify checksum, rename over it'
Write-Host '  4. remove old oat, fix owner/mode/SELinux label, remount /system ro'
Write-Host '  5. reboot, then confirm WebView version'
Write-Host '  Roll back any time with:  scripts\90-restore.ps1 -Device <ip:port> -WebView'
if (-not $DryRun) { Confirm-Continue 'This modifies /system. Continue?' -Yes:$Yes }

Write-Step '1/5 Backup stock WebView'
$null = Invoke-Act 'adb pull webview.apk + oat' {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    $o = Invoke-Adb pull /system/app/webview/webview.apk "$backup\webview.apk"
    Write-Host "    $(($o -split "`n") | Select-Object -Last 1)"
    $o = Invoke-Adb pull /system/app/webview/oat "$backup\oat"
    Write-Host "    $(($o -split "`n") | Select-Object -Last 1)"
    $local = Get-LocalSha256 "$backup\webview.apk"
    $dev   = Get-DeviceSha256 '/system/app/webview/webview.apk'
    if ($local -ne $dev) { throw 'Backup checksum does not match the device. Aborting before any change.' }
    [IO.File]::WriteAllText("$backup\SHA256", "$local  webview.apk`n")
    Write-Host "    backup verified ($local)"
}

Write-Step '2/5 Stage new WebView on /data'
$null = Invoke-Act 'adb push' {
    $o = Invoke-Adb push $WebViewApk /data/local/tmp/webview138.apk
    Write-Host "    $(($o -split "`n") | Select-Object -Last 1)"
    if ((Get-DeviceSha256 '/data/local/tmp/webview138.apk') -ne $Global:UX_WV_SHA256) {
        $null = Invoke-Adbshell 'rm -f /data/local/tmp/webview138.apk'
        throw 'Staged file checksum mismatch (transfer error). Nothing on /system was changed.'
    }
    Write-Host '    staged file verified'
}

Write-Step '3/5 Copy into /system'
$null = Invoke-Act 'remount rw + cp' {
    $null = Invoke-Su 'mount -o remount,rw /system'
    $null = Invoke-Su 'cp /data/local/tmp/webview138.apk /system/app/webview/webview.apk.new'
    $null = Invoke-Su 'sync'
    if ((Get-DeviceSha256 '/system/app/webview/webview.apk.new' -Root) -ne $Global:UX_WV_SHA256) {
        $null = Invoke-Su 'rm -f /system/app/webview/webview.apk.new'
        $null = Invoke-Su 'mount -o remount,ro /system'
        throw 'Copy on /system failed checksum. Old WebView is untouched.'
    }
    Write-Host '    new file verified on /system'
}

Write-Step '4/5 Swap and fix permissions'
$null = Invoke-Act 'mv / rm oat / chown / chmod / restorecon' {
    foreach ($c in @(
        'mv /system/app/webview/webview.apk.new /system/app/webview/webview.apk',
        'rm -rf /system/app/webview/oat',
        'chown root:root /system/app/webview /system/app/webview/webview.apk',
        'chmod 755 /system/app/webview',
        'chmod 644 /system/app/webview/webview.apk',
        'restorecon -R /system/app/webview',
        'sync')) { $null = Invoke-Su $c }
    $null = Invoke-Adbshell 'rm -f /data/local/tmp/webview138.apk'
    $null = Invoke-Su 'mount -o remount,ro /system'
    if ((Get-DeviceSha256 '/system/app/webview/webview.apk') -ne $Global:UX_WV_SHA256) { throw 'Final checksum mismatch. Run 90-restore.ps1 -WebView.' }
    Write-Host '    done'
}

Write-Step '5/5 Reboot and verify'
if ($DryRun) { Write-Host '  [dry-run] reboot skipped' -ForegroundColor DarkGray; Write-Host "`nDry run finished. Nothing was changed."; exit 0 }
$null = Invoke-Adbshell 'sync; su 0 reboot'
Write-Host '  waiting for the speaker to come back (up to 5 minutes)...'
if (-not (Wait-Boot)) {
    Write-Host 'Speaker did not come back on wireless adb. It may still be booting.' -ForegroundColor Yellow
    Write-Host 'Wait a few minutes, reconnect, and check:  adb shell dumpsys webviewupdate' -ForegroundColor Yellow
    exit 2
}
Start-Sleep -Seconds 10
$new = Get-WebViewVersion
Write-Host "  WebView version: $new"
if ($new -and $new.StartsWith('138')) { Write-Host "`nDone." -ForegroundColor Green }
else { Write-Host "`nVersion is not 138. Roll back with: scripts\90-restore.ps1 -Device $Device -WebView" -ForegroundColor Red; exit 3 }