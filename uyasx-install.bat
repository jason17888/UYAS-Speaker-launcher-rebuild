@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title UYAS X installer

rem ---- settings ----
set "APKNAME=uyasx-1.0.0.apk"
set "APKURL=https://github.com/jason17888/UYAS-Speaker-launcher-rebuild/releases/download/v1.0.0/uyasx-1.0.0.apk"
set "PTURL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass"
set "DEV="
set "ADB="
set "BAD=0"
set "BADIP=0"

echo ==================================================
echo   UYAS X installer for UYAS Play speakers
echo ==================================================
echo.
echo This tool modifies your speaker. Read README.md first.
echo Basic install touches /data only. The WebView upgrade touches /system.
echo.

call :find_adb
if not defined ADB goto :end

call :load_device

:menu
echo.
echo --------------------------------------------------
echo   Speaker : %DEV%
echo   adb     : %ADB%
echo --------------------------------------------------
echo   1  Pre-check only (read-only)
echo   2  Install UYAS X - dry run (changes nothing)
echo   3  Install UYAS X
echo   4  WebView 61 to 138 - dry run (changes nothing)
echo   5  WebView 61 to 138 (HIGH RISK, modifies /system)
echo   6  Restore: uninstall UYAS X, re-enable vendor launcher
echo   7  Restore: same as 6, plus put stock WebView back
echo   8  Change speaker address
echo   0  Exit
echo.
set "CH="
set /p "CH=Choose: "
if defined CH ( set "BAD=0" ) else ( set /a BAD+=1 )
if %BAD% GEQ 5 ( echo No input received. Exiting. & goto :end )

if "%CH%"=="1" ( call :run 01-precheck.ps1 & goto :menu )
if "%CH%"=="2" ( call :get_apk && call :run 02-install-app.ps1 -DryRun & goto :menu )
if "%CH%"=="3" ( call :get_apk && call :run 02-install-app.ps1 & goto :menu )
if "%CH%"=="4" ( call :run 03-upgrade-webview.ps1 -DryRun & goto :menu )
if "%CH%"=="5" ( call :run 03-upgrade-webview.ps1 & goto :menu )
if "%CH%"=="6" ( call :run 90-restore.ps1 & goto :menu )
if "%CH%"=="7" ( call :run 90-restore.ps1 -WebView & goto :menu )
if "%CH%"=="8" ( call :ask_device & goto :menu )
if "%CH%"=="0" goto :end
echo Invalid choice.
goto :menu

rem ---- run one powershell script ----
:run
set "SCRIPT=%~1"
shift
echo.
%PS% -File "scripts\%SCRIPT%" -Device "%DEV%" -Adb "%ADB%" %1 %2 %3
echo.
echo (exit code %ERRORLEVEL%)
pause
exit /b 0

rem ---- locate adb, or download platform-tools ----
:find_adb
if defined UYASX_ADB if exist "%UYASX_ADB%" ( set "ADB=%UYASX_ADB%" & exit /b 0 )
for /f "delims=" %%A in ('where adb 2^>nul') do ( set "ADB=%%A" & exit /b 0 )
if exist "tools\platform-tools\adb.exe" ( set "ADB=%CD%\tools\platform-tools\adb.exe" & exit /b 0 )
echo adb was not found on this PC.
echo It can be downloaded from Google: %PTURL%
set "ANS="
set /p "ANS=Download Android platform-tools into the tools folder now? [Y/N]: "
if /i not "%ANS%"=="Y" ( echo Install platform-tools yourself and add it to PATH, then run this again. & pause & exit /b 1 )
if not exist "tools" mkdir "tools"
curl.exe -L --fail -o "tools\platform-tools.zip" "%PTURL%"
if errorlevel 1 ( echo Download failed. & pause & exit /b 1 )
%PS% -Command "Expand-Archive -LiteralPath 'tools\platform-tools.zip' -DestinationPath 'tools' -Force"
del "tools\platform-tools.zip" >nul 2>&1
if exist "tools\platform-tools\adb.exe" ( set "ADB=%CD%\tools\platform-tools\adb.exe" & exit /b 0 )
echo Could not unpack platform-tools.
pause
exit /b 1

rem ---- speaker address (remembered in device.txt) ----
:load_device
if exist "device.txt" set /p "DEV=" < "device.txt"
if defined DEV exit /b 0
call :ask_device
exit /b 0

:ask_device
echo.
echo Enter the speaker IP address, for example 192.168.1.50
echo (Wireless adb must be enabled first, see docs\01-enable-wireless-adb.md)
set "IN="
set /p "IN=Speaker IP: "
if defined IN goto :ip_ok
set /a BADIP+=1
if %BADIP% GEQ 5 ( echo No input received. Exiting. & exit /b 1 )
goto :ask_device
:ip_ok
echo %IN% | find ":" >nul
if errorlevel 1 set "IN=%IN%:5555"
set "DEV=%IN%"
> "device.txt" echo %DEV%
exit /b 0

rem ---- make sure the APK is present (download from Releases) ----
:get_apk
if exist "apk\%APKNAME%" exit /b 0
echo apk\%APKNAME% not found. Downloading from GitHub Releases...
if not exist "apk" mkdir "apk"
curl.exe -L --fail -o "apk\%APKNAME%" "%APKURL%"
if errorlevel 1 ( echo Download failed. Get the APK from the Releases page manually. & del "apk\%APKNAME%" >nul 2>&1 & pause & exit /b 1 )
echo Downloaded. The install script verifies its SHA-256 before using it.
exit /b 0

:end
endlocal