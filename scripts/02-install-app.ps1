<#
.SYNOPSIS
  Install UYAS X, make it the default HOME, and disable the vendor StartupActivity.
  Touches /data only (no /system changes). Fully reversible with 90-restore.ps1.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\02-install-app.ps1 -Device 192.168.1.50:5555 -DryRun
#>
param(
    [Parameter(Mandatory=$true)][string]$Device,
    [string]$Adb,
    [switch]$DryRun,
    [switch]$Yes
)
. "$PSScriptRoot\common.ps1"
$root = Split-Path $PSScriptRoot -Parent
$apk  = Get-ChildItem "$root\apk" -Filter 'uyasx-*.apk' | Sort-Object Name | Select-Object -Last 1
if (-not $apk) { throw "No uyasx-*.apk found in $root\apk. Download it from the GitHub Releases page of this repo into that folder (see README)." }

function Invoke-Act { param([string]$Desc, [scriptblock]$Act)
    if ($DryRun) { Write-Host "  [dry-run] $Desc" -ForegroundColor DarkGray; return $null }
    Write-Host "  $Desc"
    & $Act
}

Connect-Device -Device $Device -Adb $Adb
Write-Step 'Pre-check'
& "$PSScriptRoot\01-precheck.ps1" -Device $Device -Adb $Global:UX_ADB
if ($LASTEXITCODE -ne 0) { throw 'Pre-check failed. Nothing was changed.' }

Write-Step 'Verify APK checksum'
$sums = Get-Content "$root\apk\SHA256SUMS.txt" | Where-Object { $_ -match [regex]::Escape($apk.Name) }
if (-not $sums) { throw "No checksum line for $($apk.Name) in SHA256SUMS.txt" }
$expect = ($sums -split '\s+')[0].ToLower()
$have = Get-LocalSha256 $apk.FullName
if ($have -ne $expect) { throw "APK checksum mismatch: $have (expected $expect)" }
Write-Host "  $($apk.Name)  sha256 OK"

Write-Step 'Plan'
Write-Host "  1. adb install -r $($apk.Name)"
Write-Host "  2. cmd package set-home-activity $Global:UX_HOME"
Write-Host "  3. pm disable $Global:UX_STARTUP   (undo: 90-restore.ps1)"
if (-not $DryRun) { Confirm-Continue 'Apply these changes to the speaker?' -Yes:$Yes }

Write-Step 'Install UYAS X'
$out = Invoke-Act 'adb install -r' { Invoke-Adb install -r $apk.FullName }
if (-not $DryRun) {
    Write-Host "  $out"
    if ($out -notmatch 'Success') {
        if ($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match') {
            throw 'A UYAS X build with a different signature is installed. Uninstall it first (this clears its settings): adb uninstall com.uyas.speaker.launcherx'
        }
        throw 'Install failed.'
    }
}

Write-Step 'Set default HOME'
$null = Invoke-Act 'set-home-activity' { Invoke-Adbshell "cmd package set-home-activity $Global:UX_HOME" | Write-Host }

Write-Step 'Disable vendor StartupActivity'
$null = Invoke-Act 'pm disable' { Invoke-Su "pm disable $Global:UX_STARTUP" | Write-Host }

if (-not $DryRun) {
    Write-Step 'Verify'
    $r = Invoke-Adbshell 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'
    Write-Host ("  default HOME -> " + (($r -split "`n") | Select-Object -Last 1))
    Write-Host '  Press the Home key on the speaker, or run:  adb shell am start -n com.uyas.speaker.launcherx/.MainActivity'
}
Write-Host "`nDone." -ForegroundColor Green