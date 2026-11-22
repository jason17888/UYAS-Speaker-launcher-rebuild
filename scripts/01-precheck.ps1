<#
.SYNOPSIS
  Read-only compatibility check. Changes nothing on the device.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\01-precheck.ps1 -Device 192.168.1.50:5555
#>
param(
    [Parameter(Mandatory=$true)][string]$Device,
    [string]$Adb
)
. "$PSScriptRoot\common.ps1"

$fail = 0; $warn = 0
function Check { param([string]$Name, [bool]$Ok, [string]$Detail, [switch]$Soft)
    if ($Ok) { Write-Host ("[ OK ] {0,-28} {1}" -f $Name, $Detail) -ForegroundColor Green }
    elseif ($Soft) { $script:warn++; Write-Host ("[WARN] {0,-28} {1}" -f $Name, $Detail) -ForegroundColor Yellow }
    else { $script:fail++; Write-Host ("[FAIL] {0,-28} {1}" -f $Name, $Detail) -ForegroundColor Red }
}

Connect-Device -Device $Device -Adb $Adb
Write-Host "adb: $Global:UX_ADB   device: $Device`n"

$e = $Global:UX_EXPECT
$model = Invoke-Adbshell 'getprop ro.product.model'
$dev   = Invoke-Adbshell 'getprop ro.product.device'
$sdk   = Invoke-Adbshell 'getprop ro.build.version.sdk'
$btype = Invoke-Adbshell 'getprop ro.build.type'
$fp    = Invoke-Adbshell 'getprop ro.build.fingerprint'
Check 'model'        ($model -eq $e.Model)     "$model (expect $($e.Model))"
Check 'device'       ($dev   -eq $e.Device)    "$dev (expect $($e.Device))"
Check 'android sdk'  ($sdk   -eq $e.Sdk)       "$sdk (expect $($e.Sdk))"
Check 'build type'   ($btype -eq $e.BuildType) "$btype (expect $($e.BuildType))"
Check 'fingerprint'  ($fp    -eq $e.Fingerprint) $fp -Soft

$id = Invoke-Adbshell 'su 0 id'
Check 'root (su 0)'  ($id -match 'uid=0\(root\)') ($id.Split("`n")[0])

$pkgs = Invoke-Adbshell 'pm list packages'
foreach ($p in 'com.uyas.speaker.launcher','com.uyas.speaker.bluetooth','com.uyas.speaker.volumecontrol','com.uyas.speaker.voicecontrol') {
    Check "vendor pkg" ($pkgs -match [regex]::Escape("package:$p")) $p
}
$has = $pkgs -match [regex]::Escape("package:$Global:UX_PKG")
Check 'UYAS X installed' $true $(if ($has) { 'already installed (will be updated)' } else { 'not installed yet' })

$wv = Get-WebViewVersion
Check 'webview version' ($null -ne $wv) "$wv  (61.x = stock, 138.x = already upgraded)" -Soft

$sysFree  = Get-FreeKB '/system'
$dataFree = Get-FreeKB '/data'
$needSys  = 262144   # 256 MB: new 245 MB webview is staged next to the old one
$needData = 262144
$wvDone = ($wv -and $wv.StartsWith('138'))
Check '/system free'  ($wvDone -or $sysFree  -ge $needSys)  ("{0} MB (WebView upgrade needs >= 256 MB)" -f [int]($sysFree/1024)) -Soft
Check '/data free'    ($wvDone -or $dataFree -ge $needData) ("{0} MB (WebView upgrade needs >= 256 MB)" -f [int]($dataFree/1024)) -Soft

Write-Host ''
if ($fail -gt 0) {
    Write-Host "RESULT: $fail check(s) failed. Do NOT continue." -ForegroundColor Red
    exit 1
}
if ($warn -gt 0) {
    Write-Host "RESULT: passed with $warn warning(s). Basic install is OK; read warnings before upgrading WebView." -ForegroundColor Yellow
} else {
    Write-Host 'RESULT: all checks passed.' -ForegroundColor Green
}
exit 0