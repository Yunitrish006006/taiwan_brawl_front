# 街角拾荒：寫實像素美術與遊玩相容規格

狀態：使用者已選定「像素風，但要有寫實的感覺」。本文件取代先前未確認的手繪方向。Demo 是美術／操作驗證，不代表正式遊戲或完整美術資源已完成。

## 1. 美術基調

- 台灣街角、港邊巷道、鐵皮雨棚、捲門、磚牆、回收架與小型工作桌。以真實結構、比例、材料磨損建立寫實感，不以高飽和顏色或大頭角色製造可愛感。
- 人物約六到七頭身；示範小尺寸角色約34像素高，頭5像素。姿勢自然，不以貧窮、髒污或誇張表情當笑點。
- 光源固定左上；亮面、基色、暗面、輪廓每材質以4–6色起步。鏽蝕、布補丁與木纖維只放在可辨識的局部，不把整張畫面鋪滿噪點。
- 基礎色：深墨綠 `#293d3b`、鏽銅 `#bc7955`、舊木 `#cab98b`、紙白 `#e8dfcb`、鋅灰 `#6c8382`。危險／品質不可單憑紅綠區分。
- 寫實是比例與材質邏輯，不是照片套像素濾鏡。第一版街景僅為構圖與輪廓驗證；量產前需補細緻磨損、人物動作及各材質的縮圖辨識測試。

## 2. 資產規格與畫面分層

| 類別 | 起始規格 | 輸出／限制 |
| --- | --- | --- |
| 單格物品 | 32×32基準畫布，主輪廓至少24×24 | 透明背景；48px操作格仍可分辨 |
| 長形／大型物件 | 32×64或64×64；依占格比例 | 邏輯占格由物品定義決定，不從透明像素推算 |
| 人物 | 32×48畫布，人物約34–42px高 | 站立／行走／取物／加工分組；各幀腳底錨點一致 |
| 場景 | 320×128 demo構圖；正式以區塊拆分 | 地板、建物、前景、互動物分層，不把介面烘焙進場景 |
| 介面 | 系統向量文字、清楚面板與實線格位 | 字型不像素化；可縮放文字，不同步模糊化圖像 |

正式匯出 PNG atlas、透明、無有損壓縮；nearest-neighbor、關閉 mipmap／平滑插值，atlas 邊緣預留2px padding避免取樣污染。圖像優先整數倍縮放；非整數手機尺寸採留白或裁切背景，互動格位仍按裝置邏輯像素排版。Demo 使用整數座標 SVG `crispEdges` 方便快速修改，非正式 atlas 或像素倍率驗收結果。

層次固定：背景→地面物件→人物／互動物→選取／危險輪廓→介面。操作提示、品質、材料數量不壓在高細節場景上。

## 3. 每種素材如何在玩法裡辨識

| 材料群 | 主輪廓／紋理 | 加工與原生差異 |
| --- | --- | --- |
| 木料 | 長纖維、端面、明暗長邊 | 原生連續木紋；膠合接縫、釘接釘點；仍共享同一木板用途 |
| 布／線 | 柔軟折角、織紋、線軸／線團 | 縫補針腳、拼接色塊；不靠換色代表不同數量 |
| 金屬／工具 | 硬直邊、局部冷色高光 | 鍛接痕、鏽斑與修補箍；高光不可像可點提示一直閃 |
| 塑膠／玻璃 | 塑膠偏霧面、玻璃少量高光與透色 | 保留瓶口和容器輪廓；不可把裝水畫成額外物件占格 |
| 紙／材料束 | 紙張折角、束繩、厚度側面 | 束圖示＋件數；不得暗示品質升級或變成可直接製作材料 |
| 水 | 相同容器＋液體外觀 | 濁水混濁、泥水沉澱、髒水污染標記；過濾／蒸餾／礦泉／開水靠明確文字及處理圖標，不只顏色 |
| 食物／魚 | 魚種剪影、熟食盤面／餐盒 | 品質與恢復效果放資訊面板；吃完保留同一容器身份 |
| 箱子／背包 | 箱體結構、扣件、補片 | 升級容量以格數與占地呈現，不靠圖示大小猜測 |

相同 item ID 可有 `found`／`crafted` 視覺變體；渲染來源取 provenance，不改物品用途。品質用文字「粗劣／普通／良好／優良」，詞條顯示具體影響。高品質加工物仍可有接縫，低品質原生物仍保留完整原始結構；不可把來源直接當品質。

