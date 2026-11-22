# 還原

## 還原基本安裝（解除安裝 UYAS X、恢復原廠啟動）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\90-restore.ps1 -Device 192.168.1.50:5555 -DryRun
powershell -ExecutionPolicy Bypass -File scripts\90-restore.ps1 -Device 192.168.1.50:5555
```

會 pm enable 原廠 StartupActivity 並解除安裝 UYAS X。**UYAS X 的設定與 Spotify 登入會一併清除。**
重開機後預設桌面會回到原廠。

## 還原 WebView

```powershell
powershell -ExecutionPolicy Bypass -File scripts\90-restore.ps1 -Device 192.168.1.50:5555 -WebView
```

需要 backup\webview-stock\（由 03-upgrade-webview.ps1 在同一台電腦建立）。腳本會先驗證備份雜湊，
再寫回 /system/app/webview 並重開機，最後應顯示 61.x。

## 手動還原指令

```powershell
adb shell su 0 pm enable com.uyas.speaker.launcher/.StartupActivity
adb uninstall com.uyas.speaker.launcherx
```

## 轉讓或出售喇叭前

- 在 UYAS X 登出 Spotify，並清除設定裡的 YouTube 金鑰與 Client ID（或直接解除安裝）。
- 本機型無線 adb 沒有驗證，同網路的人都能控制喇叭。若不想保留，可進 Console 把 ADB Wireless 關閉。