# 步驟 3（選用）：WebView 61 升級到 138

> ⚠️ **高風險：會改寫 /system。** 不做也能正常使用基本功能。

## 為什麼要升級

原廠 System WebView 是 Chrome 61，太舊：

- 前端程式必須用 ES5 語法
- 沒有 Custom Tabs，Spotify 等 OAuth 登入頁可能顯示不全或按鈕無反應
- 新版網站相容性差

升級到 LineageOS 的 WebView 138.0.7204.63 後，登入可直接在喇叭上完成。

## 風險

- 需要約 **256 MB** 的 /system 與 /data 空間。原廠 /system 本來只剩約 200 MB，**可能不夠**，不夠時腳本會中止。
- Chromium 138 比 61 吃記憶體，喇叭只有約 1 GB，可能變慢。
- 作者只在一台機器上做過；在別台是否順利沒有驗證。
- 寫入 /system 期間斷電或斷線，最壞情況是 WebView 壞掉。WebView 不影響開機，adb 仍可連線，可用還原腳本換回。

## 執行

```powershell
# 先看計畫（不改任何東西；下載與 push 會略過）
powershell -ExecutionPolicy Bypass -File scripts\03-upgrade-webview.ps1 -Device 192.168.1.50:5555 -DryRun

# 實際執行
powershell -ExecutionPolicy Bypass -File scripts\03-upgrade-webview.ps1 -Device 192.168.1.50:5555
```

腳本會：

1. 確認目前是原廠 61.x，且 /system、/data 各有至少 256 MB
2. 下載 WebView（約 245 MB）並驗證 SHA-256；也可用 -WebViewApk 指定已下載的檔案
3. **備份原廠 WebView 到 backup\webview-stock\**，並與喇叭上的檔案比對雜湊；不符就中止
4. 推到 /data/local/tmp，驗證雜湊
5. remount /system 為可寫，複製成 .new，再驗證一次雜湊，才用 mv 覆蓋舊檔
6. 刪除舊的 oat、修正擁有者、權限與 SELinux 標籤，再 remount 回唯讀
7. 重開機並確認版本是 138

**請保留 backup\webview-stock\**，還原要用到。它只存在於執行腳本的那台電腦上。

## 驗證

```powershell
adb -s 192.168.1.50:5555 shell dumpsys webviewupdate
```

Current WebView package 應顯示 138.0.7204.63。

## 還原

見 [04-restore.md](04-restore.md)。