## 4. 與遊玩系統的相容契約

1. 背包先顯示占格矩形，再顯示物件；大物須連續空間。旋轉只改 sprite，不旋轉名稱、品質或數量。觸控可「點物→點空格」，不能要求拖曳才可使用。
2. 原生與加工使用同一配方輸入／訂單類型，只在品質、來源、詞條上有差異。Demo 以兩種木板交同一單驗證。
3. 小玩法先顯示投入數量與會消耗的材料，之後才開始。落釘／裁切等不可逆步驟要記錄；離線、切背景或重啟不能免費回退。Demo 記錄落釘序列，重載可接續；正式版仍須原子交易及 crash recovery。
4. 稀有材料、品質、來源以輪廓＋文字／圖標多重表達。濾鏡、低畫質、關閉動畫不得改成功率或隱藏操作時機。
5. 收納束必須手動拆包；倉庫物須先取出才能製作。UI 材料總數不得把不可用倉儲資源算成可投入數。
6. 動畫暫定物件6–8fps、人物8–12fps；核心操作判定不依動畫幀。降低動態模式保留靜態進度與文字結果；無必要閃光。

## 5. 模組、版本與下載

- 第三遊戲資產只隸屬 Street Scrap。其他遊戲資料、美術與存檔不混用；共用 UI 只提供通用介面，不依賴本遊戲的 item ID 或圖包。
- manifest 分開 `gameId`、`artRevision`、`contentVersion`、`rulesVersion`、`saveSchemaVersion`、`minClientVersion`、檔案hash與尺寸。美術修正不得偷偷更改配方／占格；規則變動必須升對應版本。
- 渲染映射擬定 `{itemId, variant, assetKey, frameRect, pivot, pixelSize}`。缺圖可用有名稱／占格的通用剪影；缺必要規則不得繼續結算。資源包下載、hash核對與原子啟用由正式遊戲整合切片完成。
- 程式碼仍隨主程式配送，資源可選擇下載；美術規格不改既定 iOS／跨遊戲架構。此 Demo 不提供下載管理或多人版本協商。

## 6. 量產流程與驗收門檻

先完成 SS-00 的美術基線→用木／紙／布／金屬建立素材樣本→SS-03 背包縮圖驗收→SS-05／07 手動加工動畫→逐章擴充資產→SS-11 整包與裝置驗收。

- 每份素材附：assetKey、對應itemId、來源變體、尺寸、幀數、pivot、作者／授權、artRevision、縮圖對照。
- 320／390／768／1280px寬度檢查：無水平溢位、操作目標至少48px、文字200%仍能讀取與操作；棋盤不為擠入螢幕縮成難按小格。
- 名稱隱藏時仍以剪影辨識材料群；名稱開啟時能分辨所有具體物品。原／作字樣與品質等級可透過讀屏取得。
- 目標：代表裝置場景載入後操作不阻塞、60fps顯示、首章圖包壓縮後≤8MB、單圖集≤2048²。這些是待量測預算，不是已完成的性能證據。
- 不通過的圖：原生與加工無法辨別、箱子遮住相鄰格、液體像額外占一格、文字烘焙於圖像、低品質只能靠紅色辨識、動畫掩蓋失誤時機。

## 7. 本機示範與驗證界線

啟動與操作見 [Demo README](../../../../../TaiwanBrawlWorkspace/apps/street_scrap_demo/README.md)。連線位址為 `http://127.0.0.1:8093`，無須網際網路或 Google 登入。

本版有像素街景、六種物品圖示（木板另有加工變體）、4×4背包、旋轉、打包／拆包、釘接、交單與瀏覽器本機保存。沒有完整章節、美術量產、正式存檔安全、多分頁同步或遊戲引擎整合。自動挑選投入材料及簡化釘點是 Demo 限定；正式遊戲仍需手動選料。

### 本輪驗證記錄（2026-10-22）

