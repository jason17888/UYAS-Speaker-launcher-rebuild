# UYAS X 安裝包

為 **UYAS Play 智慧喇叭**（原廠雲端 `api.uyas.tw` 已關閉）安裝替代桌面 **UYAS X**。
提供 YouTube、Spotify、螢幕保護（時鐘＋天氣）和實體按鍵處理。

> ⚠️ **這會修改你的喇叭。** 基本安裝只動 `/data`，可完整還原；選用的 WebView 升級會改 `/system`，
> 有風險。請先讀完「風險與限制」。作者不保證任何結果，風險自負。

## 相容機型

只支援與作者相同的韌體，`01-precheck.ps1` 會自動檢查，不符就中止：

| 項目 | 需要 |
|---|---|
| 型號 | `ro.product.model=UYAS`、`ro.product.device=rk3368` |
| 系統 | Android 8.1 (SDK 27)，**`userdebug`** build |
| root | `adb shell su 0 id` 回 `uid=0` |
| 指紋 | `Sixnology/uyas/rk3368:8.1.0/OPM8.190605.005/155012:userdebug/dev-keys`（不同只警告） |

`user` build、沒有 root 的機器不支援。

## 流程總覽

| 步驟 | 內容 | 風險 | 文件 |
|---|---|---|---|
| 0 | 在喇叭上開啟無線 adb（喇叭沒有 USB 孔） | 低 | [docs/01-enable-wireless-adb.md](docs/01-enable-wireless-adb.md) |
| 1 | 相容性檢查（唯讀） | 無 | [docs/02-install.md](docs/02-install.md) |
| 2 | 安裝 UYAS X、設為預設桌面、停用原廠 `StartupActivity` | 低 | [docs/02-install.md](docs/02-install.md) |
| 3 | （選用）WebView 61 → 138 | **高** | [docs/03-webview.md](docs/03-webview.md) |
| - | 還原 | - | [docs/04-restore.md](docs/04-restore.md) |

## 快速開始（Windows）

需要：Windows、[Android platform-tools](https://developer.android.com/tools/releases/platform-tools)（`adb`）、Powershell 5.1 以上。

```powershell
# 先到本 repo 的 Releases 頁面下載 uyasx-1.0.0.apk，放進 apk\ 資料夾
# 再完成步驟 0 取得喇叭的 IP，並確認 adb 可用
adb version

# 1. 檢查（唯讀）
powershell -ExecutionPolicy Bypass -File scripts\01-precheck.ps1 -Device 192.168.1.50:5555

# 2. 安裝（先 -DryRun 看會做什麼，確認後拿掉 -DryRun）
powershell -ExecutionPolicy Bypass -File scripts\02-install-app.ps1 -Device 192.168.1.50:5555 -DryRun
powershell -ExecutionPolicy Bypass -File scripts\02-install-app.ps1 -Device 192.168.1.50:5555
```

`adb` 不在 PATH 時加 `-Adb C:\路徑\adb.exe`。

## 風險與限制

- **WebView 升級會改 `/system`。** 腳本會先備份、逐步驗證雜湊，失敗時盡量不動舊檔，但無法保證所有情況。
  `/system` 空間很緊（原廠約剩 200 MB，需要 256 MB），腳本會檢查並在不足時中止。**不升級也能用**，
  只是 Spotify 登入頁和新版前端功能在 Chrome 61 上受限。
- **記憶體只有約 1 GB。** Chromium 138 比 61 吃更多記憶體，可能變慢，作者只在一台機器上實測過。
- **簽章是 debug 簽章（公開金鑰）。** 這讓日後更新可直接 `adb install -r` 而不清除資料。
  任何能對喇叭執行 `adb install` 的人都能覆蓋它，但這台的 adb 本來就沒有驗證。
- **共用 API 金鑰。** APK 內建作者的 YouTube Data API 金鑰和 Spotify Client ID，所有安裝者共用同一份配額：
  - YouTube：每日 10,000 unit，搜尋一次 100 unit；用盡時搜尋會失敗，可在「設定 → 應用程式設定」改填自己的金鑰。
  - Spotify：開發模式下只有被加入使用者名單的帳號能登入，名額有限；其他人需自建 Spotify 應用程式並填入自己的 Client ID。
  - 金鑰寫在 APK 裡，任何人解開都看得到。
- **Spotify 控制播放需要 Premium。** 喇叭本身不是 Spotify Connect 裝置，播放發生在手機端再經藍牙傳到喇叭。
- **語音辨識不可用**（需要 Google 帳號與 GMS，這台無法完成）。
- 原廠雲端功能（登入、雲端歌單）已永久失效，本專案不嘗試復原。
- 韌體為 `userdebug` 且無線 adb **沒有驗證**（`ro.adb.secure=0`）：同一區網的人都能控制喇叭。轉讓前請見 [docs/04-restore.md](docs/04-restore.md)。

## 檔案

```
apk/SHA256SUMS.txt      APK 校驗值（APK 本身放在 Releases，需自行下載到此資料夾）
scripts/                01-precheck / 02-install-app / 03-upgrade-webview / 90-restore
docs/                   教學
```

## 授權與來源

本 repo 不包含原廠程式（`UYAS.apk` 等）。WebView 138 為 LineageOS 建置的 Chromium，**不放在本 repo**，
由腳本從下列網址下載並驗證 SHA-256：

- URL：`https://github.com/panel-assistant/android/releases/download/webview-mirror/lineageos-webview-138.0.7204.63.apk`
- SHA-256：`3fe65c631ce9b0f8e573198a783cf8ad1013aef02b83f04e7871952879b599cf`