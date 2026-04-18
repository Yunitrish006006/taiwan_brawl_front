# Taiwan Brawl Frontend

Taiwan Brawl 是一個以 Flutter 製作的跨平台前端，整合了社交、即時對戰與 Web Push 通知能力。  
目前這個 repo 主要負責：

- 使用者登入與個人資料
- 好友、私訊與通知體驗
- Royale 對戰大廳、牌組與戰場 UI
- Flutter Web 輸出與 PWA / Web Push 橋接

後端 API、D1、KV、Durable Objects 另外放在同層的 `../taiwan_brawl_back` repo。

## 主要功能

- Google 登入
- 好友系統與私訊
- 背景 Web Push 通知
- Royale 卡牌對戰介面
- 多語系文字資源
- Web、iOS、macOS、Windows、Linux 共用同一套 Flutter UI

## 技術堆疊

- Flutter
- Provider
- Hive
- WebSocket
- Web Push Service Worker

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
├── push_notifications.js
└── web-push-sw.js
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

目前聊天接收主流程仍以 polling 為主，Web Push 主要負責背景通知提醒。  
Royale 對戰的即時狀態則透過後端房間 WebSocket 與 Durable Object 驅動。