- Node 自動測試：69項通過，其中7項是 Demo 狀態測試，涵蓋旋轉衝突、打包品質與身份守恆、主材品質計算、兩種來源交同一單、滿包拒絕不扣體力、壞檔拒絕。不是完整正式遊戲的測試。
- 瀏覽器實際操作：紙屑打包後14→12格，拆包恢復；釘接第一步後重新整理，恢復1/3步進度，再依序完成，產出「加工／普通／釘固加強，支撐+10%」木板並解鎖快速製作。
- 實際截圖檢視：桌面像素街景、原生／加工木板縮圖、320px背包名稱與占格、品質資訊面板；原生完整木紋與加工接縫／釘點分開顯示。
- `preview.html` 以 iframe 建立320／390／768／1280px寬度；扣除15px捲軸後，實際clientWidth為305／375／753／1265。一般與大字模式的scrollWidth皆等於clientWidth，沒有水平溢位；棋盤與工具列操作目標最小一般48px、大字51.5px以上。大字提示內文由12px變28px，棋盤小標保持固定大小，完整資訊在放大詳情面板讀取。
- 發現並修正：原大字樣式用了根元素 `rem`，部分內文未真正放大；已改為明確字級並重新量測。
- 主控台檢查：QA頁曾記錄一筆 `MutationObserver.observe` 的Node型別錯誤，無來源URL；本Demo程式沒有MutationObserver，重載未新增同錯誤。來源未能定位，不列為「主控台零錯誤」；上述操作與排版測試未因此失效。
- 未驗收：真實iOS／Android裝置、正式Flutter渲染、觸控拖放、全素材量產、效能預算、玩家對寫實程度的主觀認可。這些保留為正式實作門檻，不將CSS寬度檢查冒充真機結果。

### 第一份正式選用美術資源（2026-10-23）

- Owner package 將原生木板 PNG 存於 `../resources/art/street-scrap-art-v0.1.0.png`，1774×887 RGBA、檔案約588KB。素材由 ImageGen 產生；prompt 要求水平正交、透明背景、低飽和舊木與清楚端面，無文字／背景。第一次輸出把棋盤格烘焙成RGB，已排除，沒有納入專案。
- 獨立 resource ID `game.street-scrap.art.wood-board`、種類 `presentation`、art revision `0.1.0`、payload schema 1，SHA-256 `0a8dc05c643d47f6784f894bbf6e882a1f8da5444a8e391ced055302ca0e405f`。不改遊戲規則、存檔或物品占位；沒有下載 URL 前保持未安裝並使用程式內像素 fallback。
- 當前 UI 只對原生／拾得來源木板讀取此圖，加工木板保留帶釘接標記的 fallback。素材仍是單件樣本，未滿足全物品 asset mapping。後續獨立 atlas owner test 已用 Flutter codec 解碼實際 PNG、讀回 RGBA 並確認三個代表 tile 不同，也確認三個 `StreetScrapItemSprite` 經 `Image.memory` 消費同一資源；這是 Flutter codec／widget 接線證據，不代表 GPU 顯示、真機辨識、效能或完整 atlas 已驗收。

### 第一版材料圖集（2026-10-23）

- 獨立生成並保存 `../resources/art/street-scrap-art-material-atlas-v0.1.0.png`：768×768 RGBA，透明底、4×4 等分格、每格192×192、檔案小於1MiB；SHA-256 `2b62f7dee3529562ed221e7fbe384f8985ef18332c1b466bc46799b7dcc524ca`。正式圖集使用「像素風、材料紋理寫實、低飽和、透明背景、物件置中、無文字」提示生成；生成原圖只保留在 Codex generated-images，不覆蓋前兩份單物件素材。
- 0起始 row-major 格位：`0`拾得原木板、`1`膠合釘接加工木板、`2`線軸、`3`縫補布條、`4`破布、`5`線頭、`6`金屬屑、`7`完整金屬片、`8`鏽蝕金屬碎片、`9`塑料碎片、`10`紙屑、`11`乾燃料束、`12`空清潔瓶、`13`裝濁水瓶、`14`空餐盒、`15`生魚。木板來源格位不同，水瓶內容依裝載資料選格；沒有對應格位的其餘物品維持內建 fallback。
- 註冊為獨立可選 `presentation` resource `game.street-scrap.art.material-atlas` v`0.1.0`、schema 1，不改玩法和存檔。載入時只對已安裝資源讀 bytes；專用 validator 要求 PNG 768×768，通用 validator 另驗 signature、最大尺寸與1MiB上限。feature map 以純單元測試驗證原生／加工木板和空瓶／濁水瓶分流；owner widget test 再以 Flutter codec 實際解碼 PNG、抽樣比較原生木板／加工木板／泥水瓶 tile 像素，並確認三個 atlas-consuming sprite 使用同一 payload。真實 GPU 顯示、觸控裝置、尺寸／縮放辨識、效能及全材料辨識仍待驗收。未有正式簽章 catalog／下載 URL，玩家不能從一般遊戲庫下載此資源。

