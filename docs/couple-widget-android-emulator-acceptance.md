# Android 桌面元件：隔離模擬器驗收

2026-11-06 至 11-08，在全新暫存 AVD 使用 Android 15（API 35）、Google
Pixel Launcher、1080 × 1920／420 dpi、Asia/Taipei。未修改原 Pixel_10a AVD。
安裝已編譯的 debug APK，從桌面元件選單加入 **Couple days**，不是另列的
**Couple days — sample**。正式 receiver 已在 `dumpsys appwidget` 中觀察到。

## 已觀察的結果

| 項目 | 範圍與結果 |
|---|---|
| 桌面加入 | 正式元件可加入；初始顯示 Please sign in |
| 離線計數 | 合成快照始日 2026-10-06；當地 11-06 顯示 Day 32，11-07 刷新後顯示 Day 33 |
| 淺色與深色 | 真正 RemoteViews 顯示正常；深色加兩倍系統字級下，天數及空狀態文字完整、無截斷 |
| 清除顯示 | active → unbound → signedOut 時，分別改成 No partner linked／Please sign in，不再保留舊天數 |
| 多實例 | 兩個正式元件的四種狀態檢查均通過；兩者一起更新與清除顯示 |
| 點擊與冷啟動 | 飛航模式、Wi-Fi 關閉時，點擊啟動 MainActivity，Intent 為 OPEN_COUPLE_WIDGET；最後停留登入頁 |
| 重啟恢復 | 模擬器重開機及解鎖後，兩個元件仍顯示 Day 33；觀察到下一個台北午夜的非精確 alarm |
| 時區事件 | 只切換系統時區、不主動刷新 receiver；夏威夷 11-07 顯示 Day 33，還原台北 11-08 顯示 Day 34，兩個實例一起更新 |
| 原生唯讀橋接 | 登入頁出現離線交往天數入口；點入後實際 readCounter channel 顯示第 33 天與未驗證登入提示，沒有關係修改控制 |

兩次四狀態腳本分別檢查一個與兩個元件，逐一比對 UI XML 的正式 resource ID
與文字，保存 PNG／XML／SHA-256；截圖亦經視覺檢查。這不是四項單元測試。
腳本結果摘要保存於 [驗收紀錄](evidence/couple-widget-api35-2026-11-07.json)。
完整截圖保存在執行時指定的暫存 evidence 目錄，系統可能清理；需要時可重跑，
摘要中的雜湊不能取代已清理的原圖。

## 重跑方式

只使用全新、可丟棄的 AVD，先安裝 debug APK、保持桌面英文、開啟飛航模式並
關閉 Wi-Fi，從 Launcher 加入正式元件後停在桌面。腳本只接受 emulator serial，
檢查 debug run-as、離線與正式元件實例；明確指定合成資料模式才會執行。

```sh
python3 tool/verify_couple_widget_android.py \
  --serial emulator-5560 \
  --evidence-dir /tmp/couple-widget-evidence-new \
  --synthetic-fixtures
```

evidence 目錄必須不存在。腳本以合成資料暫時替換 App 私有 widget preferences，
透過 App 自己的 UID 呼叫未對外開放的 receiver，測試正式 reader／renderer，
最後還原原始快照與字級／深色設定。不得對個人 AVD 或真實帳號執行。
多實例測試前先手動放置兩個元件；腳本會查核所有可見的正式元件。

## 仍未通過的驗收

本批使用合成原生快照，沒有經過真實邀請／解除／登出 API，也沒有執行 Dart
`beginSession`／`replace` 原生寫入 channel；不可宣稱兩帳號端到端完成。原生
`readCounter` 是本批實際執行的讀取 channel。

兩個日期的計數結果之間有主動刷新，不構成午夜自動準時更新的證據。移除／尺寸調整、
省電模式與實體手機電量、不同尺寸／語言、大天數與登入後切帳號仍須補測。
本批也不能代替 iOS Xcode／WidgetKit／App Group／簽章與真機驗收。
