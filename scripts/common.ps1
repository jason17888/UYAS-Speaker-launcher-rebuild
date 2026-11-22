# common.ps1 - shared helpers.
# ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less files as ANSI.
$ErrorActionPreference = 'Continue'

$Global:UX_EXPECT = @{
    Model       = 'UYAS'
    Device      = 'rk3368'
    Sdk         = '27'
    BuildType   = 'userdebug'
    Fingerprint = 'Sixnology/uyas/rk3368:8.1.0/OPM8.190605.005/155012:userdebug/dev-keys'
}
$Global:UX_PKG       = 'com.uyas.speaker.launcherx'
$Global:UX_HOME      = 'com.uyas.speaker.launcherx/.MainActivity'
$Global:UX_STARTUP   = 'com.uyas.speaker.launcher/.StartupActivity'
$Global:UX_VENDOR_HOME = 'com.uyas.speaker.launcher/.StartupActivity'
$Global:UX_WV_NAME   = 'lineageos-webview-138.0.7204.63.apk'
$Global:UX_WV_SHA256 = '3fe65c631ce9b0f8e573198a783cf8ad1013aef02b83f04e7871952879b599cf'
$Global:UX_WV_URL    = 'https://github.com/panel-assistant/android/releases/download/webview-mirror/lineageos-webview-138.0.7204.63.apk'

function Resolve-Adb {
    param([string]$Adb)
    if ($Adb) {
        if (Test-Path $Adb) { return (Resolve-Path $Adb).Path }
        throw "adb not found at: $Adb"
    }
    $c = Get-Command adb -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    throw 'adb.exe not found. Install Android platform-tools and add it to PATH, or pass -Adb <full path>.'
}

function Connect-Device {
    param([string]$Device, [string]$Adb)
    $Global:UX_ADB = Resolve-Adb $Adb
    $Global:UX_DEV = $Device
    if ($Device -match ':') { $null = & $Global:UX_ADB connect $Device 2>&1 }
    $state = (& $Global:UX_ADB -s $Device get-state 2>&1 | ForEach-Object { "$_" }) -join ''
    if ($state.Trim() -ne 'device') { throw "Device $Device is not reachable (adb state: $state)" }
}

function Invoke-Adb {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $Global:UX_ADB -s $Global:UX_DEV @args 2>&1 | ForEach-Object { "$_" }
    } finally {
        $ErrorActionPreference = $old
    }
    $Global:UX_RC = $LASTEXITCODE
    ($out -join "`n").Trim()
}

function Invoke-Adbshell {
    param([string]$Cmd)
    Invoke-Adb shell $Cmd
}

# Run a command as root. $Cmd must not contain single quotes.
function Invoke-Su {
    param([string]$Cmd)
    Invoke-Adb shell "su 0 sh -c '$Cmd'"
}

function Get-LocalSha256 {
    param([string]$Path)
    (Get-FileHash $Path -Algorithm SHA256).Hash.ToLower()
}

function Get-DeviceSha256 {
    param([string]$Path, [switch]$Root)
    $o = if ($Root) { Invoke-Su "sha256sum $Path" } else { Invoke-Adbshell "sha256sum $Path" }
    ($o -split '\s+')[0].ToLower()
}

function Get-FreeKB {
    param([string]$Path)
    $line = (Invoke-AdbShell "df -k $Path") -split "`n" | Select-Object -Last 1
    $f = $line.Trim() -split '\s+'
    if ($f.Count -ge 4) { return [int64]$f[3] }
    return -1
}

function Get-WebViewVersion {
    $wv = Invoke-AdbShell 'dumpsys webviewupdate'
    if ($wv -match 'Current WebView package \(name, version\): \(([^,]+), ([^)]+)\)') { return $Matches[2].Trim() }
    return $null
}

function Write-Step {
    param([string]$Msg)
    Write-Host "==> $Msg" -ForegroundColor Cyan
}

function Confirm-Continue {
    param([string]$Message, [switch]$Yes)
    if ($Yes) { return }
    $a = Read-Host "$Message  (type YES to continue)"
    if ($a -ne 'YES') { throw 'Aborted by user.' }
}

function Wait-Boot {
    param([int]$TimeoutSec = 300)
    Start-Sleep -Seconds 25
    $end = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $end) {
        $null = & $Global:UX_ADB connect $Global:UX_DEV 2>&1
        $bc = (& $Global:UX_ADB -s $Global:UX_DEV shell 'getprop sys.boot_completed' 2>$null | Out-String).Trim()
        if ($bc -eq '1') { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}