### 擴充材料圖集 v0.2.0（2026-10-24）

- 以第一版圖集作風格參考，使用 ImageGen 產生透明像素素材，再以 nearest-neighbor 縮至 768×768；保留原始 4×4 圖集，不覆寫 v0.1.0。將原 16 格置於新版上半部，新增圖集置於下半部，形成 768×1536 的 4×8 RGBA atlas，檔案 1,345,062 bytes，SHA-256 `7a1e8619b49c729e066849a8c5607aa6f7f39f3a99991e69263547bd51f61663`。
- 下半部 row-major 格位 16–31：木屑、木粉、漂木、木條、木框、布邊料、拼布、線頭、粗繩、釘件束、混合扣件、回收膠料、泥水瓶、髒水瓶、過濾水瓶、開水瓶。前端依物品 ID／來源／容器內容選格；未映射水種和舊 atlas 缺少的新格仍回退離線 painter，不會以同一空瓶圖覆蓋水質差異。
- resource ID 維持 `game.street-scrap.art.material-atlas`，版本升至 `0.2.0`，kind 仍為非必要、非 gameplay `presentation`。validator 同時接受已安裝的舊 768×768 v0.1.0 與新 768×1536 v0.2.0；renderer 依 PNG 高度選擇4列或8列，舊圖包在更新前繼續顯示原16格並讓新增項目使用 fallback。圖集上限調為2 MiB；不更改 item、recipe、格位、存檔 schema 或玩法版本。尚無正式下載 URL；owner／release gates 完成前不標記資源發布或裝置驗收。

### 工具／釣魚／料理圖集 v0.1.0（2026-10-24）

- 新增 `../resources/art/street-scrap-art-tool-atlas-v0.1.0.png`：768×768 RGBA、4×4 等格、663,394 bytes，SHA-256 `2325de988608437758a4e3217410ddbb390a1fdef9f9cdf3f699a8f1ec05126e`。像素寫實風格延續工具磨損、舊金屬／木柄與低飽和基線；透明底、無背景和文字。目視檢查整張透明圖集；完整小尺寸真機辨識仍待驗收。
- row-major 0–15：縫針、紙模、修補錐、撬具、分類鉗、修理組、基礎釣竿、改良釣竿、鍋、爐、料理組、冷凝器、釣組、浮標、基礎魚餌、香草魚餌。接線只依 item ID 使用相應格；水、燃料或未映射物件繼續走 material atlas／code-native fallback，避免錯誤共用圖示。
- 註冊為獨立選用 `presentation` resource `game.street-scrap.art.tool-atlas` v`0.1.0`／schema 1，`affectsGameplay=false`、`required=false`。專用 validator 嚴格限定 768×768，並通過共用 PNG signature／大小檢查；內容只有在安裝紀錄有效且 bytes 驗證成功時才讀取，缺檔或格式錯誤仍用 fallback。三語資源名稱、本機 signed preview manifest／KV metadata／媒體下載 API 也已接線；在更新後同源 8787 瀏覽器中刷新目錄並完成 663 KB 資源下載、簽章／hash 驗證與本機安裝，正式 publisher catalog 仍未發布。

### 紙材／塑料／燃料圖集 v0.1.0（2026-10-24）

- 新增 `../resources/art/street-scrap-art-material-pack-v0.1.0.png`：768×768 RGBA、透明背景、4×4 等格、840,381 bytes；SHA-256 `ab4919e0b063b25a67cd7148493faa0ab397e80547740dcfa8f2c2879a5dbad9`。以16格、每格192px設計，近看保留紙纖維／瓦楞、塑料摺痕、燃料綑紮等材質，小尺寸輪廓辨識仍待玩家／裝置驗收。
- row-major 0–15：紙屑、紙漿、紙板、防水包裝、塑料碎片、塑料片、塑料浮件、橡膠密封圈、塑料碎片束、混合燃料、乾燥燃料、油布燃料、節能燃料包、玻璃碎料、濾布、防水塗料。renderer 只對明確 item ID 使用新 atlas，並優先於舊圖集對紙屑／塑料碎片／乾燃料的簡化格；缺少資源或未映射的 item 仍使用內建 fallback。
- 註冊為獨立可選 `presentation` resource `game.street-scrap.art.material-pack` v`0.1.0`、schema 1；不變更物品數值、玩法、格位或存檔。Owner validator 嚴格檢查 PNG signature、768×768尺寸及2MiB上限；signing／manifest／loopback resource API已由release測試驗證。尚未宣稱真實遊戲庫按鈕安裝、正式publisher簽署／發布或裝置效能驗收。

