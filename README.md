# Taiwan Brawl Frontend

Taiwan Brawl 是一個以 Flutter 製作的跨平台前端，整合了社交、即時對戰與 Firebase Cloud Messaging 通知能力。  
目前這個 repo 主要負責：

- 使用者登入與個人資料
- 好友、私訊與通知體驗
- Royale 對戰大廳、牌組與戰場 UI
- Flutter Web 輸出與 Firebase Messaging service worker

後端 API、D1、KV、Durable Objects 另外放在同層的 `../taiwan_brawl_back` repo。

## 主要功能

- Google 登入
- 好友系統與私訊
- 背景 FCM 通知
- Royale 卡牌對戰介面
- 多語系文字資源
- Web、iOS、macOS、Windows、Linux 共用同一套 Flutter UI

## 技術堆疊

- Flutter
- Provider
- Hive
- WebSocket
- Firebase Cloud Messaging

## 專案結構

```text
lib/
├── constants/      # 常數、語系 catalog
├── models/         # 前端資料模型
├── pages/          # 畫面與頁面組裝
├── services/       # API、聊天、通知、對戰等邏輯
├── utils/          # 小型工具函式
└── widgets/        # 共用 UI 元件

web/
├── index.html
├── manifest.json
└── firebase-messaging-sw.js
```

## 本機開發

先安裝 Flutter 依賴：

```bash
flutter pub get
```

本機跑 Web：

```bash
flutter run -d chrome
```

### 離線本地預覽

預覽模式會直接進入示範首頁，使用瀏覽器本地 Hive 儲存與 deterministic mock API，
不需要 Google OAuth、Cloudflare API 或網路。首頁包含好友、編輯/收回/已讀訊息、
以及同頁雙 peer 的 in-memory P2P 同步示範；右上角可重置預覽資料。

```bash
flutter run -d chrome --dart-define=PREVIEW_MODE=true
```

或建立可用靜態伺服器開啟的 Web release：

```bash
PREVIEW_MODE=true ./tool/build_web.sh
```

預覽資料只保存在目前瀏覽器的本地儲存中，正式模式不會啟用這些 mock adapter。

如果要指定後端 API：

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8787 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=your-client-id \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=your-server-client-id
```

## 建置

Web release build：

```bash
flutter build web --release
```

前端也提供獨立建置入口；它只需要 Flutter SDK，不依賴 backend 或 Wrangler：

```bash
FLUTTER_BIN_DIR=/path/to/flutter/bin \
API_BASE_URL=https://example.test \
BUILD_NAME=0.132.0 \
./tool/build_web.sh
```

後端 repo 的 `deploy.sh` 會自動：

1. 生成 locale catalog
2. 建置 Flutter Web
3. 產生 `assets.json`
4. 上傳到 Cloudflare KV
5. 部署 Worker

## 相關說明

- 前後端整體架構文件：`../taiwan_brawl_back/docs/architecture.md`
- 推播設定文件：`../taiwan_brawl_back/docs/push_notifications_setup.md`

## 目前狀態

目前聊天接收主流程仍以 polling 為主，FCM 主要負責背景通知提醒。  
Royale 對戰的即時狀態則透過後端房間 WebSocket 與 Durable Object 驅動。
