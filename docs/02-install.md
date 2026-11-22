# 步驟 1 到 2：檢查並安裝 UYAS X

以下都在 **PC** 的專案根目錄執行。把 192.168.1.50:5555 換成你喇叭的位址。

## 0. 下載 APK

到本 repo 的 **Releases** 頁面下載 uyasx-1.0.0.apk，放進專案的 apk 資料夾（與 SHA256SUMS.txt 同一層）。
安裝腳本會自動比對 SHA256SUMS.txt 內的校驗值，不符就中止。

## 1. 相容性檢查（唯讀，不改任何東西）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\01-precheck.ps1 -Device 192.168.1.50:5555
```

預期每行都是 OK。出現 FAIL 就**不要繼續**。WARN 通常只影響 WebView 升級。

## 2. 安裝

先看會做什麼：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\02-install-app.ps1 -Device 192.168.1.50:5555 -DryRun
```

實際安裝（會要你輸入 YES 確認）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\02-install-app.ps1 -Device 192.168.1.50:5555
```

腳本依序做：

1. 重跑相容性檢查
2. 驗證 APK 的 SHA-256
3. adb install -r 安裝 UYAS X
4. cmd package set-home-activity 把 UYAS X 設為預設桌面
5. pm disable 停用原廠 StartupActivity，讓開機只進 UYAS X

全程只動 /data 與套件設定，不碰 /system。

## 3. 設定

打開 UYAS X，進入設定：

- **YouTube**：內建共用金鑰，建議改填自己的。建立金鑰時「應用程式限制」要選 **無**。
- **Spotify**：內建的 Client ID 只允許作者名單內的帳號登入。要用自己的帳號，請到
  Spotify Dashboard 建立應用程式，Redirect URI 填 uyas://spotify/callback，再把 Client ID 填進設定。
- **螢幕保護**：可選自建（時鐘加天氣）、原廠或關閉，也可設定城市。

## 4. 驗證

按喇叭的 Home 鍵或重開機，應進入 UYAS X。也可用下面指令確認預設桌面：

```powershell
adb -s 192.168.1.50:5555 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

最後一行應為 com.uyas.speaker.launcherx/.MainActivity。

## 已知行為

- 原廠**實體按鍵**（音量、播放/暫停、語音）改由 UYAS X 處理。
- **虛擬三按鍵**預設不會出現；需要進原廠桌面時，仍可用「同時按 5 個實體按鍵」叫出，
  再點中間的 Home（見步驟 0）。
- 進入藍牙模式會切到原廠藍牙頁面；離開時 UYAS X 會關掉它，不留在背景。