### 礦物材料束圖示（2026-10-24）

- 新增單件透明 PNG `../resources/art/street-scrap-art-mineral-pack-v0.1.0.png`，512×512 RGBA、364 KiB；SHA-256 `4468edcedc428ae28e353e1e7022cce65b06874de11decf11676147b8a6695fc`。以「重複使用的舊布袋裝有礦物碎粒，像素風且有寫實比例、低飽和、透明底、無文字／場景」作為生成需求，縮至512px後另檢視32px縮圖，袋口與碎石輪廓仍可辨識。
- 註冊為 `game.street-scrap.art.mineral-pack` v`0.1.0`、schema 1 的獨立選用 `presentation` 資源；`affectsGameplay=false`、`required=false`，暫無下載 URL。只有安裝紀錄符合版本、schema、hash 時才讀取內容；資料通過通用 PNG 驗證後只替換 `material.mineral_pack` 的內建像素繪製，否則回退至內建繪製。不得因此改物品規則、占格或存檔。
- 前端資源格式／hash與 optional-fallback 靜態接線測試 `node --test tool/street_scrap_art_resource.test.mjs`：5/5 通過。這不是 Flutter 解碼、實際畫面或裝置驗收；本輪沒有可用 Flutter／Dart SDK，亦未發布簽章 catalog 或下載 URL。縮圖辨識、Flutter renderer、真機及完整材料圖集覆蓋仍待驗收。

### 木屑束圖示（2026-10-24）

- 新增 `../resources/art/street-scrap-art-wood-chip-bundle-v0.1.0.png`：512×468 RGBA、237,875 bytes；SHA-256 `69c8709f942293983b576eef9f84b85406eb07465c9448354db9b7c433be6bce`。ImageGen 以單一綁繩木屑束、低飽和寫實像素材質、左上光源、透明背景、無文字／場景為提示，輸出縮至512px後檢查透明與32px縮圖；此圖對應 `bundle.wood_chip`，不是單片 `wood.chip`。
- 註冊為 `game.street-scrap.art.wood-chip-bundle` v`0.1.0`／schema 1 的獨立選用 presentation resource；不影響玩法、占格或存檔。僅當 library 安裝紀錄有效且 bytes 通過 PNG 驗證時，棋盤／物品卡採用素材；缺少或驗證失敗維持既有像素 fallback。尚無下載 URL 或正式簽章 catalog。
- 已新增資源 SHA／alpha／尺寸／大小、manifest 註冊、路由讀取、無效資料回退與 sprite 消費端測試。這些靜態／Node 證據不替代 Flutter Image 解碼、真機渲染／辨識與單圖資源下載驗收；Flutter／Dart SDK 未提供，相關 owner tests 尚未執行。

### 食材／魚貨／料理圖集擴充 v0.3.0（2026-10-25）

- 新增16格寫實像素食物圖，列序為整魚、魚肉、魚骨、魚貨包、廚餘、青菜、野菜、清理食材、澱粉、野生香草、鹽、調味包、綜合香料、基本湯、魚湯、蔬菜湯；來源單圖 `street-scrap-art-food-atlas-v0.1.0.png` 僅作建置素材，不另外下載。
- 將16格接在材料 atlas 原有32格後，輸出 `street-scrap-art-material-atlas-v0.3.0.png`：768×2304、4×12、530,343 bytes、SHA-256 `bc7a803a0ba9a0369c1837483b29a33e645fb8f465920082cdb50dabd006b50a`。以 nearest-neighbor 對齊192×192格，再轉256色索引 PNG；透明由 `tRNS` alpha保留，大小低於2 MiB，舊 v0.1／v0.2 atlas仍留作安裝相容。
- `game.street-scrap.art.material-atlas` 維持獨立選用 `presentation` 資源，版本由0.2.0升至0.3.0；新增 food item ID 對 cell 32–47 的明確映射，沒有圖包仍走原本離線 painter，不更動玩法、品質、格位、規則或存檔。
- 驗收：完整 Street Scrap owner suite 276/276、Flutter analyzer無問題、宿主路由4/4與資源安裝器25/25、asset Node tests 9/9、signed resource release/API 2/2。這是 Flutter codec/widget 與 loopback簽署封裝證據；尚未在瀏覽器實際更新安裝、真機縮圖辨識或測量解碼效能。

### 舊碼頭釣魚場景 v0.1.0（2026-10-27）

- 新增 `../resources/art/dock-fishing-background-v0.1.0.png`：2172×724 RGB，2,382,078 bytes，SHA-256 `a0930a892db15773fffef56f8f09c1388f9ec7793737586b27dcc556484744a8`。場景以低飽和寫實像素呈現台灣港區、漁船、舊碼頭與人物，16:5左右長景以碼頭側作手機裁切焦點；魚訊／浮標操作圖層仍由 UI 即時繪製。
- 註冊為 `game.street-scrap.art.fishing-scene` v`0.1.0`／schema 1 的可選 `presentation` 資源，`affectsGameplay=false`、`required=false`。沒有下載或 PNG 驗證失敗時保留內建離線場景；不改配方、釣魚費用、存檔或遊戲規則。釣魚場景名稱已加繁中、英文與日文。
- 隔離 Web 遊戲庫完成 signed loopback 資源下載／安裝，並在 `localhost:8990` 看見新版場景；未使用正式 Keychain 金鑰、Cloudflare 或正式發布。真機尺寸、GPU 效能、玩家對像素風辨識及 VoiceOver／TalkBack 仍待驗收。

### 主角待機圖 v1（2026-10-27）

- 新增 `../assets/fallback/street_scrap_protagonist_idle_v1.png`：1159×1358 RGBA、632,357 bytes，SHA-256 `5f7ef9f2dbe0a37af2979d3ed9de47afedade58fc6cd51b3f061e9bbd5435a95`。素材為成人六至七頭身、實用舊外套與肩袋的台灣街頭拾荒者待機姿勢，低飽和寫實像素質感；透明背景已確認有 alpha，不含場景或文字。
- 以套件內建 fallback 提供，不依賴下載選用美術資源；接入寬版空棋盤街景與空素材圖鑑街景，讓新玩家一進入遊戲即可看到角色，手機緊湊工作台不受影響。角色圖排除額外讀屏語意，整個場景仍由原探索按鈕接收點擊。真正斷網並重啟的驗收尚未執行。
- Flutter widget 測試確認 872×874 寬版場景角色高度超過200px且無 layout exception；Street Scrap owner suite **342/342**，兩個變更 Dart 檔 analyzer 無問題。此版只有待機圖，沒有接入走路、拾取或工作動畫；窄版手機實機、讀屏、角色動態及玩家辨識度仍待驗收。

### 主角行走／拾取／整理姿勢 v1（2026-10-27）

- 新增套件內建透明 sprite sheet `../assets/fallback/street_scrap_protagonist_actions_v1.png`，1884×835 RGBA，三個等寬 628×835 影格，1,051,324 bytes，SHA-256 `d85e79205b009b7749594b2933f1171948956d2ba35542890ddb03aff4c00e90`。三姿勢依序為行走、蹲身拾取與整理拾得物；角色衣著、髮型、肩袋與低飽和寫實像素風延續待機圖。
- 空工作台街景以固定單格視窗裁切圖集，1.8秒切換姿勢、240ms淡化；尊重系統「減少動態」偏好並停止週期切換。這是街景裝飾動作循環，不聲稱與探索／拾取 reducer 的操作時點同步；目前沒有多幀步態，也未接入實際加工結果事件。
- 套件版本升至 `0.1.4`，存檔 schema、玩法規則與章節資源版本不變。完整 owner suite **342/342**、module manifest consumer **18/18**、宿主 module consumer **4/4**、變更檔 analyzer 無問題；Web Release build 成功。隔離預覽 `127.0.0.1:9050` 安裝第0–4章 v`0.1.32` 與第5章 v`0.1.23`，目視確認單一大型角色姿勢完整顯示；資源 publisher `9051` 使用程序記憶體暫存簽章，未讀 Keychain、未連正式服務。小螢幕真機、讀屏、動態辨識與動作事件同步仍待驗收。
