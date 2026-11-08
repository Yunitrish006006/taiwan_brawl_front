import 'package:flutter/widgets.dart';

String streetScrapRecipeSuccessMessageKey({
  required String station,
  required String? stateEffectType,
  required bool hasOutputs,
}) {
  if (stateEffectType == 'transformContainerContent') {
    return 'recipe.successWater';
  }
  if (stateEffectType == 'transformContainers') {
    if (station == 'kitchen' && !hasOutputs) return 'recipe.successMeal';
    return hasOutputs
        ? 'recipe.successWithContainers'
        : 'recipe.successContainer';
  }
  if (stateEffectType == 'packObjects') return 'recipe.successPack';
  return 'recipe.successOutputs';
}

/// Package-owned copy for Street Scrap. Unknown locales fall back to Traditional
/// Chinese so the independently shipped game remains usable offline.
class StreetScrapLocalizations {
  const StreetScrapLocalizations(this.locale);

  final String locale;

  /// Recipe checkpoints are canonical content strings kept in Traditional
  /// Chinese. Translate them at the presentation boundary so content packs
  /// remain locale-neutral and old saves/content remain readable offline.
  static const Map<String, String> _checkpointPromptsEn = {
    '先從哪裡起針？': 'Where should the first stitch begin?',
    '兩片破布如何對接？': 'How should the two rag pieces be joined?',
    '收線時要保持什麼狀態？': 'How should the thread be secured?',
    '壓合前先怎麼排木片？': 'How should the wood pieces be aligned before pressing?',
    '膠料應塗在哪裡？': 'Where should the adhesive be applied?',
    '夾具何時固定？': 'When should the clamp be secured?',
    '第一個釘點要對準哪裡？': 'Where should the first nail be placed?',
    '敲擊時如何固定木料？': 'How should the wood be held while hammering?',
    '完成後檢查什麼？': 'What should be checked when finished?',
    '先將底板放到哪裡？': 'Where should the base board be placed first?',
    '釘件和膠料如何固定箱壁？': 'How should nails and adhesive secure the crate walls?',
    '完成組裝後先檢查什麼？': 'What should be checked first after assembly?',
    '拼接布先如何排列？': 'How should the patchwork pieces be arranged?',
    '綁帶應加在哪裡？': 'Where should the binding be added?',
    '完成縫補後如何升級？': 'How should the bag be upgraded after stitching?',
    '第一層先如何處理？': 'How should the first layer be prepared?',
    '木炭層應放在哪裡？': 'Where should the charcoal layer go?',
    '接水時要確認什麼？': 'What should be checked while collecting the water?',
    '髒水處理前先確認什麼？': 'What should be checked before treating dirty water?',
    '濾層如何排列？': 'How should the filter layers be arranged?',
    '過濾完成後還要記住什麼？': 'What must be remembered after filtering?',
    '起火後先控制哪個火力區段？': 'Which heat level should be set first after ignition?',
    '中段如何維持水溫？': 'How should the water temperature be maintained midway?',
    '完成煮沸前確認什麼？': 'What should be checked before boiling is complete?',
    '備料時先處理哪一項？': 'Which ingredient should be prepared first?',
    '火力應如何維持？': 'How should the heat be maintained?',
    '完成料理後如何收尾？': 'How should the cooking be finished?',
    '下刀從哪裡開始？': 'Where should the cut begin?',
    '刀線如何沿魚身移動？': 'How should the blade move along the fish?',
    '切分完成前要在哪裡收刀？': 'Where should the cut end?',
    '先挑除哪一處不可用部位？': 'Which unusable part should be removed first?',
    '沖洗時如何處理食材表面？': 'How should the ingredient surface be rinsed?',
    '完成清理前檢查什麼？': 'What should be checked before cleaning is complete?',
    '第 1 次配比調整如何選？': 'How should the first proportion adjustment be made?',
    '第 2 次調整以什麼為準？': 'What should guide the second adjustment?',
    '混合完成何時停止？': 'When should mixing stop?',
    '食材何時下鍋？': 'When should the ingredients go into the pot?',
    '控火時看哪個提示？': 'Which cue should guide the heat control?',
    '起鍋後餐點放在哪裡？': 'Where should the meal go after cooking?',
    '野菜先後怎麼分次加入？': 'In what order should the wild greens be added?',
    '如何判斷素湯火力？': 'How should the heat for vegetable soup be judged?',
    '完成後餐點放哪裡？': 'Where should the meal go when finished?',
    '魚料何時加入比較合適？': 'When is the best time to add the fish?',
    '如何確認魚湯熟度？': 'How can you check that the fish soup is cooked?',
    '第 1 個污點如何清理？': 'How should the first stain be cleaned?',
    '第 2 個污點如何清理？': 'How should the second stain be cleaned?',
    '完成清洗前要確認什麼？': 'What should be checked before washing is complete?',
    '第 1 次整形應落在哪裡？': 'Where should the first shaping strike land?',
    '第 2 次敲擊如何判定合格？': 'How can you tell if the second strike is on target?',
    '最後一次操作要遵守什麼？': 'What should guide the final operation?',
    '裁切從哪裡開始？': 'Where should the cut start?',
    '轉折處如何操作？': 'How should the bend be handled?',
    '裁切在哪裡結束？': 'Where should the cut finish?',
    '組裝第一步放置什麼？': 'What should be placed first during assembly?',
    '連接件應如何放置？': 'How should the connector be positioned?',
    '提交前檢查什麼？': 'What should be checked before confirming?',
    '左側塗層要達到什麼？': 'What should the coating on the left side achieve?',
    '中間區域如何處理？': 'How should the middle area be treated?',
    '右側完成後如何確認？': 'How should the right side be checked when finished?',
    '第 1 針應穿過哪裡？': 'Where should the first stitch pass through?',
    '第 2 針如何接續？': 'How should the second stitch continue?',
    '收線前最後一針放在哪裡？':
        'Where should the final stitch go before securing the thread?',
    '交織第 1 段怎麼放？': 'How should the first woven section be placed?',
    '交織第 2 段放在哪裡？': 'Where should the second woven section go?',
    '最後一段要注意什麼？': 'What should be considered for the final section?',
    '先校準哪一處？': 'Which part should be aligned first?',
    '接縫或直角如何確認？': 'How should the seam or right angle be checked?',
    '完成定位前最後檢查什麼？': 'What should be checked before final alignment?',
    '加固前要先對齊哪裡？': 'Which parts should be aligned before reinforcing?',
    '兩塊加固板如何固定？': 'How should the two reinforcing boards be secured?',
    '完成後要檢查什麼？': 'What should be checked after reinforcement?',
    '第一道隔熱布如何固定？':
        'How should the first layer of insulation fabric be secured?',
    '接縫如何保持密合？': 'How should the seam be kept tight?',
    '封口前最後檢查什麼？': 'What should be checked before sealing?',
    '固定磨損纖維': 'Secure the worn fibres',
    '補入完整線材': 'Add intact thread',
    '收緊並檢查接縫': 'Tighten and inspect the seam',
    '控制初段熱度': 'Control the initial heat',
    '維持均勻乾燥': 'Keep the drying even',
    '避免過熱收尾': 'Finish without overheating',
    '以過濾水潤濕布邊料': 'Dampen the cloth scrap with filtered water',
    '沿鏽斑方向擦拭': 'Wipe along the rust marks',
    '以乾淨布面收尾': 'Finish with a clean part of the cloth',
    '均勻預熱塑料': 'Preheat the plastic evenly',
    '控制熱壓區間': 'Keep the heat press within range',
    '平穩冷卻收尾': 'Finish with a steady cooldown',
    '移除表面煙垢': 'Remove soot from the surface',
    '控制乾燥熱度': 'Control the drying temperature',
    '確認燃料狀態': 'Check the fuel condition',
    '校正板件端點': 'Align the board ends',
    '對準偏斜接縫': 'Align the skewed joint',
    '固定定位': 'Secure the alignment',
  };

  /// Versioned recipe instructions stay in the content pack's source locale.
  /// Translate them only when they cross into the player-facing UI.
  static const Map<String, String> _operationInstructionsEn = {
    '針具／沿縫線拆線': 'Needle / unpick along the seam',
    '無／接線理結': 'None / join and knot the thread ends',
    '針具／對孔縫補': 'Needle / align the holes and sew',
    '針具／方向對齊縫合': 'Needle / align the direction and stitch',
    '無／三股編織': 'None / braid three strands',
    '無／維持張力': 'None / maintain tension',
    '分類台固定漿槽／攪拌': 'Sorting station with fixed pulp vat / stir',
    '漿槽／調濃度': 'Pulp vat / adjust the consistency',
    '固定夾具／排紋塗膠壓合': 'Fixed clamp / align the grain, apply adhesive, and press',
    '固定錘具／敲擊定位': 'Fixed hammer / hammer into alignment',
    '直角夾具／校準固定': 'Right-angle clamp / align and secure',
    '固定錘具、熱源／整形': 'Fixed hammer and heat source / reshape',
    '固定模具、熱源／熱壓': 'Fixed mold and heat source / heat-press',
    '固定工作站提供抄紙模具；三步對位與刮平':
        'The workbench supplies a fixed papermaking mould; align and level the sheet in three steps',
    '工作台塗具／均勻塗抹': 'Workbench applicator / spread evenly',
    '無／清洗覆蓋': 'None / wash and cover',
    '固定回收槽／確認分類': 'Fixed recycling bin / confirm the sorting',
    '固定錘具、夾具／組裝': 'Fixed hammer and clamp / assemble',
    '針具／縫補受力接縫': 'Needle / reinforce the load-bearing seam',
    '8 秒，拖動分層邊界；原瓶回裝濁水，泥料占新格':
        '8 sec. Drag the layer boundary. The original bottle is refilled with turbid water; mud occupies a new grid cell.',
    '10 秒，粗濾／炭層／接水順序；新濾布固定 20 次可用':
        '10 sec. Follow the coarse-filter, charcoal-layer, and water-collection order. New filter cloth has 20 fixed uses.',
    '同過濾操作，明示污染處理史；不能直接當料理水；成功保留瓶身 ID 並加上需煮沸旗標':
        'Use the same filtering steps and retain the contamination history. Not safe for cooking until boiled. On success, keep the bottle ID and set the must-boil flag.',
    '10 秒，三段控火並逐段保存 checkpoint；容器原先須裝有過濾水，成功時同瓶轉為開水並移除 requiresBoiling':
        '10 sec. Complete and save three heat-control checkpoints. The vessel must contain filtered water; success turns it into boiled water in the same bottle and clears requiresBoiling.',
    '15 秒，接管及控火；三段熱控檢查點；保留水質數值，低礦物特性用於精密清潔':
        '15 sec. Connect the condenser and control the heat through three checkpoints. Preserve water-quality values; its low-mineral property is for precision cleaning.',
    '6 秒，逆向沖洗；原型最多洗 2 次，之後回收成布邊料 1':
        '6 sec. Rinse in reverse. The prototype can be washed at most twice, then recycled into 1 cloth scrap.',
    '8 秒，裁邊並縫合；針具保留': '8 sec. Trim the edges and sew; the needle is retained.',
    '10 秒，沿魚骨切分；碼頭固定刀具':
        '10 sec. Cut along the fish bones using the dock’s fixed knife.',
    '8 秒，三段手動挑除、沖洗、檢查；3點精準產生 `rich_ingredient`，2點完成不加詞條；過濾水作為容器內容消耗，原瓶／罐留在棋盤並變空':
        '8 sec. Manually sort, rinse, and inspect in three steps. Three precise hits add rich_ingredient; two hits complete the task without a trait. Filtered water is consumed from the vessel, which remains on the board empty.',
    '6 秒，挑葉與整理；原型直接完成':
        '6 sec. Pick out and arrange the leaves; the prototype completes immediately.',
    '6 秒，拌勻分份；固定餌盆':
        '6 sec. Mix evenly and portion using the fixed bait basin.',
    '6 秒，配比；餌盆': '6 sec. Measure the proportions using the bait basin.',
    '6 秒，分類並排列引火物': '6 sec. Sort and arrange the kindling.',
    '8 秒，選擇通風位置；站點乾燥架，無離線等待':
        '8 sec. Choose a ventilated spot on the station drying rack; no real-time waiting while offline.',
    '8 秒，壓實成塊': '8 sec. Compress into a solid block.',
    '12 秒，調節遊戲炭爐；非現實操作教學':
        '12 sec. Adjust the in-game charcoal stove; this is not real-world instruction.',
    '10 秒，攪拌至稠度提示': '10 sec. Stir until the consistency cue appears.',
    '12 秒，控火攪拌；固定鍋具':
        '12 sec. Control the heat and stir using the fixed cooking pot.',
    '12 秒，分次下料；沿用同一水瓶與所選餐盒，水瓶留空':
        '12 sec. Add ingredients in batches. Reuse the same bottle and selected meal box; the bottle is left empty.',
    '12 秒，起鍋時機；沿用同一水瓶與所選餐盒，水瓶留空':
        '12 sec. Time when to remove the pot from heat. Reuse the same bottle and selected meal box; the bottle is left empty.',
    '15 秒，依序備料；開水作為容器內容消耗，原瓶／罐留在棋盤並變空；魚肉可用清理食材 2 替代':
        '15 sec. Prepare ingredients in order. Boiled water is consumed from the vessel, which remains on the board empty. Two cleaned ingredients may replace the fish meat.',
    '擦拭分離可用片；用過布料消耗，金屬片供工具與餐盒':
        'Wipe and separate usable pieces. Used cloth is consumed; metal sheets are used for tools and meal boxes.',
    '遊戲模具熱成形；明示是簡化加工，不作現實金屬工法教學':
        'Shape with the in-game mold and heat. This is simplified crafting, not real-world metalworking instruction.',
    '整形；供釘件與工具，不需另一高階工具':
        'Reshape for fasteners and tools; no additional advanced tool is required.',
    '沿線裁切；供扣件與釣鉤': 'Cut along the marked line for fasteners and fishing hooks.',
    '輪廓彎折；供箱櫃與釣竿': 'Bend to the outline for storage chests and fishing rods.',
    '卷壓接縫；供工具柄': 'Roll-press the seam for tool handles.',
    '彎鉤校準；不要求未知「鉤尖」材料':
        'Bend and calibrate the hook; no undefined “hook tip” material is required.',
    '裝配；工具修理與浮標委託': 'Assemble for tool repairs and float orders.',
    '塗層壓接；供冷凝器及棚架':
        'Apply and press the coating for condensers and shelter frames.',
    '封邊；僅防潮，不聲稱可裝液體':
        'Seal the edges for moisture resistance only; it is not liquid-proof.',
    '雙層縫製；針具保留，供餐盒與炊具':
        'Sew two layers together. The needle is retained; used for meal boxes and cooking gear.',
    '接線與張力測試；供釣竿，粗繩不能代替細釣線':
        'Join the line and test its tension for fishing rods. Coarse rope cannot replace fine fishing line.',
    '固定拆料工具；失手碎木片 1 + 木屑 2，不保留原漂木':
        'Use the fixed dismantling tool. A miss yields 1 wood chip and 2 sawdust; the original driftwood is not retained.',
    '確認後拆板，無操作加成；原品質上限保留':
        'Confirm to dismantle the board. There is no action bonus; the original quality cap is retained.',
    '定位包覆；`toolpart.handle`，1×2':
        'Position and wrap; produces toolpart.handle, size 1×2.',
    '裝配撬頭；供額外翻找分支，1×2':
        'Assemble the pry head for an additional scavenging branch, size 1×2.',
    '校準鉗口；`tool.pliers`，1×2，分類精準操作容錯 +10%':
        'Calibrate the jaws; produces tool.pliers, size 1×2, with +10% tolerance for precise sorting.',
    '裝入工具袋；`tool.kit`，2×2，保留內含工具身份，使用時只磨耗所用工具':
        'Pack into a tool kit, size 2×2. Tool identities are retained; only the tool used loses durability.',
    '裝釣組；階段 2 可重領入門釣竿，製作不是入門門檻':
        'Assemble the fishing rig. A starter rod can be reclaimed in Phase 2; crafting is not an entry requirement.',
    '保留原 instance 作升級；1×3，收線容錯 +10%':
        'Upgrade the original instance; size 1×3, with +10% tolerance when reeling in.',
    '`tool.rod_advanced`，1×3，收線容錯 +20%，不與原竿 +10% 疊加':
        'Produces tool.rod_advanced, size 1×3, with +20% reeling tolerance; it does not stack with the original rod’s +10%.',
    '`toolpart.rig`，1×1；一次消耗可修復釣竿 10 次使用量':
        'Produces toolpart.rig, size 1×1; one use restores 10 uses to a fishing rod.',
    '固定裝柄；金屬條 1 可替代魚骨，供修理與工具訂單':
        'Fit the handle securely. One metal bar may replace fish bones; used for repairs and tool orders.',
    '`toolpart.float`，1×2；原瓶鎖入浮標不能同時裝水；可拆回原瓶，繩不退':
        'Produces toolpart.float, size 1×2. The bottle locked into the float cannot hold water; it can be dismantled back into the original bottle, but the rope is not returned.',
    '`structure.raft`，2×2；碼頭委託與釣點設施，釣魚保底不依賴它':
        'Produces structure.raft, size 2×2, for dock orders and fishing-site facilities. Fishing pity does not depend on it.',
    '`structure.tarp`，2×2；住所與街坊委託，不以普通拼接布冒充防水':
        'Produces structure.tarp, size 2×2, for housing and neighborhood orders; ordinary patchwork is not treated as waterproof.',
    '`structure.shelter`，2×2；新街區住處目標，放置佔家具位 1':
        'Produces structure.shelter, size 2×2, for the new-neighborhood housing goal; placement uses one furniture slot.',
    '`tool.pot`，2×2；罐變成鍋具，不再作瓶；料理站初次直接給固定鍋':
        'Produces tool.pot, size 2×2. The jar becomes a pot and is no longer a bottle; a fixed pot is provided when the cooking station first unlocks.',
    '`tool.stove`，2×2；與鍋具搭配供炊具委託，不解鎖額外未定義燃料折扣':
        'Produces tool.stove, size 2×2, for cooking-gear orders with a pot; it grants no undefined fuel discount.',
    '`tool.cook_kit`，2×3；包裝型委託，首版不增加野外烹煮系統':
        'Produces tool.cook_kit, size 2×3, for packaged orders; the first release adds no outdoor cooking system.',
    '模具壓整；成品 clean、1×2；不用玻璃瓶憑空變餐盒':
        'Press in a mold to produce a clean item, size 1×2; a glass bottle does not become a meal box without materials.',
    '原 instance 升級；保溫包裝委託總報酬 8 交換券，不加恢復倍數':
        'Upgrade the original instance. The insulated-packaging order pays 8 exchange tickets total; no recovery multiplier is added.',
    '8 秒分裝；1×2，包材消耗；可拆回魚肉 2，品質不提升、包材不返還':
        '8 sec. Portion into size 1×2; packaging is consumed. Dismantling returns 2 fish meat, without quality gain or packaging recovery.',
    '容量 20、家具位 1；已放置箱先指定內容搬移位置，滿箱不能作輸入':
        'Capacity 20, uses one furniture slot. Choose where to move stored items before replacing a placed chest; a full chest cannot be used as an input.',
    '`bag.weatherproof`，背包 6×4，保留原座標；前置修補背包，一次性':
        'Produces bag.weatherproof, a 6×4 backpack that preserves existing coordinates; requires a repaired backpack and is one-time.',
    '2×2，罐成為裝置的一部分；保留工具不產額外空罐':
        'Size 2×2. The jar becomes part of the device; retained tools do not create an extra empty jar.',
    '`seasoning.blend`，1×1；可替代調味包，品質加分仍為 +3，不重複疊加':
        'Produces seasoning.blend, size 1×1, as an alternative to a seasoning packet; the quality bonus remains +3 and does not stack.',
    '`fuel.efficient_pack`，1×2，提供 3 燃料單位；製作不增加總能量，只省空間':
        'Produces fuel.efficient_pack, size 1×2, containing 3 fuel units; crafting does not increase total energy, it only saves space.',
  };

  /// Canonical failure outcomes stay in the content pack source locale and are
  /// translated only at the player-facing boundary.
  static const Map<String, String> _recipeFailureOutcomesEn = {
    '布邊料 1 + 線頭 1；原布已拆，不保留原件':
        '1 cloth offcut and 1 thread end; the original cloth was dismantled and is not retained.',
    '線頭 2；其中 1 份剪除損耗，重試需補足':
        '2 thread ends; 1 is lost to trimming and must be replaced before retrying.',
    '成品保留；重縫另耗線團 1，修正該接縫而非免費提高原布品質':
        'The item is retained. Restitching consumes 1 thread spool and repairs the seam; it does not freely raise the original cloth quality.',
    '成品保留；套再生結構折損':
        'The item is retained with a recycled-structure quality penalty.',
    '成品保留；不可再拆回完整布片':
        'The item is retained and cannot be dismantled back into an intact cloth piece.',
    '成品保留；同一輸入不額外補扣線':
        'The item is retained; thread is not charged again for the same input.',
    '紙漿保留；已混合紙水不可退回；過濾水可等量替代':
        'The pulp is retained; mixed paper water cannot be recovered. An equal amount of filtered water may be substituted.',
    '膠料保留並降低品質；標籤殘膠可重複翻找':
        'The adhesive is retained at lower quality; label residue can be scavenged repeatedly.',
    '成品保留；膠料消耗；階段 4 可等量用澱粉糊替代，屬遊戲簡化':
        'The item is retained and adhesive is consumed. In Phase 4, an equal amount of starch paste may substitute; this is a game simplification.',
    '成品保留；精準得釘固加強，失手得釘固偏斜':
        'The item is retained; a precise action reinforces the nails, while a miss leaves them skewed.',
    '成品保留；沒有「膠或釘任選」隱藏替代':
        'The item is retained; there is no hidden adhesive-or-nail substitution.',
    '金屬碎片 1；燃料消耗，無釘件產出；釘件也可常見拾得':
        '1 metal fragment; fuel is consumed, no nails are produced, and nails can also be found through ordinary scavenging.',
    '成品保留；燃料消耗，再加工需新燃料':
        'The item is retained and fuel is consumed; another attempt needs fresh fuel.',
    '失手仍產出乾燥紙板，但品質降低 10；兩份紙漿消耗，模具留在工作站':
        'A miss still produces dried paperboard at 10 lower quality; both pulp units are consumed and the mould stays at the workbench.',
    '成品保留；塗料已消耗，不可退回':
        'The item is retained; the coating has been consumed and cannot be refunded.',
    '漏洗留下完整舊瓶 1，水消耗；重新洗需新水':
        'The original bottle remains intact; the water is consumed, and another wash needs fresh water.',
    '無操作損失；玻璃碎料可交重複回收委託':
        'No materials are lost; glass shards can be used for repeat recycling orders.',
    '成品保留；品質不減少收納格數':
        'The item is retained; quality does not change its storage-cell size.',
    '失手仍完成升級，不減格；原型只允許此升級一次，不產第二個背包':
        'The upgrade still completes on a miss without reducing capacity. The prototype allows this upgrade once and does not create a second backpack.',
    '偏差仍得濁水與泥料，但濁水品質 −10；無真實時間等待':
        'A miss still yields turbid water and mud, but water quality is reduced by 10; no real-time wait is used.',
    '失手仍為原瓶濁水，炭消耗、濾布使用 1 次；可重試':
        'The original bottle still contains turbid water; charcoal is consumed and filter cloth loses 1 use. You may retry.',
    '失手仍為原瓶髒水，炭與濾布次數照扣；不丟瓶':
        'The original bottle still contains dirty water; charcoal and one filter-cloth use are consumed, but the bottle is kept.',
    '失手保留原容器過濾水及旗標、燃料消耗；不能以品質等級代替成功旗標':
        'The original container keeps its filtered water and status flag; fuel is consumed. Quality cannot substitute for the success flag.',
    '失手保留原瓶過濾水、燃料全耗；冷凝器保留；非主線必要':
        'The original bottle keeps its filtered water; all fuel is consumed and the condenser is retained. This is not required for the main story.',
    '失手不恢復次數，水消耗，不扣洗滌成功次數':
        'A miss does not restore a use; water is consumed, but no successful-wash count is deducted.',
    '失手仍產濾布，初始可用次數 15；不改可過濾水種':
        'A miss still produces filter cloth with 15 uses; it does not change which water types can be filtered.',
    '魚肉 1 + 魚骨 1 + 食物碎屑 1；整魚已消耗':
        '1 fish meat, 1 fish bone, and 1 food scrap; the whole fish is consumed.',
    '調味包 1，品質 −10': '1 seasoning pack; quality is reduced by 10.',
    '基礎魚餌 1；不需犧牲攜帶容器': '1 basic bait; no carried container is sacrificed.',
    '基礎魚餌 1，香草消耗': '1 basic bait; the herbs are consumed.',
    '混合燃料 2，品質 −10；可用不報廢':
        '2 mixed fuels; quality is reduced by 10, but the fuel remains usable.',
    '乾燥燃料 1 + 混合燃料 1': '1 dry fuel and 1 mixed fuel are produced.',
    '混合燃料 1': '1 mixed fuel is produced.',
    '木炭 1；所有投入消耗': '1 charcoal; all inputs are consumed.',
    '澱粉糊 1；水、燃料已耗': '1 starch paste; the water and fuel have been consumed.',
    '所選同一餐盒裝入失敗餐；不退主材料、水或燃料，原水瓶留空':
        'The failed meal goes into the selected meal box. Main ingredients, water, and fuel are not refunded; the original bottle remains empty.',
    '失敗餐裝回原餐盒；全部投入消耗，不新增容器':
        'The failed meal goes into the original meal box; all inputs are consumed and no new container is created.',
    '失敗餐裝回原餐盒；不因魚較稀有而退回原魚，不新增容器':
        'The failed meal goes into the original meal box; the fish is not refunded for being rare, and no new container is created.',
    '沿用章節17.3通則：產出主物品，品質−10；按配方扣除已確認消耗的輸入與輔料。':
        'Uses the Chapter 17.3 rule: the main item is produced at quality −10, and confirmed recipe inputs and auxiliary materials are consumed.',
    '確認式操作不進入失誤分支。': 'Confirmation-only actions do not have a failure branch.',
  };

  static const Map<String, String> _recipeQualityModesEn = {
    'weighted-primary': 'weighted by primary-material quality',
    'capped-at-primary': 'capped at primary-material quality',
    'preserve-primary': 'preserves primary-material quality',
  };

  static const Map<String, String> _itemNamesZhHant = {
    'cloth.rag_piece': '破布片',
    'cloth.edge_scrap': '布邊料',
    'cloth.repair_strip': '縫補布條',
    'cloth.patchwork': '拼接布',
    'cloth.thread_spool': '線團',
    'cloth.thread_end': '線頭',
    'cloth.binding': '綁帶',
    'rope.coarse': '粗繩',
    'line.fishing': '釣線',
    'cloth.waterproof': '防水布',
    'cloth.insulation': '隔熱布',
    'wood.chip': '碎木片',
    'wood.sawdust': '木屑',
    'wood.driftwood': '漂木',
    'wood.rod': '木條',
    'wood.board': '木板',
    'wood.frame': '木框',
    'adhesive.residue': '標籤殘膠',
    'adhesive.recycled': '回收膠料',
    'adhesive.starch_paste': '澱粉糊',
    'metal.scrap': '金屬屑',
    'metal.shard': '金屬碎片',
    'metal.sheet': '金屬片',
    'metal.bar': '金屬條',
    'metal.wire': '鐵線',
    'metal.nail_bundle': '釘件束',
    'metal.fastener': '金屬扣',
    'metal.ferrule': '套環',
    'metal.hook': '釣鉤',
    'plastic.scrap': '塑料碎片',
    'plastic.sheet': '塑料片',
    'plastic.float_part': '浮標零件',
    'plastic.seal': '防水接頭',
    'paper.scrap': '紙屑',
    'paper.pulp': '紙漿',
    'paper.board': '乾燥紙板',
    'paper.packaging': '防潮包材',
    'water.turbid': '濁水',
    'water.dirty': '髒水',
    'water.muddy': '泥水',
    'water.filtered': '過濾水',
    'water.boiled': '開水',
    'water.distilled': '蒸餾水',
    'water.mineral': '礦泉水',
    'material.mineral_pack': '礦物包',
    'material.mud': '泥料',
    'material.charcoal': '木炭',
    'material.filter_cloth': '濾布',
    'material.waterproof_coating': '防水塗料',
    'material.glass_scrap': '玻璃碎料',
    'fish.raw': '整魚',
    'fish.meat': '魚肉',
    'fish.bone': '魚骨',
    'fish.pack': '魚貨包',
    'food.scrap': '食物碎屑',
    'food.greens': '野菜',
    'food.edible': '可食拾得物',
    'food.cleaned': '清理食材',
    'food.starch': '澱粉食材',
    'herb.wild': '香草',
    'seasoning.salt': '鹽',
    'seasoning.packet': '調味包',
    'seasoning.blend': '綜合香料',
    'fuel.mixed': '混合燃料',
    'fuel.dry': '乾燥燃料',
    'fuel.oilcloth': '可燃油布',
    'fuel.efficient_pack': '節能燃料包',
    'container.broken_bottle': '破瓶',
    'container.used_intact': '完整舊瓶',
    'container.clean': '清潔容器',
    'container.clean_jar': '清潔罐',
    'container.meal_box': '餐盒',
    'container.meal_box_insulated': '保溫餐盒',
    'bag.basic': '起始背包',
    'bag.reinforced': '修補背包',
    'bag.weatherproof': '耐候收納袋',
    'storage.wooden_crate': '木箱',
    'storage.reinforced_chest': '加固箱櫃',
    'bait.basic': '基礎魚餌',
    'bait.herb': '香草餌',
    'tool.needle': '針具',
    'tool.paper_mould': '抄紙模具',
    'tool.awl': '修補錐',
    'tool.crowbar': '撬具',
    'tool.pliers': '分類鉗',
    'tool.kit': '維修工具組',
    'tool.rod_basic': '簡易釣竿',
    'tool.rod_repaired': '修補釣竿',
    'tool.rod_advanced': '改良釣竿',
    'tool.pot': '簡易鍋具',
    'tool.stove': '便攜爐架',
    'tool.cook_kit': '外出料理組',
    'tool.condenser': '冷凝器',
    'toolpart.handle': '工具柄',
    'toolpart.rig': '備用釣組',
    'toolpart.float': '簡易浮標',
    'structure.raft': '小型浮架',
    'structure.tarp': '避雨棚布',
    'structure.shelter': '可折雨棚',
    'meal.soup_basic': '基礎湯',
    'meal.soup_fish': '魚湯',
    'meal.soup_vegetable': '素食湯',
    'meal.shared': '共享餐',
    'meal.failed': '失敗餐',
    'meal.relief_box': '政府救助便當',
    'bundle.cloth_scrap': '布邊料束',
    'bundle.thread_end': '線頭束',
    'bundle.wood_chip': '碎木片束',
    'bundle.metal_scrap': '金屬屑束',
    'bundle.plastic_scrap': '塑料碎片束',
    'bundle.paper_scrap': '紙屑束',
  };

  static const Map<String, String> _itemNamesEn = {
    'cloth.rag_piece': 'Rag piece',
    'cloth.edge_scrap': 'Cloth offcut',
    'cloth.repair_strip': 'Mended cloth strip',
    'cloth.patchwork': 'Patchwork cloth',
    'cloth.thread_spool': 'Thread spool',
    'cloth.thread_end': 'Thread ends',
    'cloth.binding': 'Binding strip',
    'rope.coarse': 'Coarse rope',
    'line.fishing': 'Fishing line',
    'cloth.waterproof': 'Waterproof cloth',
    'cloth.insulation': 'Insulating cloth',
    'wood.chip': 'Wood chips',
    'wood.sawdust': 'Sawdust',
    'wood.driftwood': 'Driftwood',
    'wood.rod': 'Wooden slat',
    'wood.board': 'Wooden board',
    'wood.frame': 'Wooden frame',
    'adhesive.residue': 'Label adhesive residue',
    'adhesive.recycled': 'Recycled adhesive',
    'adhesive.starch_paste': 'Starch paste',
    'metal.scrap': 'Metal scrap',
    'metal.shard': 'Metal shard',
    'metal.sheet': 'Metal sheet',
    'metal.bar': 'Metal bar',
    'metal.wire': 'Wire',
    'metal.nail_bundle': 'Nail bundle',
    'metal.fastener': 'Metal fastener',
    'metal.ferrule': 'Ferrule',
    'metal.hook': 'Fishing hook',
    'plastic.scrap': 'Plastic scrap',
    'plastic.sheet': 'Plastic sheet',
    'plastic.float_part': 'Float component',
    'plastic.seal': 'Waterproof connector',
    'paper.scrap': 'Paper scraps',
    'paper.pulp': 'Paper pulp',
    'paper.board': 'Dried paperboard',
    'paper.packaging': 'Moisture-resistant packaging',
    'water.turbid': 'Turbid water',
    'water.dirty': 'Dirty water',
    'water.muddy': 'Muddy water',
    'water.filtered': 'Filtered water',
    'water.boiled': 'Boiled water',
    'water.distilled': 'Distilled water',
    'water.mineral': 'Mineral water',
    'material.mineral_pack': 'Mineral pack',
    'material.mud': 'Mud material',
    'material.charcoal': 'Charcoal',
    'material.filter_cloth': 'Filter cloth',
    'material.waterproof_coating': 'Waterproof coating',
    'material.glass_scrap': 'Glass fragments',
    'fish.raw': 'Whole fish',
    'fish.meat': 'Fish meat',
    'fish.bone': 'Fish bones',
    'fish.pack': 'Fish catch bundle',
    'food.scrap': 'Food scraps',
    'food.greens': 'Wild greens',
    'food.edible': 'Foraged edible',
    'food.cleaned': 'Cleaned ingredients',
    'food.starch': 'Starchy ingredients',
    'herb.wild': 'Wild herbs',
    'seasoning.salt': 'Salt',
    'seasoning.packet': 'Seasoning packet',
    'seasoning.blend': 'Mixed seasoning',
    'fuel.mixed': 'Mixed fuel',
    'fuel.dry': 'Dried fuel',
    'fuel.oilcloth': 'Oiled burnable cloth',
    'fuel.efficient_pack': 'Efficient fuel pack',
    'container.broken_bottle': 'Broken bottle',
    'container.used_intact': 'Intact used bottle',
    'container.clean': 'Clean container',
    'container.clean_jar': 'Clean jar',
    'container.meal_box': 'Meal box',
    'container.meal_box_insulated': 'Insulated meal box',
    'bag.basic': 'Starter backpack',
    'bag.reinforced': 'Reinforced backpack',
    'bag.weatherproof': 'Weatherproof storage bag',
    'storage.wooden_crate': 'Wooden crate',
    'storage.reinforced_chest': 'Reinforced chest',
    'bait.basic': 'Basic bait',
    'bait.herb': 'Herb bait',
    'tool.needle': 'Needle',
    'tool.paper_mould': 'Papermaking mould',
    'tool.awl': 'Mending awl',
    'tool.crowbar': 'Crowbar',
    'tool.pliers': 'Sorting pliers',
    'tool.kit': 'Repair kit',
    'tool.rod_basic': 'Basic fishing rod',
    'tool.rod_repaired': 'Repaired fishing rod',
    'tool.rod_advanced': 'Improved fishing rod',
    'tool.pot': 'Simple cooking pot',
    'tool.stove': 'Portable stove frame',
    'tool.cook_kit': 'Field cooking kit',
    'tool.condenser': 'Condenser',
    'toolpart.handle': 'Tool handle',
    'toolpart.rig': 'Spare fishing rig',
    'toolpart.float': 'Simple float',
    'structure.raft': 'Small floating platform',
    'structure.tarp': 'Rain tarp',
    'structure.shelter': 'Foldable shelter',
    'meal.soup_basic': 'Basic soup',
    'meal.soup_fish': 'Fish soup',
    'meal.soup_vegetable': 'Vegetable soup',
    'meal.shared': 'Shared meal',
    'meal.failed': 'Failed meal',
    'meal.relief_box': 'Government relief bento',
    'bundle.cloth_scrap': 'Cloth offcut bundle',
    'bundle.thread_end': 'Thread-end bundle',
    'bundle.wood_chip': 'Wood-chip bundle',
    'bundle.metal_scrap': 'Metal-scrap bundle',
    'bundle.plastic_scrap': 'Plastic-scrap bundle',
    'bundle.paper_scrap': 'Paper-scrap bundle',
  };

  /// Localized item names; unknown IDs stay visible for forward compatibility.
  String itemName(String itemId) {
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    final names = normalizedLocale == 'en' || normalizedLocale.startsWith('en-')
        ? _itemNamesEn
        : _itemNamesZhHant;
    final contentId = itemId.startsWith('content:')
        ? itemId.substring('content:'.length)
        : itemId;
    final canonicalId = contentId == 'container.bottle_clean'
        ? 'container.clean'
        : contentId;
    return names[canonicalId] ?? itemId;
  }

  String itemSource(String source) {
    final normalized = source.toLowerCase();
    final crafted =
        normalized.contains('crafted') ||
        normalized.contains('recycled') ||
        source.contains('加工');
    return text(crafted ? 'board.itemSourceCrafted' : 'board.itemSourceFound');
  }

  String itemQuality(int score) {
    final tierKey = switch (score) {
      < 40 => 'board.qualityPoor',
      < 70 => 'board.qualityOrdinary',
      < 90 => 'board.qualityGood',
      _ => 'board.qualityExcellent',
    };
    return text(
      'board.itemQuality',
      arguments: {'tier': text(tierKey), 'score': '$score'},
    );
  }

  static const Map<String, String> _zhHant = {
    'game.title': '街角拾荒',
    'entry.loginExpired': '登入狀態已失效，請重新登入後再開啟。',
    'entry.saveLoadFailed': '存檔無法載入；原始資料尚未修改。',
    'entry.saveLoadAdvice': '請返回遊戲庫後再試；不要清除本機資料。若問題持續，請先保留存檔並尋求協助。',
    'entry.contentLoadFailed': '已安裝的街區內容無法讀取；本機存檔未修改。',
    'entry.contentLoadAdvice': '請返回遊戲庫檢查或重新下載內容包；本機存檔不會因此變更。',
    'entry.rulesLoadFailed': '探索規則內容無法載入；本機存檔未修改。',
    'entry.backToLibrary': '返回遊戲庫',
    'entry.loaded': '本機存檔已載入',
    'entry.noProgress': '尚無遊戲進度。',
    'entry.progressVersion': '進度版本 {revision}；最後保存 {savedAt}',
    'entry.readOnlyTitle': '此存檔已在另一個分頁開啟，目前為唯讀。',
    'entry.readOnlyBody': '關閉另一個分頁後重新開啟本頁即可取得寫入權。',
    'entry.contentNotInstalled': '街區內容尚未安裝。本機進度仍保留；下載內容後才能開始遊玩。',
    'entry.openLibrary': '前往遊戲庫',
    'settings.title': '遊戲設定',
    'transfer.title': '存檔轉移',
    'transfer.description': '存檔只會在這台裝置產生檔案；匯入前會先檢查版本與物品位置。',
    'transfer.export': '匯出存檔',
    'transfer.import': '匯入存檔',
    'transfer.exporting': '匯出中…',
    'transfer.choosing': '選擇存檔中…',
    'transfer.importing': '檢查存檔中…',
    'transfer.exportTitle': '匯出街角拾荒存檔',
    'transfer.importTitle': '選擇街角拾荒存檔',
    'transfer.exported': '存檔檔案已匯出。',
    'transfer.exportFailed': '存檔匯出失敗。',
    'transfer.reviewTitle': '檢查這份存檔',
    'transfer.reviewBody':
        '第 {chapter} 階段・存檔版本 {revision}\n保存時間：{savedAt}\n規則版本：{ruleset}\n\n確認後會先保留目前存檔，再匯入這份進度。',
    'transfer.cancel': '取消',
    'transfer.confirmImport': '確認匯入',
    'transfer.imported': '存檔已匯入；先前進度可從存檔恢復頁找回。',
    'transfer.importFailed': '存檔無法匯入。版本不符或資料無效時，原進度會保留。',
    'supplies.title': '固定補給點',
    'supplies.repeatable': '依章節解鎖，可重複取得；確認後才消耗體力。',
    'supplies.repeatableShort': '可重複補給',
    'supplies.availableTitle': '街區補給',
    'supplies.quantitySemantics': '數量 {quantity}',
    'supplies.staminaSemantics': '消耗體力 {stamina}',
    'supplies.details': '取得 {quantity} 件・消耗體力 {stamina}',
    'supplies.claim': '前往取得',
    'supplies.working': '領取中…',
    'supplies.chooseVessel': '選擇要裝水的清潔空容器',
    'supplies.confirmTitle': '確認取得補給',
    'supplies.confirmBody': '取得 {item} ×{quantity}，消耗體力 {stamina}。',
    'supplies.claimed': '已取得 {item} ×{quantity}',
    'supplies.publicWashTitle': '公共水槽・清洗空瓶',
    'supplies.publicWashCost': '直接使用水槽清洗，不耗瓶中水；消耗體力 2。',
    'supplies.publicRefillTitle': '公共水槽・裝過濾水',
    'supplies.publicRefillCost': '選一個清潔空容器裝水，消耗體力 2。',
    'supplies.cleanEmptyVessel': '清潔空容器',
    'supplies.noWaterVessels': '先從街區帶回一個可重用容器。',
    'supplies.fillTitle': '裝入過濾水？',
    'supplies.fillBody': '使用公共補水點裝水，消耗體力 {stamina}。',
    'supplies.fillAction': '裝水・2 體力',
    'supplies.fillComplete': '已裝入過濾水，容器仍可重複使用。',
    'supplies.emptyVessel': '空瓶・待清洗',
    'supplies.washTitle': '清洗這個空瓶？',
    'supplies.washBody': '使用公共水槽清洗，不消耗瓶中水；消耗體力 {stamina}。',
    'supplies.washAction': '清洗・2 體力',
    'supplies.washComplete': '空瓶已清洗，可再次裝水。',
    'supplies.error.alreadyClean': '這個容器已經清潔，不需要清洗。',
    'supplies.error.notEmpty': '請先倒空容器，再使用公共水槽。',
    'supplies.error.stamina': '體力不足；補給尚未取得。',
    'supplies.error.backpackSpace': '背包放不下這批補給；先移幾件到工作棋盤或箱櫃。',
    'supplies.organize': '整理',
    'supplies.error.vessel': '請選擇仍在棋盤或背包中的清潔空容器。',
    'supplies.error.locked': '此補給尚未解鎖。',
    'supplies.error.generic': '補給未能領取，存檔未變更；整理後再試。',
    'settings.close': '關閉',
    'settings.extraTextScale': '遊戲額外字級：{percent}%',
    'settings.reduceMotion': '減少介面動畫',
    'settings.reduceMotionDescription': '保留操作結果，減少轉場動畫效果。',
    'settings.assistedControls': '操作輔助：文字點選',
    'settings.assistedControlsDescription': '加工時展開可點選的文字目標，不降低品質上限。',
    'settings.soundVolume': '音效與音量',
    'settings.soundMuted': '遊戲音效已靜音。',
    'settings.soundEnabled': '本機遊戲音效・{percent}%。',
    'settings.save': '保存設定',
    'settings.saving': '保存中…',
    'settings.saveFailed': '設定保存失敗，原進度未變更，請稍後再試。',
    'settings.readOnly': '此存檔目前唯讀；關閉另一個分頁後重新開啟才能修改設定。',
    'collection.title': '收藏簿',
    'collection.count': '首次取得 {owned} / {total} 種物品',
    'recipes.known': '已知配方',
    'recipes.unlockedCount': '{known} / {total} 項已解鎖',
    'settings.scaleSummary': '字級 {percent}%',
    'settings.motionReduced': '減少動畫',
    'settings.motionNormal': '一般動畫',
    'settings.controlsAssisted': '文字操作輔助',
    'settings.controlsStandard': '標準操作',
    'board.title': '工作棋盤',
    'board.saveRevision': '存檔版本 {revision}・本機保存',
    'board.pendingMaintenance': '有一項去鏽操作尚未結算',
    'board.pendingCraft': '有一項加工尚未結算',
    'board.pendingSteps': '已保存 {done} / 3 個操作步驟；相關材料與工具已鎖定。',
    'board.cancelPending': '取消尚未開始的加工',
    'board.resumeCraft': '續作加工',
    'board.viewRecipes': '查看配方（{count}）',
    'board.materialIndex': '材料用途索引',
    'board.materialWorkspace': '素材工作區',
    'board.materialWorkspaceShort': '素材',
    'board.materialFocusMode': '放大素材',
    'board.materialGalleryBack': '返回棋盤與背包',
    'board.category.all': '全部素材',
    'board.category.wood': '木料',
    'board.category.cloth': '布料',
    'board.category.metal': '金屬',
    'board.category.water': '水',
    'board.category.food': '食物',
    'board.category.tools': '工具',
    'board.category.other': '其他',
    'board.moreMaterials': '更多素材',
    'board.previousMaterials': '上一批素材',
    'board.nextMaterials': '下一批素材',
    'board.workingGridShort': '工作台',
    'board.backpackGridShort': '背包',
    'board.workingGrid': '工作棋盤 6×6',
    'board.backpackGrid': '背包 4×4',
    'board.gridNameWorking': '工作棋盤',
    'board.gridNameBackpack': '背包',
    'board.moved': '物品已移動',
    'board.undoMove': '復原',
    'board.rotate': '旋轉物件',
    'board.clearSelection': '取消選取',
    'board.packCount': '打包成材料束（{count} 件）',
    'board.unpackBundle': '手動拆開材料束',
    'board.pendingItems': '待整理物品',
    'board.pendingItemsEmpty': '目前沒有待整理物品。之後在街區取得的物品會先出現在這裡。',
    'board.homeStorage': '地盤倉庫',
    'board.storageItem': '倉庫物品・取出需放入目前格盤',
    'board.instructionUnselected': '點選物品以選取；再切換格盤並點空格放置。',
    'board.instructionSelected': '已選取物品。切換格盤後點選目標位置；不合格的放置會被拒絕且不會扣除物品。',
    'board.error.craftLocked': '這件物品已保留給進行中的加工；請先完成或取消該操作。',
    'board.error.noSpace': '目前格盤沒有能完整放下物品的位置；物品仍保留原處。',
    'board.error.invalidPlacement': '這個位置不適合該物品，或存檔已在其他分頁更新；物品沒有移動。',
    'board.error.saveFailed': '本機保存失敗，物品沒有移動。請稍後重試。',
    'board.ownerLocation': '{grid}（{x}, {y}）',
    'board.ownerStorage': '存放於{storage}',
    'board.ownerPending': '待整理',
    'packing.title': '打包材料',
    'packing.contents': '以下 {count} 件 {input} 會收納成 {output}：',
    'packing.itemDetails': '• {location}・{source}・{quality}',
    'packing.identity': '每件物品會保留在材料束內，可手動拆開。',
    'packing.cancel': '取消',
    'packing.confirm': '確認打包',
    'mealPack.action': '裝入餐盒',
    'mealPack.chooseContainer': '選擇要使用的餐盒',
    'mealPack.containerOption': '{name}・同類第 {number} 件・{quality}',
    'mealPack.confirmTitle': '確認裝盒',
    'mealPack.confirmBody':
        '將 {meal}（{quality}）裝入 {container}。餐點會移入餐盒，餐盒本身可重複使用。',
    'mealPack.confirmAction': '裝入並保留餐盒',
    'mealPack.error.locked': '第5章內容尚未解鎖，無法裝盒。',
    'mealPack.error.notCooked': '這份餐點不是由共享餐配方完成，不能交付。',
    'mealPack.error.backpack': '請先把餐點與餐盒都放入背包。',
    'mealPack.error.container': '找不到可用的餐盒，請重新選擇。',
    'mealPack.error.notEmpty': '餐盒已有內容，請改選空餐盒。',
    'mealPack.error.needsCleaning': '餐盒需要先清洗才能裝入餐點。',
    'board.cellSemantics': '{grid}，第 {row} 行第 {column} 列，{state}{cursor}',
    'board.cellEmpty': '空格',
    'board.cellOccupied': '已占用',
    'board.cellCursor': '，目前游標',
    'board.cellHint': '點兩下放置已選物件，也可拖曳物件至此格。',
    'board.objectSemantics':
        '{grid}，第 {row} 行第 {column} 列起始，{name}，來源 {source}，{quality}，占格 {width} 乘 {height} 格',
    'board.objectHint': '點兩下選取；方向鍵移動、R 旋轉、Enter 放置，也可拖曳移動。',
    'board.itemMetadata': '來源 {source}・{quality}',
    'board.itemSemantics':
        '{name}，來源 {source}，{quality}，占格 {width} 乘 {height} 格{extra}',
    'board.itemSemanticsExtra': '，{subtitle}',
    'board.itemHint': '點兩下選取；可長按拖曳，或選取後用棋盤鍵盤操作。',
    'board.itemSourceFound': '原生／拾得',
    'board.itemSourceCrafted': '加工',
    'board.spriteSemantics': '{item}，{source}',
    'board.spriteSemanticsWithContents': '{item}，{source}，內含 {content}',
    'board.itemQuality': '品質 {tier}（{score}）',
    'board.qualityPoor': '粗劣',
    'board.qualityOrdinary': '普通',
    'board.qualityGood': '良好',
    'board.qualityExcellent': '優良',
    'trait.unknownEffect': '效果依內容版本規則',
    'trait.joint_reinforced.name': '加固接點',
    'trait.joint_reinforced.effect': '支撐力 +10%',
    'trait.joint_skewed.name': '接點歪斜',
    'trait.joint_skewed.effect': '工具耐久 −10%',
    'trait.clear.name': '清澈',
    'trait.clear.effect': '打漿品質 +3；煮沸後消失',
    'trait.mineral_rich.name': '礦物豐富',
    'trait.mineral_rich.effect': '湯品品質 +3',
    'trait.intact_fibre.name': '纖維完整',
    'trait.intact_fibre.effect': '下次布料／工具加工品質 +3',
    'trait.frayed.name': '纖維磨損',
    'trait.frayed.effect': '下次布料／工具加工品質 −3',
    'trait.cracked.name': '木料裂紋',
    'trait.cracked.effect': '製作耐久工具時耐久 −10%',
    'trait.damp.name': '潮濕',
    'trait.damp.effect': '木作／造紙品質 −3',
    'trait.smooth_metal.name': '金屬平整',
    'trait.smooth_metal.effect': '下次金屬工具加工品質 +3',
    'trait.rusted.name': '鏽蝕',
    'trait.rusted.effect': '下次金屬工具加工品質 −3',
    'trait.sealed.name': '封邊完整',
    'trait.sealed.effect': '防水物件加工品質 +3',
    'trait.brittle.name': '脆化',
    'trait.brittle.effect': '接頭／浮標加工品質 −3',
    'trait.even_pulp.name': '紙漿均勻',
    'trait.even_pulp.effect': '下次紙板／包材加工品質 +3',
    'trait.rich_ingredient.name': '鮮料完整',
    'trait.rich_ingredient.effect': '料理品質 +3',
    'trait.rough_cut.name': '切面粗糙',
    'trait.rough_cut.effect': '料理品質 −3',
    'trait.even_burn.name': '燃燒均勻',
    'trait.even_burn.effect': '下次控火成功區域寬度 +10%',
    'trait.smoky.name': '燃燒冒煙',
    'trait.smoky.effect': '下次熱加工成品品質 −3',
    'board.readOnlyTitle': '此存檔目前唯讀',
    'board.readOnlyBody': '另一個分頁持有寫入權；關閉後重新進入即可操作。',
    'board.keyboardHelp': '鍵盤操作棋盤',
    'board.keyboardSemantics': '物品棋盤。方向鍵移動格位，Enter 或空白鍵選取／放置，R 旋轉，Escape 取消選取。',
    'return.title': '接續你的進度',
    'return.savedAt': '本機存檔更新於 {time}；沒有每日登入獎勵或期限。',
    'return.chapter': '目前進度：第 {phase} 階段',
    'return.craftPending': '有一項加工尚未結算（已完成 {steps} / 3 步）',
    'return.expeditionReturned': '探索已返程：{count} 件結果待整理',
    'return.expeditionActive': '探索尚未結束：已走 {count} 個節點，可接續或返程',
    'return.fishingPending': '有一份釣魚結果尚未領取',
    'return.fishingActive': '有一場釣魚操作尚未完成',
    'return.reliefAvailable': '救助便當可領 {count} 份',
    'return.reliefMalformed': '救助資料需要檢查；其他本機進度仍保留',
    'return.stamina': '目前體力：{current} / {maximum}',
    'recipeIndex.title': '配方索引',
    'recipeIndex.invalidProgress': '章節進度存檔無效；所有配方暫時鎖定。',
    'recipeIndex.phaseProgress': '目前開放至階段 {phase}；鎖定配方仍可查看解鎖階段。',
    'recipeIndex.phaseFilter': '查看階段 {phase} 配方',
    'recipeIndex.allPhases': '查看全部階段的配方',
    'recipeIndex.allShort': '全部',
    'recipeIndex.page': '第 {current} / {total} 頁',
    'recipeIndex.previousPage': '上一頁配方',
    'recipeIndex.nextPage': '下一頁配方',
    'recipeIndex.invalidLock': '進度無效，暫時鎖定',
    'recipeIndex.questLock': '尚未解鎖；需先{quest}',
    'recipeIndex.stationLock': '完成回收分類任務後解鎖回收分類台',
    'recipes.questLocked': '尚未解鎖；需先{quest}',
    'recipeIndex.phaseLock': '階段 {required}・尚未解鎖（目前階段 {current}）',
    'common.close': '關閉',
    'common.dismiss': '知道了',
    'board.previousPage': '上一頁素材',
    'board.nextPage': '下一頁素材',
    'board.pageCount': '第 {current} / {total} 頁',
    'checkpoint.leftZone': '左側區',
    'checkpoint.promptZone': '提示區',
    'checkpoint.rightZone': '右側區',
    'collection.progress': '首次取得 {owned} / {total} 種物品',
    'collection.viewMaterialUses': '查看材料來源與用途',
    'collection.collected': '已取得',
    'collection.notCollected': '尚未取得',
    'recipes.progress': '{known} / {total} 項已解鎖',
    'recipes.title.withOutput': '{action}・{input} → {output}',
    'recipes.title.inputOnly': '{action}・{input}',
    'recipes.title.actionOnly': '{action}配方',
    'recipe.containerContentContext': '{recipe}（{content}）',
    'recipe.inputContainerContents': '{container}（內含{content}）',
    'recipes.action.cut': '切製',
    'recipes.action.sew': '縫製',
    'recipes.action.braid': '編織',
    'recipes.action.mix': '混合',
    'recipes.action.align': '對位',
    'recipes.action.strike': '敲製',
    'recipes.action.heat': '熱處理',
    'recipes.action.coat': '塗覆',
    'recipes.action.wash': '清理',
    'recipes.action.sort': '分類',
    'recipes.action.filter': '過濾',
    'recipes.action.cook': '烹調',
    'recipes.action.assemble': '組裝',
    'recipes.unlockedPhase': '已解鎖・階段 {phase}',
    'recipes.lockedPhase': '尚未解鎖・需要階段 {phase}',
    'recipes.stationLocked': '前置站點尚未解鎖',
    'recipe.questPrerequisite.filletFish': '取得本章的漁獲',
    'recipe.questPrerequisite.pressRod': '領取壓合教學材料',
    'recipe.questPrerequisite.nailBoard': '完成木條壓合並領取釘接教學材料',
    'recipe.questPrerequisite.woodenCrate': '完成撬具修理並領取木箱教學材料',
    'recipe.questPrerequisite.upgradeBag': '完成木箱放置與物品存取',
    'recipe.questPrerequisite.joinThread': '完成拆線步驟',
    'recipe.questPrerequisite.sewStrip': '拆線並將線頭接成線團',
    'materialUses.title': '材料用途索引',
    'materialUses.description': '完整拾得物與加工材料使用相同配方；來源只描述取得方式與品質差異。',
    'materialUses.producedBy': '取得／製作：{recipes}',
    'materialUses.usedBy': '加工用途：{recipes}',
    'recipe.phaseDuration': '階段 {phase}・{station}・{seconds} 秒',
    'recipe.station.recycler': '回收分類台',
    'recipe.station.tutorial': '教學操作',
    'recipe.station.workbench': '木料工作台',
    'recipe.station.kitchen': '料理區',
    'recipe.station.dock': '碼頭',
    'recipe.itemQuantity': '{item} × {count}',
    'recipe.inputSeparator': ' + ',
    'recipe.alternativeSeparator': ' 或 ',
    'recipe.itemSeparator': '、',
    'recipe.instructions': '操作：{instructions}',
    'recipe.detailInfo': '加工資訊',
    'recipe.requirements': '需求：{items}',
    'recipe.retainedTools': '保留工具：{tools}',
    'recipe.successWater': '成功結果：同一容器內水種由 {from} 轉為 {to}',
    'recipe.successMeal': '成功結果：依料理結果更新已選瓶身與餐盒內容；原容器保留',
    'recipe.successContainer': '成功結果：更新所選容器內容；保留原容器',
    'recipe.successWithContainers': '成功結果：產出 {outputs}；保留所選容器',
    'recipe.successPack': '成功結果：{inputs} 封裝進 {output}；拆解可取回原物件',
    'recipe.successOutputs': '成功產出：{outputs}',
    'recipe.qualityRule': '品質規則：{mode}；主材品質損耗 {loss}',
    'craft.qualityTraits.title': '本次材料的品質效果預覽',
    'craft.qualityTraits.empty': '目前材料沒有適用的正／負品質詞條修正；精準手動操作仍可提升成品品質。',
    'craft.qualityTraits.polarityNote': '正面與負面效果各最多採用一項；以上為依本次選料實際生效的詞條。',
    'recipe.failure': '失手結果：{outcome}',
    'recipe.selectAndCraft': '選料並加工',
    'craft.dialog.title': '製作 {recipe}',
    'craft.dialog.instruction': '操作：{instructions}。請逐件選取材料與保留工具。',
    'craft.dialog.materialPlan': '材料方案 {number}',
    'craft.dialog.selectMaterials': '選擇材料',
    'craft.dialog.materialsOnOtherGrid': '材料或工具在另一格盤',
    'craft.dialog.materialsNotOnBoard': '材料未放在目前格盤',
    'craft.dialog.organizeOtherGrid': '切換格盤整理',
    'craft.dialog.materialQuality': '{name}・{source}・品質 {quality}',
    'craft.dialog.selectedCount': '{name}：已選 {selected} / {required}',
    'craft.dialog.retainedTools': '保留工具（不消耗）',
    'craft.dialog.toolDurabilityUnknown': '耐久未設定',
    'craft.dialog.toolDurability': '耐久 {durability}',
    'craft.dialog.automaticLesson': '這是單步教學操作；確認後會依固定配方結算。',
    'craft.dialog.manualOperation': '確認後會先鎖定選取物件；三個操作檢查點逐步保存，可離開後續作。',
    'craft.dialog.spacePreview': '結果空間已預檢；失手依此配方的版本化規則結算。',
    'craft.dialog.cancel': '取消',
    'craft.dialog.confirmComplete': '確認並完成',
    'craft.dialog.quickCraft': '熟練快速製作',
    'craft.dialog.startManual': '開始手動加工',
    'craft.dialog.manualUnavailable': '此配方尚未具備可執行的手動流程',
    'craft.dialog.traitEffect': '{name}：{effect}',
    'craft.result.success': '加工完成，品質 {quality}。',
    'craft.result.missed': '操作失手，已依配方結算；品質 {quality}。',
    'water.title': '可重用水瓶',
    'water.rules': '裝水會消耗 2 點體力；倒水保留水質與污染史；清洗使用一瓶無須再煮沸的過濾水。',
    'water.rule.fill.short': '裝水 2',
    'water.rule.fill.detail': '裝水消耗 2 點體力',
    'water.rule.pour.short': '保留水質',
    'water.rule.pour.detail': '倒水會保留水質與污染史',
    'water.rule.wash.short': '濾水清洗',
    'water.rule.wash.detail': '清洗需使用無須再煮沸的過濾水',
    'water.noVessels': '背包／棋盤沒有可用水瓶。',
    'water.emptyBottle': '空瓶',
    'water.clean': '清潔',
    'water.unwashed': '未清潔',
    'water.vessel': '{id}：{content}（{cleanliness}）{quality}',
    'water.sourceTurbid': '濁水水岸',
    'water.sourceDirty': '髒水水岸（需煮沸）',
    'water.sourceMuddy': '泥水水岸',
    'water.sourceMineral': '新街區泉點（礦泉水・3體力・料理品質 +3）',
    'water.target': '倒入 {id}',
    'water.fillFiltered': '裝過濾水（公共補水點）',
    'water.fillSelected': '裝所選水源',
    'water.pour': '倒入另一個空瓶',
    'water.empty': '倒掉水',
    'water.wash': '用所選瓶中過濾水清洗另一瓶',
    'water.boil': '到配方頁控火煮沸（可存檔續作）',
    'water.confirmDiscardTitle': '倒掉容器內容？',
    'water.confirmDiscardBody': '只會倒掉所選容器裡的水；原容器與格位會保留。',
    'water.cancel': '取消',
    'water.confirmDiscard': '確認倒掉',
    'water.actionFailed': '水瓶操作未完成：{details}',
    'water.errorSourceLocked': '這個水源尚未解鎖。',
    'water.errorExpansionMissing': '請先安裝第5章擴充內容。',
    'water.errorStamina': '體力不足，未改變水瓶。',
    'water.errorCleanBottle': '請選擇清潔空瓶。',
    'water.errorSameBottle': '來源瓶與目標瓶必須不同。',
    'water.errorNoWater': '所選瓶中沒有可轉移的水。',
    'water.errorTargetNotEmpty': '目標瓶必須是清潔空瓶。',
    'water.errorFilteredRequired': '需要使用不必煮沸的過濾水。',
    'water.errorVesselMissing': '找不到所選水瓶；請重新選擇。',
    'water.errorUnknownSource': '無法識別所選水源。',
    'water.errorKitBackpackSpace': '濾水包需要背包空出 4 格。',
    'water.errorContentUnavailable':
        '濾水教學所需物品定義不在目前資源中。請到遊戲庫更新第 0–4 章資源後再試；本次沒有領取任何物品。',
    'water.errorOperationFailed': '水處理未完成，瓶中內容沒有變更。請重新選擇後再試。',
    'game.errorOperationFailed': '操作未完成，資料沒有變更。請整理後再試。',
    'craft.errorFinishPendingFirst': '先完成或取消目前的加工，再存取木箱。',
    'craft.errorPendingOperation': '目前有尚未完成的加工，請先繼續或取消。',
    'craft.errorSaving': '存檔仍在處理，請稍候再開始加工。',
    'craft.errorLaunchFailed': '配方視窗已關閉，但加工選料沒有開啟；請重新開啟配方再試一次。',
    'woodwork.actionFailed': '操作未完成：{details}',
    'woodwork.errorSaveUnconfirmed': '無法確認操作是否存入存檔。請重新載入並檢查材料與進度，再決定是否重試。',
    'woodwork.errorKitNoSpace': '棋盤與背包都沒有足夠空間。請先整理格位，再領取教學材料。',
    'woodwork.errorStoreBeforeWithdraw': '請先存入一件物品，再從木箱取出。',
    'woodwork.errorStoredItemMissing': '木箱物品清單已變動，資料未變更；請重新開啟遊戲後再試。',
    'woodwork.errorCrateNotPlaced': '請先放置木箱，再存取物品。',
    'woodwork.errorStorageItemInvalid': '這件物品目前不能存入木箱。',
    'woodwork.errorStorageFull': '木箱空間不足，沒有移動物品。',
    'woodwork.errorNoWithdrawalSpace': '背包和工作棋盤都放不下這件物品；請先整理空間。',
    'woodwork.openRecipes': '打開配方與手動加工',
    'woodwork.errorCrateUncrafted': '先依木箱配方完成加工。',
    'woodwork.errorCrateUnplaced': '請先把木箱移到棋盤或背包。',
    'woodwork.errorChapterFiveStructuresMissing': '請先製作雨棚與加固箱櫃，並移至棋盤或背包。',
    'woodwork.errorNoChapterFiveStorageItem': '棋盤或背包沒有可存入箱櫃的物品。',
    'woodwork.errorChapterFiveChestEmpty': '加固箱櫃目前是空的。',
    'woodwork.errorNoCrateStorageItem': '沒有可放入木箱的棋盤／背包物品。',
    'woodwork.storeOne': '存入一件物品',
    'woodwork.withdrawOne': '取出一件物品',
    'woodwork.workbenchTitle': '木料工作台',
    'woodwork.crateKitDescription': '木箱配方材料補給會扣除已持有材料，補足木板4、釘件束2、回收膠料1。',
    'woodwork.claimCrateMaterials': '領取木箱材料',
    'woodwork.claimingMaterials': '材料放入中…',
    'woodwork.crateReady': '材料已備妥；打開配方並手動完成木箱加工。',
    'woodwork.placeCrate': '放置木箱',
    'woodwork.placingCrate': '放置中…',
    'woodwork.crateStorage': '已放置木箱；箱內存放 {count} 件物品（最多12格）。',
    'repair.title': '工具日常修理',
    'repair.rules': '依已安裝內容包的材料組合修理；每次恢復指定耐久但不超過工具品質上限。工具與材料須在同一個棋盤或背包。',
    'repair.selectTool': '選擇要修理的工具',
    'repair.selectMethod': '維修方式',
    'repair.generalMethod': '一般維修（{uses}次）',
    'repair.preciseMethod': '精密保養（{uses}次）',
    'repair.selectMaterials': '選擇修理材料',
    'repair.toolOption': '{name}・耐久 {durability}',
    'repair.materialOption': '{name}・{quality}',
    'repair.action': '修理工具（+{uses} 耐久）',
    'repair.inProgress': '修理中…',
    'repair.item.distilledWaterContent': '蒸餾水（瓶中內容）',
    'repair.item.clothEdgeScrap': '布邊料',
    'repair.item.basicRod': '簡易釣竿',
    'repair.item.repairedRod': '修補釣竿',
    'repair.item.advancedRod': '改良釣竿',
    'repair.item.crowbar': '撬具',
    'repair.item.pliers': '分類鉗',
    'repair.item.awl': '修補錐',
    'repair.item.spareRig': '備用釣組',
    'repair.item.metalShard': '金屬碎片',
    'repair.item.binding': '綁帶',
    'repair.item.fishBone': '魚骨',
    'woodwork.repairKitDescription': '修理教學補給：剩餘1次耐久的撬具、金屬碎片1、綁帶1。',
    'woodwork.claimRepairKit': '領取修理材料',
    'woodwork.replenishRepairKit': '補回缺少的修理材料',
    'woodwork.repairCrowbar': '修理撬具（+10耐久）',
    'woodwork.repairingCrowbar': '修理中…',
    'woodwork.repairCompleteStatus': '撬具修理完成：原工具身份、品質與來源保留，消耗金屬碎片和綁帶，耐久恢復10次。',
    'woodwork.pressCompleteStatus': '壓合教學完成。木條可繼續釘接成木板，也可製作工具柄。',
    'woodwork.nailCompleteStatus': '木板釘接完成。精準作業可留下「釘固加強」，失手則保留可用木板並留下「釘固偏斜」。',
    'woodwork.pressInstructions':
        '把三片碎木順紋排齊，塗上回收膠料，再用夾具壓合成木條。失手仍會得到可用但品質較低的木條。',
    'woodwork.pressKitDescription': '材料優先放入背包；空間不足時整組放到工作台：碎木片 3、回收膠料 1。',
    'woodwork.claimPressKit': '領取壓合材料',
    'woodwork.nailKitDescription': '釘接教學補給會補足 3 根可操作木條與釘件束 1；已放在棋盤或背包的木條會先計入。',
    'woodwork.claimNailKit': '領取釘接材料',
    'woodwork.replenishNailKit': '補領缺少的釘接材料',
    'woodwork.crateAndBagComplete':
        '木箱已完成存取，修補背包也已升級為 {capacity} 格；升級保留原背包與既有物品。',
    'woodwork.crateCompleteBagOptional':
        '第一個木箱已放置，物品存取成功；箱內容量以格位計算，配方仍須先取回材料。背包目前 {capacity} 格；修補背包升級為可選。',
    'woodwork.waterLessonTitle': '水處理教學',
    'woodwork.waterLessonDescription': '濾水成功可取得過濾水；失手會保留濁水，但消耗木炭與濾布一次，可重新操作。',
    'woodwork.claimWaterKit': '領取濾水材料',
    'woodwork.waterKitReady': '濾水材料已放入背包；到配方頁選擇「濁水過濾」。',
    'woodwork.filteringComplete': 'q4.01 完成：你已取得過濾水，可以繼續料理教學。',
    'woodwork.lessonFiltered': '濾水',
    'woodwork.soupKitDescription': '基礎湯教學補給：清理食材、乾燥燃料、裝有開水的原瓶與空餐盒。',
    'woodwork.claimSoupKit': '領取基礎湯材料',
    'woodwork.soupKitReady': '材料已備妥；配方頁選擇「基礎湯」並手動控火。',
    'woodwork.soupComplete': 'q4.02 完成：餐點已裝入原餐盒，水瓶保留且已清空。',
    'woodwork.lessonCooked': '料理',
    'woodwork.selfServeDescription': '自主補給：食用前會顯示品質計算後的恢復量；體力已滿時不會消耗餐點。',
    'woodwork.consumeMeal': '查看並食用餐點',
    'woodwork.deliverMeal': '交付正常湯品訂單（+4 券）',
    'woodwork.processingMeal': '處理中…',
    'woodwork.mealChoiceComplete': 'q4.03 完成：已選擇食用或交付餐點；餐盒保留待清洗。',
    'woodwork.lessonMealUsed': '餐點已使用',
    'meal.eatDialogTitle': '食用餐點',
    'meal.eatDialogBody':
        '這份餐點可恢復 {recovery} 點體力，現在會恢復 {actual} 點。{overflowNotice}\n\n食用後會消耗餐點，原餐盒保留但需要清洗。',
    'meal.eatDialogOverflow': '將有 {overflow} 點超出上限。',
    'meal.cancelEating': '先不吃',
    'meal.confirmEating': '確認食用',
    'meal.deliverDialogTitle': '交付餐點訂單',
    'meal.deliverDialogBody': '交付一份正常湯品可得 4 張交換券。餐點會交出，原餐盒返還並需清洗；此章節訂單只能完成一次。',
    'meal.keepMeal': '先保留',
    'meal.confirmDelivery': '確認交付',
    'meal.errorMissingMeal': '背包中沒有裝著餐點的餐盒。',
    'meal.errorNotDeliverable': '沒有可交付的正常湯品；失敗餐不能交這張訂單。',
    'meal.errorOrderUnavailable': '訂單內容尚未載入，請重新開啟遊戲。',
    'meal.errorLessonLocked': '請先完成基礎湯教學，再食用或交付餐點。',
    'meal.errorAlreadyComplete': '本章餐點任務已完成，無法再次食用或交付。',
    'meal.errorFullStamina': '體力已滿，餐點不會被消耗。',
    'meal.errorInvalidStamina': '體力資料無效；餐點與存檔均未變更。',
    'meal.errorInventoryUnavailable': '目前無法讀取背包；餐點與存檔均未變更。',
    'meal.errorBoxUnavailable': '餐盒已不在背包中，請重新選擇。',
    'meal.errorUnknownMeal': '餐盒中沒有可辨識的餐點。',
    'meal.errorInvalidBalance': '交換券資料無效；餐點與存檔均未變更。',
    'meal.errorOrderSelection': '餐點或餐盒狀態已改變，請重新選擇。',
    'woodwork.chapter5Goal': 'q5.02 穩定生活目標',
    'woodwork.chapter5Orders': '普通循環委託：{completed}/5',
    'woodwork.chapter5StructuresPlaced': '可折雨棚與加固箱櫃已放置；雨棚支撐加成 +{support}%。',
    'woodwork.chapter5StructuresNeeded': '先完成雨棚與加固箱櫃配方，再一次放置到地盤家具位。',
    'woodwork.selectShelter': '選擇要放置的可折雨棚',
    'woodwork.selectChest': '選擇要放置的加固箱櫃',
    'woodwork.chapter5ShelterItem': '{id}・品質 {quality}・支撐 +{support}%',
    'woodwork.chapter5ChestItem': '{id}・品質 {quality}',
    'woodwork.placeStructures': '放置雨棚與加固箱櫃',
    'woodwork.placingStructures': '放置中…',
    'woodwork.chapter5Storage': '加固箱櫃已存 {count} 件物品；最多20格，製作前須先取出。',
    'woodwork.chapter5Complete': 'q5.02 完成：穩定住所與互助循環已建立。',
    'fishing.title': '碼頭釣魚',
    'fishing.equipFloat': '裝備簡易浮標',
    'fishing.unequipFloat': '收回浮標',
    'fishing.placeRaft': '放置浮架',
    'fishing.recallRaft': '收回浮架',
    'fishing.toBoard': '放入棋盤',
    'fishing.toBackpack': '放入背包',
    'fishing.spot.dockEntrance': '舊碼頭入口',
    'fishing.spot.unknown': '未知釣點',
    'fishing.intro': '使用免費天然餌與借用釣竿；投竿後魚訊會保存，稍後可接續操作。',
    'fishing.fishLanded': '漁獲已上岸',
    'fishing.missed': '這次脫鉤，帶回水岸材料',
    'fishing.claimWhole': '收下整魚（品質 {quality}）',
    'fishing.claimDriftwood': '收下漂木',
    'fishing.claimThread': '收下線頭',
    'fishing.inProgress': '釣魚進行中：{spot}',
    'fishing.progress': '已支付 {cost} 體力・{signals} / {total} 段魚訊',
    'fishing.guided': '跟著岸邊提示收線（引導模式）',
    'fishing.signalPrompt': '第 {number} 段魚訊：在亮起的提示區按住 2 秒，提前鬆開會視為失手。',
    'fishing.assistedSignalPrompt': '第 {number} 段魚訊：文字輔助已開啟，可點選完成訊號；仍可取得最高品質。',
    'fishing.signalPromptShort': '魚訊 {number}・按住亮區',
    'fishing.assistedTap': '點擊完成此段魚訊',
    'fishing.promptZone': '提示區 {percent}%',
    'fishing.promptZoneShort': '按住',
    'fishing.promptZoneSemantics': '提示區 {percent}%；按住 2 秒完成，提前鬆開會失手。',
    'fishing.stamina': '目前體力 {stamina}；投竿消耗 {cost}。',
    'fishing.saving': '保存中…',
    'fishing.castShort': '投竿',
    'fishing.castAt': '在{spot}投竿',
    'relief.clockSaveError': '救助時鐘未能保存。請重新進入遊戲確認狀態；本次操作未能確認完成。',
    'fishing.disposition': '漁獲去向：可保留整魚，或在工作棋盤的配方清單選擇「沿魚骨切分」。',
    'fishing.keepWhole': '保留整魚',
    'fishing.error.locked': '目前章節或釣點尚未開放釣魚。',
    'fishing.error.equipmentUnavailable': '沒有可用釣具；本次沒有開始釣魚。',
    'fishing.error.otherActivityPending': '請先完成或處理目前進行中的活動。',
    'fishing.error.claimPrevious': '請先領取上一筆釣魚結果。',
    'fishing.error.insufficientStamina': '體力不足，釣魚尚未開始。',
    'fishing.error.activityUnavailable': '釣魚進度無法續作；已保存進度未變更。',
    'fishing.error.resultUnavailable': '釣魚結果或背包資料無效，獎勵尚未領取。',
    'fishing.error.dispositionUnavailable': '目前無法變更這筆漁獲的處理方式。',
    'fishing.error.saveMalformed': '釣魚存檔資料格式無效；存檔未變更。',
    'fishing.error.concurrentWrite': '存檔已在其他位置更新；請重新載入後再試。',
    'fishing.error.operationFailed': '釣魚操作未能完成；請重新載入後再試。',
    'expedition.title': '街區翻找',
    'expedition.stamina': '體力 {current} / {maximum}',
    'expedition.readOnly': '此存檔目前唯讀，探索操作已停用。',
    'expedition.phaseZero': '階段 0 教學',
    'expedition.claimStarterVessels': '領取教學瓶 ×2',
    'expedition.step.search': '翻找',
    'expedition.step.keep': '收好',
    'expedition.step.deliver': '交付',
    'expedition.step.complete': '已完成',
    'expedition.step.next': '待完成',
    'expedition.startShort': '出發',
    'expedition.scene.description': '像素風台灣街角：舊屋、回收架、紙箱與玻璃瓶。',
    'expedition.task.firstItem': '調查並帶回第一份物品',
    'expedition.task.keepItem': '將物品收進背包並保留',
    'expedition.task.deliverMaterials': '交付紙屑 2 件或破布片 2 件',
    'expedition.deliverPaper': '交付紙屑 2 件',
    'expedition.deliverRags': '交付破布片 2 件',
    'expedition.materialsUnavailable': '背包尚無足量的紙屑或破布片；可在固定素材點取得。',
    'expedition.phaseOne': '階段 1｜分清回收物',
    'expedition.phaseTwo': '階段 2｜碼頭釣魚',
    'expedition.phaseThree': '階段 3｜木作與收納',
    'expedition.phaseFour': '階段 4｜水與餐點',
    'expedition.phaseFive': '階段 5｜穩定生活',
    'expedition.task.castLine': '使用釣竿完成一次投竿',
    'expedition.task.landFish': '完成一次釣魚並收下漁獲',
    'expedition.task.chooseFishUse': '選擇保留整魚或沿魚骨切分',
    'expedition.task.pressRod': '用碎木片與回收膠壓合木條',
    'expedition.task.nailBoard': '用木條與釘件釘接木板',
    'expedition.task.repairTool': '消耗修理材料，修復教學撬具',
    'expedition.task.storeCrate': '製作木箱、放置後存入並取回物品',
    'expedition.task.upgradeBagOptional': '（選做）擴充背包容量',
    'expedition.task.filterWater': '嘗試過濾濁水並取得可用水',
    'expedition.task.cookMeal': '手動完成基礎湯、素食湯或魚湯其中一道',
    'expedition.task.useOrDeliverMeal': '食用餐點恢復體力，或交付餐點委託',
    'expedition.task.advancedOrders': '完成五種生產器各一張進階委託',
    'expedition.task.stableLiving': '放置雨棚與加固箱櫃，並完成普通循環委託 5 次',
    'expedition.sortedCount': '正確分類 {sorted} / {total} 類；分類錯誤可重新選擇。',
    'expedition.claimSortingSamples': '領取回收分類教學樣本（紙／金屬／布／塑料各 1）',
    'expedition.currentCategory': '目前分類：{category}',
    'expedition.notClassified': '尚未分類',
    'expedition.classify': '分類／修正',
    'expedition.classifyItem': '{item} 分類',
    'expedition.sortingComplete': 'q1.01 完成：回收分類台教學已解鎖。',
    'expedition.tutorialSample': '教學樣本',
    'expedition.sewingTitle': 'q1.02｜拆線與縫補',
    'expedition.task.unpickThread': '從舊布拆出線頭',
    'expedition.task.joinThread': '將線頭接成可縫補的線團',
    'expedition.task.sewStrip': '用教學針具縫成布條',
    'expedition.sewingComplete': 'q1.02 完成：縫補布條可用於修補與工具製作。',
    'expedition.claimSewingKit': '領取縫補教學工具包（破布／補充線／針具）',
    'expedition.task.intactMaterial': '檢視完整材料並選擇保留或交付',
    'expedition.intactMaterialTitle': '完整材料',
    'expedition.intactFound': '完整拾得物',
    'expedition.fixedRackQuality': '來源：固定金屬回收架・品質 {quality}；用途與加工材料相同。',
    'expedition.keep': '保留',
    'expedition.deliver': '交付',
    'expedition.confirmKeep': '確認保留',
    'expedition.confirmDeliver': '確認交付',
    'expedition.return': '返回',
    'expedition.keepSourceQuality': '保留原物；來源與品質會持續記錄。',
    'expedition.deliverIntact': '交付後會消耗這件完整材料。',
    'expedition.intactLessonHint': '前往階段 1 探索第 3 節點的金屬回收架，取得木板或金屬片完整物。',
    'expedition.intactLessonComplete': 'q1.03 完成（{choice}）；材料用途索引已解鎖。',
    'expedition.kept': '已保留',
    'expedition.delivered': '已交付',
    'expedition.confirmTutorialDelivery': '確認交付',
    'expedition.deliveryConsumesItems': '交付後素材會被消耗',
    'expedition.cancel': '取消',
    'expedition.recyclingCategory.paper': '紙',
    'expedition.recyclingCategory.metal': '金屬',
    'expedition.recyclingCategory.cloth': '布',
    'expedition.recyclingCategory.plastic': '塑料',
    'expedition.error.recyclingClassificationLocked': '完成階段 0 委託後，才能開始回收分類教學。',
    'expedition.error.starterVesselsLocked': '教學瓶只供階段 0 領取。',
    'expedition.error.starterVesselsAlreadyClaimed': '教學瓶已經領取。',
    'expedition.error.recyclingSamplesAlreadyClaimed': '教學樣本已領取；可直接分類或修正分類。',
    'expedition.error.recyclingSampleUnavailable': '樣本目前不在背包，請先放回背包再分類。',
    'expedition.error.sewingTutorialKitLocked': '先完成 q1.01 回收分類，再領取縫補教學工具包。',
    'expedition.error.sewingTutorialKitAlreadyClaimed': '縫補教學工具包已領取。',
    'expedition.error.intactMaterialLessonLocked': '完成拆線與縫補任務後，才能選擇完整材料的去留。',
    'expedition.error.intactMaterialLessonComplete': '完整材料任務已完成，材料用途索引已解鎖。',
    'expedition.error.intactMaterialUnavailable': '完整材料已不在棋盤或背包；請從固定金屬回收架重新取得。',
    'expedition.error.noFittingSpace': '背包空間不足；整理後可領取教學用品，不會只領到一部分。',
    'expedition.organizeBackpack': '整理背包',
    'expedition.error.noCleanEmptyBottle': '沒有可用的清潔空瓶；請放棄礦泉水，或先準備空瓶再領取。',
    'expedition.error.insufficientStamina': '體力不足，可以免費返程。',
    'expedition.error.nodeAlreadyInvestigated': '這個節點已調查，請前往下一處或返程。',
    'expedition.error.claimPreviousRewardsFirst': '請先返程並領取上一趟物品，再開始新行程。',
    'expedition.error.operationFailed': '操作未完成，狀態沒有被部分扣除。請稍後再試。',
    'expedition.error.malformedSave': '探索資料無法讀取；原存檔未變更。請返回進度頁，使用存檔復原檢查可用備份。',
    'game.error.malformedSave':
        '遊戲存檔資料無法讀取；為避免覆寫進度，此頁暫停操作且存檔未修改。請返回進度頁使用存檔復原檢查備份。',
    'silhouette.title': '觀察現場提示',
    'silhouette.clue': '提示：{item}的目標輪廓位於{slot}。選錯仍會找到 1 件。',
    'silhouette.slot.left': '左側輪廓',
    'silhouette.slot.middle': '中間輪廓',
    'silhouette.slot.right': '右側輪廓',
    'silhouette.debrisLabel': '可拖曳的遮擋碎料',
    'silhouette.debrisHint': '長按後拖到任一輪廓上揭露；也可直接點擊輪廓。',
    'silhouette.instructions': '長按並拖動碎料揭露輪廓，或直接點擊。',
    'silhouette.cancel': '取消',
    'silhouette.select': '選{slot}',
    'silhouette.target.revealed': '{slot}，已揭露',
    'silhouette.target.covered': '{slot}，被碎料遮住',
    'silhouette.target.selectHint': '可以選擇此輪廓',
    'silhouette.target.revealHint': '點擊或拖入碎料來揭露',
    'silhouette.coveredObject': '遮擋物',
    'silhouette.status.revealed': '輪廓已露出',
    'silhouette.status.covered': '被遮住',
    'silhouette.debris.dragging': '碎料',
    'silhouette.debris.move': '移開碎料',
    'checkpoint.title': '加工步驟 {step} / 3',
    'checkpoint.assist.active': '操作輔助：文字點選',
    'checkpoint.assist.open': '改用鍵盤／螢幕閱讀器操作',
    'checkpoint.assist.short': '輔助操作',
    'checkpoint.assist.default': '操作輔助：文字點選',
    'checkpoint.result.success': '操作到位',
    'checkpoint.result.miss': '沒有對準提示區；本步記為失手',
    'checkpoint.result.shortSuccess': '到位',
    'checkpoint.result.shortMiss': '失手',
    'checkpoint.action.swipe': '按住並掃過發亮區域',
    'checkpoint.action.slider': '將刻度移到發亮區域',
    'checkpoint.action.tap': '點擊發亮目標區',
    'checkpoint.action.shortSwipe': '掃過亮區',
    'checkpoint.action.shortSlider': '調整刻度',
    'checkpoint.action.shortTap': '點擊亮點',
    'checkpoint.action.later': '稍後繼續',
    'checkpoint.action.save': '保存本步',
    'checkpoint.action.saveAndContinue': '保存並繼續',
    'checkpoint.slider.angle': '角度目標 0°；容許偏差 ±10°',
    'checkpoint.slider.tension': '五段張力刻度・目標區段 {step}',
    'checkpoint.slider.fire': '控火目標區段 {step}',
    'checkpoint.slider.fireExpanded': '控火目標區段 {step}（範圍擴大 10%）',
    'checkpoint.slider.generic': '五段滑桿・目標區段 {step}',
    'checkpoint.gesture.label': '加工目標區',
    'checkpoint.gesture.hint.swipe': '按住並掃過高亮的目標區域。',
    'checkpoint.gesture.hint.tap': '點擊高亮目標區域。',
    'checkpoint.assist.sew': '選第 {number} 孔',
    'checkpoint.assist.cut.start': '選起點',
    'checkpoint.assist.cut.bend': '選轉折',
    'checkpoint.assist.cut.end': '選終點',
    'checkpoint.assist.align.angle': '{degree}°',
    'checkpoint.assist.align.endpoint': '選端點',
    'checkpoint.assist.align.seam': '選接縫',
    'checkpoint.assist.align.anchor': '選定位',
    'checkpoint.assist.strike': '選落點 {number}',
    'checkpoint.assist.assemble.base': '選底件',
    'checkpoint.assist.assemble.joint': '選接點',
    'checkpoint.assist.assemble.fix': '選固定',
    'checkpoint.assist.wash': '完成污點 {number}',
    'checkpoint.assist.coat.left': '塗覆左區',
    'checkpoint.assist.coat.middle': '塗覆中區',
    'checkpoint.assist.coat.right': '塗覆右區',
    'checkpoint.assist.braid.tensionLow': '低張力',
    'checkpoint.assist.braid.tensionTarget': '提示張力',
    'checkpoint.assist.braid.tensionHigh': '高張力',
    'checkpoint.assist.braid.left': '交織左側',
    'checkpoint.assist.braid.middle': '交織中央',
    'checkpoint.assist.braid.right': '交織右側',
    'checkpoint.assist.target': '選目標區段 {number}',
    'checkpoint.canvas.zone.left': '左側',
    'checkpoint.canvas.zone.middle': '中央',
    'checkpoint.canvas.zone.right': '右側',
    'checkpoint.canvas.zone.coatLeft': '左區',
    'checkpoint.canvas.zone.coatMiddle': '中區',
    'checkpoint.canvas.zone.coatRight': '右區',
    'checkpoint.canvas.stain': '污點 {number}',
    'checkpoint.canvas.point.hole': '孔 {number}',
    'checkpoint.canvas.point.start': '起點',
    'checkpoint.canvas.point.bend': '轉折',
    'checkpoint.canvas.point.end': '終點',
    'checkpoint.canvas.point.endpoint': '端點',
    'checkpoint.canvas.point.seam': '接縫',
    'checkpoint.canvas.point.anchor': '定位',
    'checkpoint.canvas.point.strike': '落點 {number}',
    'checkpoint.canvas.point.base': '底件',
    'checkpoint.canvas.point.joint': '接點',
    'checkpoint.canvas.point.fix': '固定',
    'maintenance.title.threadRepair': '補線修整',
    'maintenance.title.drying': '乾燥處理',
    'maintenance.title.rustRemoval': '擦拭去鏽',
    'maintenance.title.heatReshape': '重新熱整',
    'maintenance.title.fuelRedrying': '重新乾燥燃料',
    'maintenance.title.boardAlignment': '重新定位木板',
    'maintenance.errorChapter': '第3章工作台解鎖後才能維護材料詞條。',
    'maintenance.errorAux': '{title}需要 {material} × 1，請先放入目前格盤。',
    'maintenance.errorAuxWater': '{title}需要 {material} × 1，以及裝有 {water} 的清潔容器。',
    'maintenance.prepare': '準備{title}材料',
    'maintenance.cost':
        '費用：{material} × 1{waterCost}。{vesselNote}物件身份、品質與位置不變。三步中至少兩步到位才移除「{trait}」。',
    'maintenance.quality': '{id}・品質 {quality}',
    'maintenance.vesselQuality': '{id}・內容品質 {quality}',
    'maintenance.vesselLabel': '{water}容器',
    'maintenance.later': '稍後處理',
    'maintenance.start': '開始{title}',
    'maintenance.complete': '{title}完成，原物件身份與品質保留。',
    'maintenance.missed': '{title}失手；輔料已使用，「{trait}」仍在。',
    'maintenance.waterCost': '＋{water} × 1',
    'maintenance.vesselNote': '原容器保留並清空；',
    'maintenance.errorMalformed': '材料維護操作存檔格式錯誤；材料仍保留。',
    'craft.error.unstructuredFailure': '此配方的失手結算尚未結構化；沒有扣除材料。',
    'craft.error.recipeVersionUnavailable': '加工使用的配方版本目前無法讀取；材料保持鎖定。',
    'craft.error.operationIncompatible': '加工步驟資料與已保存操作不相容；材料保持鎖定。',
    'craft.error.operationMalformed': '加工進度存檔損壞；沒有修改材料。',
    'craft.error.operationHasExtraSteps': '加工進度超出配方步驟；存檔未變更。',
    'craft.error.inputMismatch': '材料選取已變更或數量不符；沒有扣除材料。',
    'craft.error.toolsMismatch': '缺少可用工具；沒有扣除材料。',
    'craft.error.notMastered': '完成一次手動加工後才可使用快速製作。',
    'craft.error.phaseLocked': '此配方尚未解鎖；請先完成前置章節任務。',
    'craft.error.stationLocked': '先完成回收物分類任務，才能使用回收分類台配方。',
    'craft.error.chapterProgressInvalid': '章節進度存檔無效；為保護進度，暫時不能加工。',
    'craft.error.questLocked': '此配方尚未解鎖；需先{quest}。',
    'craft.error.waterLessonRequired': '先完成濾水教學，才能開始製作湯品；沒有扣除材料。',
    'craft.error.waterLessonRecipe': '這份濾水教學材料只能用於濁水過濾；材料沒有扣除。',
    'craft.error.sampleUnsorted': '教學樣本需先完成正確分類；分類錯誤可回到探索頁修正。',
    'craft.error.unpickFirst': '先完成拆線，再接合線頭。',
    'craft.error.prepareThreadFirst': '先拆線並把線頭接成線團，再開始縫補。',
    'craft.error.supplyReserved': '這份教學材料保留給指定步驟使用。',
    'craft.error.alreadyIrreversible': '操作已開始；不能免費取消，請續作完成結算。',
    'craft.error.incompatible': '這筆加工依據的內容版本目前不可用；材料仍保留且未扣除。',
    'craft.error.maintenanceLocked': '完成第3章前不能使用材料維護工作台。',
    'craft.error.profileUnknown': '此維護配方尚未啟用；材料沒有變更。',
    'craft.error.targetInvalid': '所選物件不含可移除的目標詞條。',
    'craft.error.auxiliaryRequired': '維護所需輔料不符；材料沒有扣除。',
    'craft.error.waterRequired': '缺少符合要求的水或清潔容器；材料沒有扣除。',
    'craft.error.inputUnavailable': '維護材料必須位於目前格盤且未被其他操作鎖定。',
    'craft.error.inputsChanged': '維護材料在結算前已改變；材料未扣除，請重新選取。',
    'craft.error.operationChanged': '維護操作狀態已變更或尚未完成；請重新載入操作。',
    'craft.error.rustTargetInvalid': '所選金屬已沒有鏽蝕，或不是可處理的金屬物件。',
    'craft.error.rustClothRequired': '去鏽需要布邊料 1。',
    'craft.error.rustWaterRequired': '去鏽需要清潔容器中的過濾水。',
    'craft.error.generic': '加工未提交，材料與存檔均未變更。請稍後再試。',
    'craft.error.concurrentWrite': '存檔已在其他位置更新；加工未提交，請重新載入後再試。',
    'craft.error.notSubmitted': '加工未提交，材料與存檔均未變更。',
    'craft.error.outputSpace': '格盤空間不足。先把物品移到另一格盤或收納箱，再試一次。',
    'expedition.start': '進入街區（消耗 1 體力）',
    'expedition.node': '路線節點 {current} / {total}',
    'expedition.position': '目前位置：{place}',
    'expedition.returned': '已返程；物品暫存在這趟探索中，領取時會一次檢查背包空間。',
    'expedition.mineralWaterReward': '品質 {quality}・需選擇清潔空瓶裝入；沒有空瓶可放棄',
    'expedition.rewardDetails': '品質 {quality}・{source}',
    'expedition.rewardSource.fixed.clothing_corner': '街角衣物堆',
    'expedition.rewardSource.fixed.paper_wood_pile': '紙木回收堆',
    'expedition.rewardSource.fixed.container_corner': '容器回收角',
    'expedition.rewardSource.fixed.metal_recycling_rack': '金屬回收架',
    'expedition.rewardSource.fixed.sorting_shed': '分類棚',
    'expedition.rewardSource.fixed.waterfront_materials': '水岸材料點',
    'expedition.rewardSource.fixed.repair_district': '修繕區',
    'expedition.rewardSource.fixed.market_exchange': '菜攤交換區',
    'expedition.rewardSource.fixed.old_street_exchange': '舊街固定交換點',
    'expedition.rewardSource.fixed.sorting_shed_chapter5': '新街分類棚',
    'expedition.rewardSource.fixedGeneric': '固定地點拾得',
    'expedition.rewardSource.surprise.commonScraps': '驚喜拾得・常見散料',
    'expedition.rewardSource.surprise.intactBase': '驚喜拾得・完整材料',
    'expedition.rewardSource.surprise.containers': '驚喜拾得・容器',
    'expedition.rewardSource.surprise.optionalSpecial': '驚喜拾得・特殊物品',
    'expedition.rewardSource.surpriseGeneric': '驚喜拾得',
    'expedition.rewardSource.other': '探索拾得物',
    'expedition.discardItem': '放棄這項物品',
    'expedition.claimAll': '領取全部物品到背包',
    'expedition.surveyFixed': '調查固定素材（2 體力）',
    'expedition.surveyFixedShort': '固定素材',
    'expedition.surveySurprise': '調查驚喜物件（2 體力）',
    'expedition.surveySurpriseShort': '驚喜物件',
    'expedition.alreadyInvestigated': '這個節點已調查；可前往下一處，或免費返程。',
    'expedition.nextNode': '前往下一節點（1 體力）',
    'expedition.nextNodeShort': '下一站',
    'expedition.returnFree': '免費返程',
    'expedition.returnShort': '返家',
    'expedition.chooseMaterial': '選擇要找的材料',
    'expedition.findQuantity': '找到時 {quantity} 件・品質依材料來源判定',
    'expedition.chooseBottle': '選擇空瓶裝入礦泉水',
    'expedition.mineralQuality': '礦泉水品質 {quality}；水會裝入瓶中，不會另占棋盤格。',
    'expedition.vesselQuality': '品質 {quality}・清潔空瓶',
    'expedition.vesselOption': '{item}・{source}・第 {number} 件',
    'expedition.cancelClaim': '取消領取',
    'expedition.confirmDiscard': '確認放棄物品',
    'expedition.keepReward': '保留',
    'expedition.confirmDiscardAction': '確認放棄',
    'expedition.discardPrompt':
        '放棄 {item} × {quantity}（品質 {quality}）？\n\n放棄後不能取回或重新調查。',
    'orders.title': '街坊委託',
    'orders.name.ss.order.recycle': '回收分類委託',
    'orders.name.ss.order.mending': '縫補委託',
    'orders.name.ss.order.fish': '漁獲委託',
    'orders.name.ss.order.board': '木板委託',
    'orders.name.ss.order.packaging': '包材委託',
    'orders.name.ss.order.meal': '餐點委託',
    'orders.name.ss.order.failed_meal_recycle': '失敗餐回收委託',
    'orders.name.ss.order.insulated': '保溫餐盒委託',
    'orders.name.ss.order.advanced_search': '舊街完整材料委託',
    'orders.name.ss.order.advanced_recycle': '回收加工委託',
    'orders.name.ss.order.advanced_fish': '魚貨加工委託',
    'orders.name.ss.order.advanced_workbench': '工具修補委託',
    'orders.name.ss.order.advanced_cooking': '共享餐委託',
    'orders.cycleSlots': '循環委託 ×2',
    'orders.cycleProgress': '已完成 {count} 次',
    'orders.neighborhoodProgress': '新街區互助委託 {done}/{total}',
    'orders.chapterSection': '主線／章節專屬委託',
    'orders.cycleSection': '普通循環委託',
    'orders.none': '目前還沒有開放的委託。',
    'orders.reward': '{count} 張券',
    'orders.phaseShort': '階段 {phase}',
    'orders.replace': '免費替換',
    'orders.replacing': '替換中…',
    'orders.accept': '接下委託',
    'orders.accepting': '接單中…',
    'orders.accepted': '已接單；只計算接單後完成的指定活動。',
    'orders.requiredSource': '指定來源：{source}；須在接單後取得並交付。',
    'orders.itemOption': '{name}・{quality}・第 {number} 件',
    'orders.materialAvailability': '持有 {available}／需求 {required}',
    'orders.containerOption': '{name}（內含 {contents}・{quality}）・第 {number} 件',
    'orders.requiredRecipes': '接單後須完成配方：{recipes}。',
    'orders.noMealContainers': '背包中沒有符合的餐點容器。',
    'orders.noPreparedMeal': '先將共享餐裝入可重用容器，再把容器放入背包。',
    'orders.selectedCount': '已選 {selected} 件；需求 {required} 件',
    'orders.tutorialCompleted': '已完成',
    'orders.deliver': '交付訂單',
    'orders.delivering': '交付中…',
    'orders.enterChapterFive': '前往新街區（第 5 章）',
    'orders.installChapterFive': '前往遊戲庫安裝第 5 章擴充包',
    'orders.confirmTitle': '交付「{order}」？',
    'orders.confirmConsume': '交出湯品與保溫餐盒；兩者都會消耗，獲得 {count} 張交換券。',
    'orders.confirmReturn':
        '交出 {containers} 個容器中的餐點，容器會保留並標記為待清洗；獲得 {reward} 張交換券。',
    'orders.confirmItems': '交付選取的 {count} 件物品；獲得 {reward} 張交換券。',
    'orders.cancelDelivery': '再整理一下',
    'orders.confirmDelivery': '確認交付',
    'orders.successDelivery': '委託完成，獲得 {count} 張交換券。',
    'orders.successReplacement': '已免費替換委託；沒有消耗物品或券。',
    'orders.error.operationFailed': '{operation}未完成；存檔與物品沒有部分變更。',
    'orders.operation.enterChapterFive': '進入新街區',
    'orders.operation.delivery': '委託交付',
    'orders.operation.acceptance': '接單',
    'orders.operation.replacement': '替換委託',
    'orders.error.chapter5PrerequisiteIncomplete': '先完成第 4 章餐點任務，再前往新街區。',
    'orders.error.chapter5ExpansionNotInstalled': '第 5 章擴充包尚未安裝，請先到遊戲庫下載。',
    'orders.error.orderUnavailable': '這張委託目前無法使用，請重新整理委託清單。',
    'orders.error.orderChapterMalformed': '章節進度資料無效；委託清單已停用。',
    'orders.error.cycleOrderSlotsMalformed': '循環委託欄位資料無效；委託清單已停用。',
    'orders.error.cycleOrderCursorMalformed': '循環委託替換進度無效；未替換委託。',
    'orders.error.cycleOrderNotActive': '這張委託已不在目前的循環清單中。',
    'orders.error.orderLocked': '尚未完成這張委託的解鎖條件。',
    'orders.error.orderNotAccepted': '請先接下委託，再完成指定活動。',
    'orders.error.orderAlreadyAccepted': '這張委託已接下。',
    'orders.error.orderAlreadyCompleted': '這張委託已完成。',
    'orders.error.orderTutorialLocked': '請先完成前置教學任務。',
    'orders.error.tutorialStateMalformed': '任務／教學存檔格式無效；委託交易未完成並已停用交付。',
    'orders.error.orderSourceEventRequired': '指定物品必須在接單後從指定地點取得。',
    'orders.error.orderRecipeEventRequired': '請先在接單後完成委託指定的加工配方。',
    'orders.error.orderSelectionInvalid': '選取的物品與委託需求不符；物品未變更。',
    'orders.error.orderContainerMissing': '符合需求的餐點容器已不存在，請重新選擇。',
    'orders.error.orderItemMissing': '選取的物品已不存在，請重新選擇。',
    'orders.error.orderItemNotAccepted': '這件物品不符合委託需求；物品未變更。',
    'orders.error.orderAcceptanceUnavailable': '目前無法接下這張委託。',
    'orders.error.orderAcceptanceStateMalformed': '接單紀錄格式無效；委託交易未完成。',
    'orders.error.recipeCompletionStateMalformed': '配方完成紀錄格式無效；委託交易未完成。',
    'orders.error.inventoryMissing': '目前無法讀取背包；委託交易未完成。',
    'orders.error.acceptedCycleOrderCannotBeReplaced': '已接下的循環委託不能替換。',
    'orders.error.cycleOrderNoReplacement': '目前沒有其他可替換的循環委託。',
    'orders.error.cycleOrderUnavailable': '這張循環委託目前無法替換。',
    'orders.error.invalidOrderBalance': '交換券資料無效；委託交易未完成。',
    'orders.error.invalidCompletedOrderCount': '已完成委託紀錄無效；委託交易未完成。',
    'orders.error.orderCompletionStateMalformed': '委託完成紀錄格式無效；委託交易未完成。',
    'orders.error.orderCompletionGroupInvalid': '委託任務進度格式無效；委託交易未完成。',
    'orders.error.cycleStateMalformed': '循環委託資料格式錯誤，已停用交付。',
    'orders.source.fixed:old_street_exchange': '舊街固定交換點',
    'orders.recipe.ss.recipe.unpick_cloth': '拆線取出線頭',
    'orders.recipe.ss.recipe.recycle_glue': '回收調製膠料',
    'relief.title': '政府救助',
    'relief.available':
        '可領 {visible} 份{reserve}；每滿24小時增加1份，不要求每天登入；每份恢復 {amount} 點體力。',
    'relief.reserve': '（另有 {count} 份保留額度）',
    'relief.ended': '穩定生活目標已完成，救助不再新增；既有 {count} 份保留。章節補給餘額：{balance} 點。',
    'relief.endedShort': '停止新增',
    'relief.stopWillHappen': '階段5穩定生活目標完成後將停止新增；完成前會再次確認並提供80點章節補給。',
    'relief.stopWillHappenShort': '第5章後停止 · +80補給',
    'relief.stopPrompt':
        '穩定生活目標已完成。確認停止後將不再新增救助；目前累積份額會保留，並另發一次80點章節補給。可稍後再確認。',
    'relief.stopPromptShort': '目標完成 · 便當保留 · +80補給',
    'relief.processing': '處理中…',
    'relief.finishAndClaim': '完成停止救助並領取補給',
    'relief.reviewOptions': '檢視停止救助與補給選項',
    'relief.rollback': '已記錄 {count} 次裝置時間回撥；不會重複發放救助。',
    'relief.claiming': '領取中…',
    'relief.claimReserved': '領用保留的救助便當',
    'relief.claim': '領用救助便當',
    'relief.claimSupply': '領取章節補給',
    'relief.claimSuccess': '領取救助便當：恢復 {restored} 點體力；剩餘 {count} 份。',
    'relief.claimFull': '體力已滿，救助份額不會被消耗。',
    'relief.noClaims': '目前沒有可領用的救助便當。',
    'relief.claimFailed': '救助領用失敗，份額沒有被消耗。請稍後再試。',
    'relief.supplySuccess': '領取章節補給，實際恢復 {restored} 點；尚餘 {remaining} 點。',
    'relief.supplyFailed': '章節補給領用失敗，進度沒有改變。請稍後再試。',
    'relief.stopTitle': '停止新增政府救助？',
    'relief.stopBody':
        '確認後政府救助將不再新增。已累積的救助便當會保留，之後仍可領用；另外發放一次80點章節補給，兩種補給分開領取。停止後無法恢復救助。',
    'relief.notNow': '暫不停止',
    'relief.confirmStop': '確認停止並領取補給',
    'relief.stopSuccess': '救助已停止新增；保留 {count} 份便當，並發放 {supply} 點章節補給。',
    'relief.stopFailed': '救助轉換未完成；可稍後續做。',
    'recovery.title': '恢復街角拾荒存檔',
    'recovery.damaged': '目前存檔無法驗證',
    'recovery.healthy': '沒有需要恢復的損壞存檔',
    'recovery.preserveNotice': '原存檔會保留不動。請檢視備份時間與進度，再選擇是否恢復；恢復會建立新的存檔版本。',
    'recovery.healthyStatus': '存檔狀態正常，未提供回退操作。',
    'recovery.none': '沒有可用的有效備份。請勿重置或覆蓋此存檔。',
    'recovery.revision': '備份 revision {revision}',
    'recovery.savedAt': '儲存時間：{time}',
    'recovery.ruleset': '規則版本：{version}{unsupported}',
    'recovery.unsupported': '（目前不支援）',
    'recovery.choose': '選擇恢復',
    'recovery.confirmTitle': '確認恢復備份？',
    'recovery.confirmBody': '將載入 revision {revision}（{time}）。損壞的存檔不會在確認前被覆寫。',
    'recovery.reviewAgain': '再檢查一下',
    'recovery.restore': '恢復這份備份',
  };

  static const Map<String, String> _en = {
    'game.title': 'Street Scrap',
    'entry.loginExpired':
        'Your login has expired. Sign in again to open this game.',
    'entry.saveLoadFailed':
        'The save could not be loaded. Your original data was not changed.',
    'entry.saveLoadAdvice':
        'Return to the Game Library and try again. Do not clear local data; if the issue persists, keep the save and ask for help.',
    'entry.contentLoadFailed':
        'Installed neighborhood content could not be read. Your local save was not changed.',
    'entry.contentLoadAdvice':
        'Return to the Game Library to check or download the content pack again. Your local save will not be changed.',
    'entry.rulesLoadFailed':
        'Exploration rules could not be loaded. Your local save was not changed.',
    'entry.backToLibrary': 'Back to Game Library',
    'entry.loaded': 'Local save loaded',
    'entry.noProgress': 'No game progress yet.',
    'entry.progressVersion':
        'Progress revision {revision}; last saved {savedAt}',
    'entry.readOnlyTitle': 'This save is open in another tab and is read-only.',
    'entry.readOnlyBody':
        'Close the other tab, then reopen this page to get write access.',
    'entry.contentNotInstalled':
        'Neighborhood content is not installed. Local progress is preserved; install content to start playing.',
    'entry.openLibrary': 'Open Game Library',
    'settings.title': 'Game Settings',
    'transfer.title': 'Save transfer',
    'transfer.description':
        'The save stays in a local file on this device. Versions and item placement are checked before import.',
    'transfer.export': 'Export save',
    'transfer.import': 'Import save',
    'transfer.exporting': 'Exporting…',
    'transfer.choosing': 'Choosing save…',
    'transfer.importing': 'Checking save…',
    'transfer.exportTitle': 'Export Street Scrap save',
    'transfer.importTitle': 'Choose a Street Scrap save',
    'transfer.exported': 'Save file exported.',
    'transfer.exportFailed': 'Could not export the save.',
    'transfer.reviewTitle': 'Review this save',
    'transfer.reviewBody':
        'Chapter {chapter} · save revision {revision}\nSaved: {savedAt}\nRuleset: {ruleset}\n\nYour current save will be kept before this progress is imported.',
    'transfer.cancel': 'Cancel',
    'transfer.confirmImport': 'Import save',
    'transfer.imported':
        'Save imported. Your previous progress is available from save recovery.',
    'transfer.importFailed':
        'The save could not be imported. Version or data errors leave your current progress unchanged.',
    'supplies.title': 'Fixed supply points',
    'supplies.repeatable':
        'Unlock by chapter and revisit when needed. Stamina is spent only after confirmation.',
    'supplies.repeatableShort': 'Repeatable',
    'supplies.availableTitle': 'Street supplies',
    'supplies.quantitySemantics': 'Quantity {quantity}',
    'supplies.staminaSemantics': 'Costs {stamina} stamina',
    'supplies.details': 'Collect {quantity} · costs {stamina} stamina',
    'supplies.claim': 'Collect',
    'supplies.working': 'Collecting…',
    'supplies.chooseVessel': 'Choose a clean, empty vessel for the water',
    'supplies.confirmTitle': 'Confirm supply collection',
    'supplies.confirmBody': 'Collect {item} ×{quantity} for {stamina} stamina.',
    'supplies.claimed': 'Collected {item} ×{quantity}',
    'supplies.publicWashTitle': 'Public tap · wash an empty bottle',
    'supplies.publicWashCost':
        'Use the fixed tap; no bottled water is spent. Costs 2 stamina.',
    'supplies.publicRefillTitle': 'Public tap · fill filtered water',
    'supplies.publicRefillCost':
        'Choose a clean, empty vessel. Costs 2 stamina.',
    'supplies.cleanEmptyVessel': 'Clean empty vessel',
    'supplies.noWaterVessels':
        'Bring back a reusable vessel from the street first.',
    'supplies.fillTitle': 'Fill this vessel with filtered water?',
    'supplies.fillBody':
        'Use the public refill point. Costs {stamina} stamina.',
    'supplies.fillAction': 'Fill · 2 stamina',
    'supplies.fillComplete': 'Filtered water added; the vessel can be reused.',
    'supplies.emptyVessel': 'Empty vessel · needs washing',
    'supplies.washTitle': 'Wash this empty vessel?',
    'supplies.washBody':
        'Use the public tap without spending bottled water. Costs {stamina} stamina.',
    'supplies.washAction': 'Wash · 2 stamina',
    'supplies.washComplete': 'The vessel is clean and ready to refill.',
    'supplies.error.alreadyClean': 'This vessel is already clean.',
    'supplies.error.notEmpty': 'Empty the vessel before using the public tap.',
    'supplies.error.stamina': 'Not enough stamina. Nothing was collected.',
    'supplies.error.backpackSpace':
        'The backpack cannot fit this supply. Move items to the workboard or a chest first.',
    'supplies.organize': 'Organize',
    'supplies.error.vessel':
        'Choose a clean, empty vessel that remains on the board or in the backpack.',
    'supplies.error.locked': 'This supply is not unlocked yet.',
    'supplies.error.generic':
        'Could not collect the supply. Your save is unchanged; make room and try again.',
    'settings.close': 'Close',
    'settings.extraTextScale': 'Game text size: {percent}%',
    'settings.reduceMotion': 'Reduce interface motion',
    'settings.reduceMotionDescription':
        'Keep action feedback while reducing transition animations.',
    'settings.assistedControls': 'Assisted controls: tap text targets',
    'settings.assistedControlsDescription':
        'Show tappable text targets during crafting without lowering the quality cap.',
    'settings.soundVolume': 'Sound and volume',
    'settings.soundMuted': 'Game sound is muted.',
    'settings.soundEnabled': 'Local game audio · {percent}%.',
    'settings.save': 'Save settings',
    'settings.saving': 'Saving…',
    'settings.saveFailed':
        'Settings could not be saved; progress was not changed. Please try again.',
    'settings.readOnly':
        'This save is read-only. Close the other tab and reopen this page to change settings.',
    'collection.title': 'Collection',
    'collection.count': 'First finds: {owned} / {total} items',
    'recipes.known': 'Known recipes',
    'recipes.unlockedCount': '{known} / {total} unlocked',
    'settings.scaleSummary': 'Text {percent}%',
    'settings.motionReduced': 'Reduced motion',
    'settings.motionNormal': 'Standard motion',
    'settings.controlsAssisted': 'Assisted text controls',
    'settings.controlsStandard': 'Standard controls',
    'board.title': 'Work Board',
    'board.saveRevision': 'Save revision {revision} · saved locally',
    'board.pendingMaintenance': 'Rust-removal work is waiting to be settled',
    'board.pendingCraft': 'Crafting is waiting to be settled',
    'board.pendingSteps':
        '{done} / 3 action steps saved; related materials and tools are locked.',
    'board.cancelPending': 'Cancel crafting before it starts',
    'board.resumeCraft': 'Resume crafting',
    'board.viewRecipes': 'View recipes ({count})',
    'board.materialIndex': 'Material uses index',
    'board.materialWorkspace': 'Materials workspace',
    'board.materialWorkspaceShort': 'Materials',
    'board.materialFocusMode': 'Focus materials',
    'board.materialGalleryBack': 'Back to board and backpack',
    'board.category.all': 'All materials',
    'board.category.wood': 'Wood',
    'board.category.cloth': 'Cloth',
    'board.category.metal': 'Metal',
    'board.category.water': 'Water',
    'board.category.food': 'Food',
    'board.category.tools': 'Tools',
    'board.category.other': 'Other',
    'board.moreMaterials': 'More materials',
    'board.previousMaterials': 'Previous materials',
    'board.nextMaterials': 'Next materials',
    'board.workingGridShort': 'Workbench',
    'board.backpackGridShort': 'Backpack',
    'board.workingGrid': 'Work Board 6×6',
    'board.backpackGrid': 'Backpack 4×4',
    'board.gridNameWorking': 'Work Board',
    'board.gridNameBackpack': 'Backpack',
    'board.moved': 'Item moved',
    'board.undoMove': 'Undo',
    'board.rotate': 'Rotate item',
    'board.clearSelection': 'Clear selection',
    'board.packCount': 'Pack into a bundle ({count} items)',
    'board.unpackBundle': 'Unpack bundle manually',
    'board.pendingItems': 'Items to sort',
    'board.pendingItemsEmpty':
        'No items need sorting right now. Items found in the neighborhood will appear here.',
    'board.homeStorage': 'Home storage',
    'board.storageItem': 'Stored item · move it to the active grid to retrieve',
    'board.instructionUnselected':
        'Select an item, switch grids, then tap an empty cell to place it.',
    'board.instructionSelected':
        'Item selected. Switch grids and choose a target cell. Invalid placements are rejected without consuming the item.',
    'board.error.craftLocked':
        'This item is reserved for an ongoing craft. Finish or cancel that operation first.',
    'board.error.noSpace':
        'There is no valid space for this item on the active grid. The item remains where it is.',
    'board.error.invalidPlacement':
        'This location cannot fit the item, or another tab updated the save. The item was not moved.',
    'board.error.saveFailed':
        'The local save failed; the item was not moved. Try again later.',
    'board.ownerLocation': '{grid} ({x}, {y})',
    'board.ownerStorage': 'Stored in {storage}',
    'board.ownerPending': 'Pending placement',
    'packing.title': 'Pack materials',
    'packing.contents': 'These {count} {input} will be packed into {output}:',
    'packing.itemDetails': '• {location} · {source} · {quality}',
    'packing.identity':
        'Each item remains inside the bundle and can be unpacked manually.',
    'packing.cancel': 'Cancel',
    'packing.confirm': 'Pack items',
    'mealPack.action': 'Pack into meal box',
    'mealPack.chooseContainer': 'Choose a meal box',
    'mealPack.containerOption': '{name} · item {number} · {quality}',
    'mealPack.confirmTitle': 'Confirm meal packing',
    'mealPack.confirmBody':
        'Pack {meal} ({quality}) into {container}. The meal moves into the reusable container.',
    'mealPack.confirmAction': 'Pack and keep container',
    'mealPack.error.locked':
        'Chapter 5 content is not unlocked for meal packing.',
    'mealPack.error.notCooked':
        'This meal was not produced by the shared-meal recipe.',
    'mealPack.error.backpack':
        'Move both the meal and container into the backpack first.',
    'mealPack.error.container':
        'That meal box is unavailable. Choose another one.',
    'mealPack.error.notEmpty':
        'That meal box is not empty. Choose an empty one.',
    'mealPack.error.needsCleaning': 'Clean the meal box before packing food.',
    'board.cellSemantics':
        '{grid}, row {row}, column {column}, {state}{cursor}',
    'board.cellEmpty': 'empty',
    'board.cellOccupied': 'occupied',
    'board.cellCursor': ', cursor here',
    'board.cellHint':
        'Double-tap to place the selected item, or drag an item to this cell.',
    'board.objectSemantics':
        '{grid}, starts at row {row}, column {column}: {name}, {source}, {quality}, occupies {width} by {height} cells',
    'board.objectHint':
        'Double-tap to select; use arrow keys to move, R to rotate, Enter to place, or drag to move.',
    'board.itemMetadata': '{source} · {quality}',
    'board.itemSemantics':
        '{name}, {source}, {quality}, occupies {width} by {height} cells{extra}',
    'board.itemSemanticsExtra': ', {subtitle}',
    'board.itemHint':
        'Double-tap to select; long-press and drag, or select and use board keyboard controls.',
    'board.itemSourceFound': 'Found (original material)',
    'board.itemSourceCrafted': 'Crafted',
    'board.spriteSemantics': '{item}, {source}',
    'board.spriteSemanticsWithContents': '{item}, {source}, contains {content}',
    'board.itemQuality': 'Quality: {tier} ({score})',
    'board.qualityPoor': 'Poor',
    'board.qualityOrdinary': 'Ordinary',
    'board.qualityGood': 'Good',
    'board.qualityExcellent': 'Excellent',
    'trait.unknownEffect': 'Effect is defined by the installed content version',
    'trait.joint_reinforced.name': 'Reinforced joint',
    'trait.joint_reinforced.effect': 'Support +10%',
    'trait.joint_skewed.name': 'Misaligned joint',
    'trait.joint_skewed.effect': 'Tool durability −10%',
    'trait.clear.name': 'Clear',
    'trait.clear.effect': 'Pulp quality +3; removed after boiling',
    'trait.mineral_rich.name': 'Mineral-rich',
    'trait.mineral_rich.effect': 'Soup quality +3',
    'trait.intact_fibre.name': 'Intact fibers',
    'trait.intact_fibre.effect': 'Next cloth/tool crafting quality +3',
    'trait.frayed.name': 'Frayed fibers',
    'trait.frayed.effect': 'Next cloth/tool crafting quality −3',
    'trait.cracked.name': 'Cracked wood',
    'trait.cracked.effect': 'Durability −10% when making durable tools',
    'trait.damp.name': 'Damp',
    'trait.damp.effect': 'Woodworking/papermaking quality −3',
    'trait.smooth_metal.name': 'Smooth metal',
    'trait.smooth_metal.effect': 'Next metal-tool crafting quality +3',
    'trait.rusted.name': 'Rusted',
    'trait.rusted.effect': 'Next metal-tool crafting quality −3',
    'trait.sealed.name': 'Sealed edges',
    'trait.sealed.effect': 'Waterproof-item crafting quality +3',
    'trait.brittle.name': 'Brittle',
    'trait.brittle.effect': 'Connector/float crafting quality −3',
    'trait.even_pulp.name': 'Even pulp',
    'trait.even_pulp.effect': 'Next paperboard/packaging crafting quality +3',
    'trait.rich_ingredient.name': 'Fresh ingredients',
    'trait.rich_ingredient.effect': 'Cooking quality +3',
    'trait.rough_cut.name': 'Rough-cut',
    'trait.rough_cut.effect': 'Cooking quality −3',
    'trait.even_burn.name': 'Even-burning',
    'trait.even_burn.effect': 'Next heat-control success zone width +10%',
    'trait.smoky.name': 'Smoky burn',
    'trait.smoky.effect': 'Next heated product quality −3',
    'board.readOnlyTitle': 'This save is read-only',
    'board.readOnlyBody':
        'Another tab owns write access. Close it, then reopen this game to continue.',
    'board.keyboardHelp': 'Keyboard controls for the board',
    'board.keyboardSemantics':
        'Item board. Use arrow keys to move the cursor, Enter or Space to select or place, R to rotate, and Escape to cancel selection.',
    'return.title': 'Continue where you left off',
    'return.savedAt':
        'Local save updated {time}. There are no daily login rewards or deadlines.',
    'return.chapter': 'Current progress: Phase {phase}',
    'return.craftPending':
        'A crafting operation is unfinished ({steps} of 3 steps complete)',
    'return.expeditionReturned':
        'Expedition returned: {count} reward(s) to sort',
    'return.expeditionActive':
        'Expedition in progress: {count} nodes visited; resume or return',
    'return.fishingPending': 'A fishing result is waiting to be claimed',
    'return.fishingActive': 'A fishing activity is unfinished',
    'return.reliefAvailable': '{count} relief meal(s) are available to claim',
    'return.reliefMalformed':
        'Relief data needs review; other local progress is preserved',
    'return.stamina': 'Current stamina: {current} / {maximum}',
    'recipeIndex.title': 'Recipe Index',
    'recipeIndex.invalidProgress':
        'Chapter progress is invalid; all recipes are temporarily locked.',
    'recipeIndex.phaseProgress':
        'Available through Phase {phase}. Locked recipes still show their unlock phase.',
    'recipeIndex.phaseFilter': 'Show Phase {phase} recipes',
    'recipeIndex.allPhases': 'Show recipes from every phase',
    'recipeIndex.allShort': 'All',
    'recipeIndex.page': 'Page {current} of {total}',
    'recipeIndex.previousPage': 'Previous recipes',
    'recipeIndex.nextPage': 'Next recipes',
    'recipeIndex.invalidLock': 'Progress is invalid; temporarily locked',
    'recipeIndex.questLock': 'Locked until {quest}',
    'recipeIndex.stationLock':
        'Complete the sorting tutorial to unlock the recycler station',
    'recipes.questLocked': 'Locked until {quest}',
    'recipeIndex.phaseLock':
        'Phase {required} · Locked (current phase: {current})',
    'common.close': 'Close',
    'common.dismiss': 'Dismiss',
    'board.previousPage': 'Previous materials',
    'board.nextPage': 'Next materials',
    'board.pageCount': 'Page {current} of {total}',
    'checkpoint.leftZone': 'Left zone',
    'checkpoint.promptZone': 'Cue zone',
    'checkpoint.rightZone': 'Right zone',
    'collection.progress': 'First finds: {owned} / {total} item types',
    'collection.viewMaterialUses': 'View material sources and uses',
    'collection.collected': 'Collected',
    'collection.notCollected': 'Not yet found',
    'recipes.progress': '{known} / {total} unlocked',
    'recipes.title.withOutput': '{action}: {input} → {output}',
    'recipes.title.inputOnly': '{action}: {input}',
    'recipes.title.actionOnly': '{action} recipe',
    'recipe.containerContentContext': '{recipe} ({content})',
    'recipe.inputContainerContents': '{container} containing {content}',
    'recipes.action.cut': 'Cut',
    'recipes.action.sew': 'Sew',
    'recipes.action.braid': 'Braid',
    'recipes.action.mix': 'Mix',
    'recipes.action.align': 'Align',
    'recipes.action.strike': 'Shape',
    'recipes.action.heat': 'Heat-treat',
    'recipes.action.coat': 'Coat',
    'recipes.action.wash': 'Clean',
    'recipes.action.sort': 'Sort',
    'recipes.action.filter': 'Filter',
    'recipes.action.cook': 'Cook',
    'recipes.action.assemble': 'Assemble',
    'recipes.unlockedPhase': 'Unlocked · Phase {phase}',
    'recipes.lockedPhase': 'Locked · requires Phase {phase}',
    'recipes.stationLocked': 'Prerequisite station is locked',
    'recipe.questPrerequisite.filletFish':
        'the catch for this phase is collected',
    'recipe.questPrerequisite.pressRod':
        'the wood-press tutorial materials are claimed',
    'recipe.questPrerequisite.nailBoard':
        'a wooden rod is pressed and the nailing tutorial materials are claimed',
    'recipe.questPrerequisite.woodenCrate':
        'the pry bar is repaired and the crate tutorial materials are claimed',
    'recipe.questPrerequisite.upgradeBag':
        'the crate is placed and an item is stored and retrieved',
    'recipe.questPrerequisite.joinThread': 'the cloth is unpicked',
    'recipe.questPrerequisite.sewStrip':
        'the cloth is unpicked and the thread is joined into a spool',
    'materialUses.title': 'Material Sources and Uses',
    'materialUses.description':
        'Found and crafted materials use the same recipes; source describes acquisition and quality differences only.',
    'materialUses.producedBy': 'Found / made by: {recipes}',
    'materialUses.usedBy': 'Used in: {recipes}',
    'recipe.phaseDuration': 'Phase {phase} · {station} · {seconds}s',
    'recipe.station.recycler': 'Recycling station',
    'recipe.station.tutorial': 'Tutorial station',
    'recipe.station.workbench': 'Woodworking bench',
    'recipe.station.kitchen': 'Cooking area',
    'recipe.station.dock': 'Dock',
    'recipe.itemQuantity': '{item} × {count}',
    'recipe.inputSeparator': ' + ',
    'recipe.alternativeSeparator': ' or ',
    'recipe.itemSeparator': ', ',
    'recipe.instructions': 'Steps: {instructions}',
    'recipe.detailInfo': 'Crafting details',
    'recipe.requirements': 'Requirements: {items}',
    'recipe.retainedTools': 'Tools returned: {tools}',
    'recipe.successWater':
        'On success: transforms water in the same container from {from} to {to}',
    'recipe.successMeal':
        'On success: updates the selected bottle and meal-box contents; containers are retained',
    'recipe.successContainer':
        'On success: updates the selected container contents and retains the original container',
    'recipe.successWithContainers':
        'On success: produces {outputs} and retains the selected container',
    'recipe.successPack':
        'On success: packs {inputs} into {output}; unpacking restores the original items',
    'recipe.successOutputs': 'On success: {outputs}',
    'recipe.qualityRule': 'Quality rule: {mode}; primary-material loss {loss}',
    'craft.qualityTraits.title': 'Material quality effects preview',
    'craft.qualityTraits.empty':
        'No positive or negative traits apply to these materials. Precise manual actions can still improve the result.',
    'craft.qualityTraits.polarityNote':
        'At most one positive and one negative effect apply. These traits are evaluated for the selected materials.',
    'recipe.failure': 'On a miss: {outcome}',
    'recipe.selectAndCraft': 'Select materials and craft',
    'craft.dialog.title': 'Craft {recipe}',
    'craft.dialog.instruction':
        'Action: {instructions}. Select each material and any reusable tools.',
    'craft.dialog.materialPlan': 'Material option {number}',
    'craft.dialog.selectMaterials': 'Select materials',
    'craft.dialog.materialsOnOtherGrid':
        'Materials or tools are on the other grid',
    'craft.dialog.materialsNotOnBoard': 'Materials are not on this grid',
    'craft.dialog.organizeOtherGrid': 'Switch grids to organize',
    'craft.dialog.materialQuality': '{name} · {source} · quality {quality}',
    'craft.dialog.selectedCount': '{name}: selected {selected} / {required}',
    'craft.dialog.retainedTools': 'Reusable tools (not consumed)',
    'craft.dialog.toolDurabilityUnknown': 'Durability not set',
    'craft.dialog.toolDurability': 'Durability {durability}',
    'craft.dialog.automaticLesson':
        'This is a one-step tutorial action. Confirm to resolve the fixed recipe.',
    'craft.dialog.manualOperation':
        'Selected objects are locked on confirmation. The three checkpoints are saved as you go, so you can leave and resume.',
    'craft.dialog.spacePreview':
        'Output space is checked first. A miss follows this recipe version’s outcome rules.',
    'craft.dialog.cancel': 'Cancel',
    'craft.dialog.confirmComplete': 'Confirm and complete',
    'craft.dialog.quickCraft': 'Quick craft (mastered)',
    'craft.dialog.startManual': 'Start manual crafting',
    'craft.dialog.manualUnavailable':
        'This recipe does not have an executable manual flow yet',
    'craft.dialog.traitEffect': '{name}: {effect}',
    'craft.result.success': 'Craft complete · quality {quality}.',
    'craft.result.missed':
        'Missed; resolved by the recipe · quality {quality}.',
    'water.title': 'Reusable Water Bottles',
    'water.rules':
        'Filling costs 2 stamina. Pouring preserves water quality and contamination history. Cleaning uses filtered water that does not need boiling.',
    'water.rule.fill.short': 'Fill · 2',
    'water.rule.fill.detail': 'Filling costs 2 stamina.',
    'water.rule.pour.short': 'Keep quality',
    'water.rule.pour.detail':
        'Pouring preserves water quality and contamination history.',
    'water.rule.wash.short': 'Wash · filtered',
    'water.rule.wash.detail':
        'Cleaning uses filtered water that does not need boiling.',
    'water.noVessels':
        'No usable water bottles are on the board or in your backpack.',
    'water.emptyBottle': 'Empty bottle',
    'water.clean': 'Clean',
    'water.unwashed': 'Unwashed',
    'water.vessel': '{id}: {content} ({cleanliness}){quality}',
    'water.sourceTurbid': 'Turbid-water shore',
    'water.sourceDirty': 'Dirty-water shore (must be boiled)',
    'water.sourceMuddy': 'Muddy-water shore',
    'water.sourceMineral':
        'New Neighborhood Spring (mineral water · costs 3 stamina · meal quality +3)',
    'water.target': 'Pour into {id}',
    'water.fillFiltered': 'Fill with filtered water (public refill point)',
    'water.fillSelected': 'Fill from selected source',
    'water.pour': 'Pour into another empty bottle',
    'water.empty': 'Discard water',
    'water.wash':
        'Wash another bottle with filtered water in the selected bottle',
    'water.boil': 'Open recipes to boil water (progress can be resumed)',
    'water.confirmDiscardTitle': 'Discard the bottle contents?',
    'water.confirmDiscardBody':
        'Only the selected container will be emptied; the container and its grid position will remain.',
    'water.cancel': 'Cancel',
    'water.confirmDiscard': 'Confirm discard',
    'water.actionFailed': 'Water-bottle action failed: {details}',
    'water.errorSourceLocked': 'This water source is still locked.',
    'water.errorExpansionMissing': 'Install the Chapter 5 expansion first.',
    'water.errorStamina': 'Not enough stamina. The bottle was not changed.',
    'water.errorCleanBottle': 'Choose a clean, empty bottle.',
    'water.errorSameBottle': 'Choose different source and target bottles.',
    'water.errorNoWater': 'The selected bottle has no water to transfer.',
    'water.errorTargetNotEmpty': 'The target must be a clean, empty bottle.',
    'water.errorFilteredRequired':
        'Use filtered water that does not require boiling.',
    'water.errorVesselMissing':
        'The selected bottle could not be found. Choose it again.',
    'water.errorUnknownSource': 'The selected water source is not recognized.',
    'water.errorKitBackpackSpace':
        'Free 4 backpack slots for the filtration kit.',
    'water.errorContentUnavailable':
        'The installed resources are missing an item needed for the filtration lesson. Update the Chapter 0–4 resource in Game Library and retry; no items were claimed.',
    'water.errorOperationFailed':
        'Water processing did not finish; bottle contents are unchanged. Reselect and try again.',
    'game.errorOperationFailed':
        'The action did not finish and no data changed. Make room and try again.',
    'craft.errorFinishPendingFirst':
        'Finish or cancel the pending craft before using the crate.',
    'craft.errorPendingOperation':
        'Finish or cancel the pending craft before starting another one.',
    'craft.errorSaving':
        'The save is still being written. Try crafting again in a moment.',
    'craft.errorLaunchFailed':
        'The recipe closed without opening material selection. Reopen it and try again.',
    'woodwork.actionFailed': 'Action did not complete: {details}',
    'woodwork.errorSaveUnconfirmed':
        'Could not confirm whether this action was saved. Reload and check your materials and progress before retrying.',
    'woodwork.errorKitNoSpace':
        'There is not enough room on the workboard or in the backpack. Make room, then claim the lesson supplies.',
    'woodwork.errorStoreBeforeWithdraw':
        'Store an item in the crate before withdrawing one.',
    'woodwork.errorStoredItemMissing':
        'The crate contents changed. No data changed; reopen the game and try again.',
    'woodwork.errorCrateNotPlaced':
        'Place the crate before storing or withdrawing items.',
    'woodwork.errorStorageItemInvalid':
        'This item cannot be stored in the crate.',
    'woodwork.errorStorageFull':
        'There is not enough room in the crate. No item was moved.',
    'woodwork.errorNoWithdrawalSpace':
        'There is no room for this item in the backpack or workboard. Make room and try again.',
    'woodwork.openRecipes': 'Open recipes and manual crafting',
    'woodwork.errorCrateUncrafted':
        'Craft the wooden crate from its recipe first.',
    'woodwork.errorCrateUnplaced':
        'Move the wooden crate onto the work board or backpack first.',
    'woodwork.errorChapterFiveStructuresMissing':
        'Craft the awning and reinforced chest, then move them onto the work board or backpack.',
    'woodwork.errorNoChapterFiveStorageItem':
        'There is no item on the work board or backpack to store in the chest.',
    'woodwork.errorChapterFiveChestEmpty': 'The reinforced chest is empty.',
    'woodwork.errorNoCrateStorageItem':
        'There is no work-board or backpack item that can be stored in the wooden crate.',
    'woodwork.storeOne': 'Store one item',
    'woodwork.withdrawOne': 'Withdraw one item',
    'woodwork.workbenchTitle': 'Woodworking Bench',
    'woodwork.crateKitDescription':
        'The crate recipe supply tops up 4 boards, 2 nail bundles, and 1 unit of recycled adhesive after subtracting materials you already own.',
    'woodwork.claimCrateMaterials': 'Claim crate materials',
    'woodwork.claimingMaterials': 'Adding materials…',
    'woodwork.crateReady':
        'Materials are ready. Open Recipes and craft the wooden crate manually.',
    'woodwork.placeCrate': 'Place wooden crate',
    'woodwork.placingCrate': 'Placing…',
    'woodwork.crateStorage':
        'Wooden crate placed; {count} items stored (12-cell capacity).',
    'repair.title': 'Tool Maintenance',
    'repair.rules':
        'Repairs use material combinations from installed content. Each repair restores a set amount without exceeding the tool quality cap. Keep the tool and materials on the same board or in the backpack.',
    'repair.selectTool': 'Choose a tool to repair',
    'repair.selectMethod': 'Repair method',
    'repair.generalMethod': 'Basic repair ({uses} uses)',
    'repair.preciseMethod': 'Precision maintenance ({uses} uses)',
    'repair.selectMaterials': 'Choose repair materials',
    'repair.toolOption': '{name} · durability {durability}',
    'repair.materialOption': '{name} · {quality}',
    'repair.action': 'Repair tool (+{uses} durability)',
    'repair.inProgress': 'Repairing…',
    'repair.item.distilledWaterContent': 'Distilled water (bottle contents)',
    'repair.item.clothEdgeScrap': 'Cloth edge scrap',
    'repair.item.basicRod': 'Basic fishing rod',
    'repair.item.repairedRod': 'Patched fishing rod',
    'repair.item.advancedRod': 'Improved fishing rod',
    'repair.item.crowbar': 'Crowbar',
    'repair.item.pliers': 'Sorting pliers',
    'repair.item.awl': 'Mending awl',
    'repair.item.spareRig': 'Spare fishing rig',
    'repair.item.metalShard': 'Metal shard',
    'repair.item.binding': 'Binding strip',
    'repair.item.fishBone': 'Fish bone',
    'woodwork.repairKitDescription':
        'Repair lesson supplies: a crowbar with 1 use remaining, 1 metal shard, and 1 binding strip.',
    'woodwork.claimRepairKit': 'Claim repair materials',
    'woodwork.replenishRepairKit': 'Restore missing repair materials',
    'woodwork.repairCrowbar': 'Repair crowbar (+10 durability)',
    'woodwork.repairingCrowbar': 'Repairing…',
    'woodwork.repairCompleteStatus':
        'Crowbar repaired: its identity, quality, and source are preserved. One metal shard and one binding strip were consumed; durability increased by 10.',
    'woodwork.pressCompleteStatus':
        'Pressing lesson complete. Rods can be nailed into boards or used to make tool handles.',
    'woodwork.nailCompleteStatus':
        'Board nailing complete. Precise work can add the Reinforced Nails trait; a miss still yields a usable board with a Bent Nails trait.',
    'woodwork.pressInstructions':
        'Align three wood chips with the grain, apply recycled adhesive, then clamp them into a rod. A miss still produces a usable rod at lower quality.',
    'woodwork.pressKitDescription':
        'Lesson supplies go into your backpack, or together on the workboard if it is full: 3 wood chips and 1 recycled adhesive.',
    'woodwork.claimPressKit': 'Claim pressing materials',
    'woodwork.nailKitDescription':
        'Nailing lesson supplies top up to 3 usable rods and 1 nail bundle; rods on your workboard or in your backpack count toward the total.',
    'woodwork.claimNailKit': 'Claim nailing materials',
    'woodwork.replenishNailKit': 'Replace missing nailing materials',
    'woodwork.crateAndBagComplete':
        'Wooden crate storage is working and the repaired backpack is upgraded to {capacity} cells. Your original bag and existing items were preserved.',
    'woodwork.crateCompleteBagOptional':
        'Your first crate is placed and item storage works. Capacity uses grid cells; retrieve ingredients before crafting. Backpack capacity is {capacity} cells; repairing the bag is optional.',
    'woodwork.waterLessonTitle': 'Water Treatment Lesson',
    'woodwork.waterLessonDescription':
        'Success yields filtered water. On a miss, the turbid water remains, but one charcoal and filter cloth are consumed; you can try again.',
    'woodwork.claimWaterKit': 'Claim filtration materials',
    'woodwork.waterKitReady':
        'Filtration materials are in your backpack. Open Recipes and choose “Filter Turbid Water.”',
    'woodwork.filteringComplete':
        'q4.01 complete: you obtained filtered water and can continue to the cooking lesson.',
    'woodwork.lessonFiltered': 'Filtered',
    'woodwork.soupKitDescription':
        'Basic soup lesson supplies: cleaned ingredients, dry fuel, the original bottle filled with boiled water, and an empty meal box.',
    'woodwork.claimSoupKit': 'Claim basic soup materials',
    'woodwork.soupKitReady':
        'Materials are ready. Open Recipes, choose “Basic Soup,” and control the heat manually.',
    'woodwork.soupComplete':
        'q4.02 complete: the meal is in the original meal box; the bottle is retained and empty.',
    'woodwork.lessonCooked': 'Cooked',
    'woodwork.selfServeDescription':
        'Self-supply: the quality-based stamina recovery is shown before eating. At full stamina, the meal is not consumed.',
    'woodwork.consumeMeal': 'Review and eat the meal',
    'woodwork.deliverMeal': 'Deliver a normal soup order (+4 vouchers)',
    'woodwork.processingMeal': 'Processing…',
    'woodwork.mealChoiceComplete':
        'q4.03 complete: you chose to eat or deliver the meal. The meal box is retained for washing.',
    'woodwork.lessonMealUsed': 'Meal used',
    'meal.eatDialogTitle': 'Eat the meal',
    'meal.eatDialogBody':
        'This meal can restore {recovery} stamina; you will recover {actual} now.{overflowNotice}\n\nEating consumes the meal. The original box is kept and must be washed.',
    'meal.eatDialogOverflow': ' {overflow} stamina will exceed the maximum.',
    'meal.cancelEating': 'Not now',
    'meal.confirmEating': 'Eat meal',
    'meal.deliverDialogTitle': 'Deliver meal order',
    'meal.deliverDialogBody':
        'Deliver one normal soup for 4 vouchers. The meal is handed over; the original box is returned and must be washed. This chapter order can only be completed once.',
    'meal.keepMeal': 'Keep meal',
    'meal.confirmDelivery': 'Confirm delivery',
    'meal.errorMissingMeal':
        'There is no meal box containing food in your backpack.',
    'meal.errorNotDeliverable':
        'There is no normal soup to deliver. Failed meals cannot fulfill this order.',
    'meal.errorOrderUnavailable':
        'Order data has not loaded. Reopen the game and try again.',
    'meal.errorLessonLocked':
        'Complete the basic soup lesson before eating or delivering a meal.',
    'meal.errorAlreadyComplete':
        'This chapter meal task is already complete; it cannot be repeated.',
    'meal.errorFullStamina': 'Stamina is full, so the meal was not consumed.',
    'meal.errorInvalidStamina':
        'Saved stamina is invalid. The meal and save were not changed.',
    'meal.errorInventoryUnavailable':
        'The backpack could not be read. The meal and save were not changed.',
    'meal.errorBoxUnavailable':
        'The meal box is no longer in the backpack. Select it again.',
    'meal.errorUnknownMeal': 'The box does not contain a recognized meal.',
    'meal.errorInvalidBalance':
        'Saved voucher balance is invalid. The meal and save were not changed.',
    'meal.errorOrderSelection':
        'The meal or box state changed. Select it again.',
    'woodwork.chapter5Goal': 'q5.02 Stable Living Goal',
    'woodwork.chapter5Orders': 'Ordinary cycle orders: {completed}/5',
    'woodwork.chapter5StructuresPlaced':
        'The folding awning and reinforced chest are placed; awning support bonus: +{support}%.',
    'woodwork.chapter5StructuresNeeded':
        'Craft the folding awning and reinforced chest, then place both in the homestead furniture slots.',
    'woodwork.selectShelter': 'Choose a folding awning to place',
    'woodwork.selectChest': 'Choose a reinforced chest to place',
    'woodwork.chapter5ShelterItem':
        '{id} · quality {quality} · support +{support}%',
    'woodwork.chapter5ChestItem': '{id} · quality {quality}',
    'woodwork.placeStructures': 'Place awning and reinforced chest',
    'woodwork.placingStructures': 'Placing…',
    'woodwork.chapter5Storage':
        'The reinforced chest stores {count} items; capacity is 20 cells. Withdraw items before crafting.',
    'woodwork.chapter5Complete':
        'q5.02 complete: a stable home and mutual-aid cycle are established.',
    'fishing.title': 'Dock Fishing',
    'fishing.equipFloat': 'Equip float',
    'fishing.unequipFloat': 'Remove float',
    'fishing.placeRaft': 'Place raft',
    'fishing.recallRaft': 'Recall raft',
    'fishing.toBoard': 'Move to board',
    'fishing.toBackpack': 'Move to backpack',
    'fishing.spot.dockEntrance': 'Old Dock Entrance',
    'fishing.spot.unknown': 'Unknown fishing spot',
    'fishing.intro':
        'Use free natural bait and a loaner rod. Fishing signals are saved after casting, so you can continue later.',
    'fishing.fishLanded': 'Catch landed',
    'fishing.missed': 'The fish got away; shoreline materials were recovered',
    'fishing.claimWhole': 'Keep whole fish (quality {quality})',
    'fishing.claimDriftwood': 'Collect driftwood',
    'fishing.claimThread': 'Collect thread ends',
    'fishing.inProgress': 'Fishing at {spot}',
    'fishing.progress': '{cost} stamina spent · {signals} / {total} signals',
    'fishing.guided': 'Follow the shore cue to reel in (guided mode)',
    'fishing.signalPrompt':
        'Signal {number}: hold the lit cue area for 2 seconds. Releasing early counts as a miss.',
    'fishing.assistedSignalPrompt':
        'Signal {number}: text assistance is on. Tap to complete the cue; maximum fish quality remains available.',
    'fishing.signalPromptShort': 'Signal {number} · hold the lit area',
    'fishing.assistedTap': 'Tap to complete this signal',
    'fishing.promptZone': 'Cue zone {percent}%',
    'fishing.promptZoneShort': 'Hold',
    'fishing.promptZoneSemantics':
        'Cue zone {percent}%. Hold for 2 seconds to complete; releasing early counts as a miss.',
    'fishing.stamina': 'Stamina: {stamina}; casting costs {cost}.',
    'fishing.saving': 'Saving…',
    'fishing.castShort': 'Cast',
    'fishing.castAt': 'Cast at {spot}',
    'relief.clockSaveError':
        'The relief timer could not be saved. Reopen the game to verify its state; this operation could not be confirmed.',
    'fishing.disposition':
        'Catch options: keep the whole fish, or choose “Cut Along the Backbone” in the Work Board recipe list.',
    'fishing.keepWhole': 'Keep whole fish',
    'fishing.error.locked': 'Fishing is not unlocked for this chapter or spot.',
    'fishing.error.equipmentUnavailable':
        'No fishing equipment is available. Fishing did not start.',
    'fishing.error.otherActivityPending':
        'Finish or resolve the current activity first.',
    'fishing.error.claimPrevious': 'Claim the previous fishing result first.',
    'fishing.error.insufficientStamina':
        'You do not have enough stamina. Fishing did not start.',
    'fishing.error.activityUnavailable':
        'The fishing attempt cannot continue; saved progress was not changed.',
    'fishing.error.resultUnavailable':
        'Fishing result or backpack data is invalid. No reward was claimed.',
    'fishing.error.dispositionUnavailable':
        'This catch cannot be changed to that disposition now.',
    'fishing.error.saveMalformed':
        'The fishing save data is invalid; the save was not changed.',
    'fishing.error.concurrentWrite':
        'The save changed elsewhere. Reload and try again.',
    'fishing.error.operationFailed':
        'The fishing action could not be completed. Reload and try again.',
    'expedition.title': 'Neighborhood Scavenging',
    'expedition.stamina': 'Stamina {current} / {maximum}',
    'expedition.readOnly': 'This save is read-only; exploration is disabled.',
    'expedition.phaseZero': 'Phase 0 tutorial',
    'expedition.claimStarterVessels': 'Claim tutorial bottles ×2',
    'expedition.step.search': 'Search',
    'expedition.step.keep': 'Keep',
    'expedition.step.deliver': 'Deliver',
    'expedition.step.complete': 'Complete',
    'expedition.step.next': 'Next',
    'expedition.startShort': 'Go',
    'expedition.scene.description':
        'Pixel-art Taiwanese street corner with a recycling crate, cardboard, and a glass bottle.',
    'expedition.task.firstItem': 'Search and bring back your first item',
    'expedition.task.keepItem': 'Put the item in your backpack and keep it',
    'expedition.task.deliverMaterials':
        'Turn in 2 paper scraps or 2 rag pieces',
    'expedition.deliverPaper': 'Turn in 2 paper scraps',
    'expedition.deliverRags': 'Turn in 2 rag pieces',
    'expedition.materialsUnavailable':
        'You do not have enough paper scraps or rag pieces in your backpack. Find them at fixed material spots.',
    'expedition.phaseOne': 'Phase 1 | Sort recyclables',
    'expedition.phaseTwo': 'Phase 2 | Dock fishing',
    'expedition.phaseThree': 'Phase 3 | Woodworking and storage',
    'expedition.phaseFour': 'Phase 4 | Water and meals',
    'expedition.phaseFive': 'Phase 5 | Stable living',
    'expedition.task.castLine': 'Cast a line with the fishing rod',
    'expedition.task.landFish': 'Finish a fishing attempt and claim the catch',
    'expedition.task.chooseFishUse':
        'Keep the whole fish or cut along its backbone',
    'expedition.task.pressRod': 'Press wood chips and recycled glue into a rod',
    'expedition.task.nailBoard': 'Join rods into a board with nails',
    'expedition.task.repairTool':
        'Spend repair materials to fix the tutorial crowbar',
    'expedition.task.storeCrate':
        'Craft and place a crate, then store and retrieve an item',
    'expedition.task.upgradeBagOptional': '(Optional) Expand backpack capacity',
    'expedition.task.filterWater': 'Filter turbid water to obtain usable water',
    'expedition.task.cookMeal':
        'Manually prepare a basic, vegetable, or fish soup',
    'expedition.task.useOrDeliverMeal':
        'Eat the meal for stamina or deliver a meal order',
    'expedition.task.advancedOrders':
        'Complete one advanced order for each of the five producers',
    'expedition.task.stableLiving':
        'Place the shelter and reinforced chest, then complete 5 regular cycle orders',
    'expedition.sortedCount':
        'Correctly sorted {sorted} / {total} categories. You can correct a mistake.',
    'expedition.claimSortingSamples':
        'Claim sorting samples (1 each: paper, metal, cloth, plastic)',
    'expedition.currentCategory': 'Current category: {category}',
    'expedition.notClassified': 'Not sorted',
    'expedition.classify': 'Sort / correct',
    'expedition.classifyItem': 'Sort {item}',
    'expedition.sortingComplete':
        'q1.01 complete: the recycling station tutorial is unlocked.',
    'expedition.tutorialSample': 'Tutorial sample',
    'expedition.sewingTitle': 'q1.02 | Unpick and sew',
    'expedition.task.unpickThread': 'Unpick thread from old cloth',
    'expedition.task.joinThread': 'Join loose threads into a usable spool',
    'expedition.task.sewStrip': 'Use the tutorial needle to sew a cloth strip',
    'expedition.sewingComplete':
        'q1.02 complete: sewn strips can repair items and make tools.',
    'expedition.claimSewingKit':
        'Claim sewing kit (rags, spare thread, and needle)',
    'expedition.task.intactMaterial':
        'Inspect an intact material and choose to keep or deliver it',
    'expedition.intactMaterialTitle': 'Intact material',
    'expedition.intactFound': 'Intact found item',
    'expedition.fixedRackQuality':
        'Source: fixed metal recycling rack · quality {quality}; it has the same uses as crafted material.',
    'expedition.keep': 'Keep',
    'expedition.deliver': 'Deliver',
    'expedition.confirmKeep': 'Confirm keep',
    'expedition.confirmDeliver': 'Confirm delivery',
    'expedition.return': 'Back',
    'expedition.keepSourceQuality':
        'Keep the original item; its source and quality remain recorded.',
    'expedition.deliverIntact': 'Delivering consumes this intact material.',
    'expedition.intactLessonHint':
        'At Phase 1, search the metal recycling rack at node 3 for an intact board or metal sheet.',
    'expedition.intactLessonComplete':
        'q1.03 complete ({choice}); the material-use index is unlocked.',
    'expedition.kept': 'kept',
    'expedition.delivered': 'delivered',
    'expedition.confirmTutorialDelivery': 'Confirm delivery',
    'expedition.deliveryConsumesItems': 'Materials are consumed after delivery',
    'expedition.cancel': 'Cancel',
    'expedition.recyclingCategory.paper': 'Paper',
    'expedition.recyclingCategory.metal': 'Metal',
    'expedition.recyclingCategory.cloth': 'Cloth',
    'expedition.recyclingCategory.plastic': 'Plastic',
    'expedition.error.recyclingClassificationLocked':
        'Complete the Phase 0 orders before starting the recycling tutorial.',
    'expedition.error.starterVesselsLocked':
        'Tutorial bottles are only available in phase 0.',
    'expedition.error.starterVesselsAlreadyClaimed':
        'The tutorial bottles were already claimed.',
    'expedition.error.recyclingSamplesAlreadyClaimed':
        'The tutorial samples were already claimed. You can sort or correct them now.',
    'expedition.error.recyclingSampleUnavailable':
        'This sample is not in your backpack. Move it back before sorting.',
    'expedition.error.sewingTutorialKitLocked':
        'Complete q1.01 sorting before claiming the sewing tutorial kit.',
    'expedition.error.sewingTutorialKitAlreadyClaimed':
        'The sewing tutorial kit was already claimed.',
    'expedition.error.intactMaterialLessonLocked':
        'Complete the unpicking and sewing tasks before choosing what to do with intact material.',
    'expedition.error.intactMaterialLessonComplete':
        'The intact-material task is complete and the material-use index is unlocked.',
    'expedition.error.intactMaterialUnavailable':
        'The intact material is no longer on the board or in your backpack. Find it again at the fixed metal rack.',
    'expedition.error.noFittingSpace':
        'Your backpack is full. Make room to claim the tutorial supplies; partial claims are not allowed.',
    'expedition.organizeBackpack': 'Open backpack',
    'expedition.error.noCleanEmptyBottle':
        'No clean empty bottle is available. Discard the mineral water or prepare an empty bottle before collecting it.',
    'expedition.error.insufficientStamina':
        'Not enough stamina. You can return for free.',
    'expedition.error.nodeAlreadyInvestigated':
        'This node has already been searched. Move on or return.',
    'expedition.error.claimPreviousRewardsFirst':
        'Return and collect the previous trip’s items before starting another trip.',
    'expedition.error.operationFailed':
        'The operation was not completed and no partial costs were applied. Please try again.',
    'expedition.error.malformedSave':
        'Exploration data could not be read. Your save is unchanged. Return to game progress and use Save Recovery to inspect available backups.',
    'game.error.malformedSave':
        'Game save data could not be read. This page is paused to avoid overwriting progress, and the save is unchanged. Return to game progress and use Save Recovery to inspect backups.',
    'silhouette.title': 'Read the on-site clue',
    'silhouette.clue':
        'Clue: the {item} target is under the {slot}. A wrong choice still finds 1 item.',
    'silhouette.slot.left': 'left silhouette',
    'silhouette.slot.middle': 'middle silhouette',
    'silhouette.slot.right': 'right silhouette',
    'silhouette.debrisLabel': 'Covering debris that can be dragged',
    'silhouette.debrisHint':
        'Long-press and drag the debris onto any silhouette to reveal it, or tap a silhouette directly.',
    'silhouette.instructions':
        'Long-press and drag debris to reveal a silhouette, or tap one directly.',
    'silhouette.cancel': 'Cancel',
    'silhouette.select': 'Select {slot}',
    'silhouette.target.revealed': '{slot}, revealed',
    'silhouette.target.covered': '{slot}, covered by debris',
    'silhouette.target.selectHint': 'This silhouette can be selected',
    'silhouette.target.revealHint': 'Tap or drag debris here to reveal it',
    'silhouette.coveredObject': 'Covering debris',
    'silhouette.status.revealed': 'Silhouette revealed',
    'silhouette.status.covered': 'Covered',
    'silhouette.debris.dragging': 'Debris',
    'silhouette.debris.move': 'Move debris',
    'checkpoint.title': 'Crafting step {step} / 3',
    'checkpoint.assist.active': 'Input assistance: tap text targets',
    'checkpoint.assist.open': 'Use keyboard / screen-reader controls',
    'checkpoint.assist.short': 'Input help',
    'checkpoint.assist.default': 'Input assistance: tap text targets',
    'checkpoint.result.success': 'On target',
    'checkpoint.result.miss': 'Missed the cue area; this step counts as a miss',
    'checkpoint.result.shortSuccess': 'On target',
    'checkpoint.result.shortMiss': 'Miss',
    'checkpoint.action.swipe': 'Press and sweep across the highlighted area',
    'checkpoint.action.slider': 'Move the marker into the highlighted area',
    'checkpoint.action.tap': 'Tap the highlighted target area',
    'checkpoint.action.shortSwipe': 'Sweep the cue',
    'checkpoint.action.shortSlider': 'Adjust marker',
    'checkpoint.action.shortTap': 'Tap target',
    'checkpoint.action.later': 'Continue later',
    'checkpoint.action.save': 'Save this step',
    'checkpoint.action.saveAndContinue': 'Save and continue',
    'checkpoint.slider.angle': 'Angle target 0°; tolerance ±10°',
    'checkpoint.slider.tension': 'Five tension levels · target segment {step}',
    'checkpoint.slider.fire': 'Heat-control target segment {step}',
    'checkpoint.slider.fireExpanded':
        'Heat-control target segment {step} (zone widened by 10%)',
    'checkpoint.slider.generic': 'Five slider levels · target segment {step}',
    'checkpoint.gesture.label': 'Crafting target area',
    'checkpoint.gesture.hint.swipe':
        'Press and sweep across the highlighted target area.',
    'checkpoint.gesture.hint.tap': 'Tap the highlighted target area.',
    'checkpoint.assist.sew': 'Choose hole {number}',
    'checkpoint.assist.cut.start': 'Choose start point',
    'checkpoint.assist.cut.bend': 'Choose bend',
    'checkpoint.assist.cut.end': 'Choose end point',
    'checkpoint.assist.align.angle': '{degree}°',
    'checkpoint.assist.align.endpoint': 'Choose endpoint',
    'checkpoint.assist.align.seam': 'Choose seam',
    'checkpoint.assist.align.anchor': 'Choose anchor',
    'checkpoint.assist.strike': 'Choose strike point {number}',
    'checkpoint.assist.assemble.base': 'Choose base piece',
    'checkpoint.assist.assemble.joint': 'Choose joint',
    'checkpoint.assist.assemble.fix': 'Choose fastener point',
    'checkpoint.assist.wash': 'Clean stain {number}',
    'checkpoint.assist.coat.left': 'Coat left area',
    'checkpoint.assist.coat.middle': 'Coat middle area',
    'checkpoint.assist.coat.right': 'Coat right area',
    'checkpoint.assist.braid.tensionLow': 'Low tension',
    'checkpoint.assist.braid.tensionTarget': 'Target tension',
    'checkpoint.assist.braid.tensionHigh': 'High tension',
    'checkpoint.assist.braid.left': 'Weave left side',
    'checkpoint.assist.braid.middle': 'Weave center',
    'checkpoint.assist.braid.right': 'Weave right side',
    'checkpoint.assist.target': 'Choose target segment {number}',
    'checkpoint.canvas.zone.left': 'Left',
    'checkpoint.canvas.zone.middle': 'Center',
    'checkpoint.canvas.zone.right': 'Right',
    'checkpoint.canvas.zone.coatLeft': 'Left area',
    'checkpoint.canvas.zone.coatMiddle': 'Middle area',
    'checkpoint.canvas.zone.coatRight': 'Right area',
    'checkpoint.canvas.stain': 'Stain {number}',
    'checkpoint.canvas.point.hole': 'Hole {number}',
    'checkpoint.canvas.point.start': 'Start',
    'checkpoint.canvas.point.bend': 'Bend',
    'checkpoint.canvas.point.end': 'End',
    'checkpoint.canvas.point.endpoint': 'Endpoint',
    'checkpoint.canvas.point.seam': 'Seam',
    'checkpoint.canvas.point.anchor': 'Anchor',
    'checkpoint.canvas.point.strike': 'Strike {number}',
    'checkpoint.canvas.point.base': 'Base',
    'checkpoint.canvas.point.joint': 'Joint',
    'checkpoint.canvas.point.fix': 'Fastener',
    'maintenance.title.threadRepair': 'Thread repair',
    'maintenance.title.drying': 'Drying treatment',
    'maintenance.title.rustRemoval': 'Rust removal',
    'maintenance.title.heatReshape': 'Heat reshaping',
    'maintenance.title.fuelRedrying': 'Fuel redrying',
    'maintenance.title.boardAlignment': 'Board realignment',
    'maintenance.errorChapter':
        'Material maintenance unlocks at the Chapter 3 workbench.',
    'maintenance.errorAux':
        '{title} requires 1 {material}. Place it on the active grid first.',
    'maintenance.errorAuxWater':
        '{title} requires 1 {material} and a clean vessel containing {water}.',
    'maintenance.prepare': 'Prepare materials for {title}',
    'maintenance.cost':
        'Cost: 1 {material}{waterCost}. The object identity, quality, and position stay unchanged. At least two of three steps must be on target to remove “{trait}”.',
    'maintenance.quality': '{id} · quality {quality}',
    'maintenance.vesselQuality': '{id} · contents quality {quality}',
    'maintenance.vesselLabel': '{water} vessel',
    'maintenance.later': 'Do this later',
    'maintenance.start': 'Start {title}',
    'maintenance.complete':
        '{title} complete. The original object identity and quality are preserved.',
    'maintenance.missed':
        '{title} missed; the auxiliary material was used and “{trait}” remains.',
    'maintenance.waterCost': ' + 1 {water}',
    'maintenance.vesselNote': 'The original vessel is kept and emptied; ',
    'maintenance.errorMalformed':
        'The saved material-maintenance operation is malformed; materials remain untouched.',
    'craft.error.unstructuredFailure':
        'This recipe has no structured miss outcome yet. No materials were consumed.',
    'craft.error.recipeVersionUnavailable':
        'The recipe version used by this operation is unavailable. Materials remain locked.',
    'craft.error.operationIncompatible':
        'The saved operation is incompatible with the recipe steps. Materials remain locked.',
    'craft.error.operationMalformed':
        'The saved crafting progress is malformed. No materials were changed.',
    'craft.error.operationHasExtraSteps':
        'Crafting progress exceeds the recipe steps. The save was not changed.',
    'craft.error.inputMismatch':
        'The selected materials changed or have the wrong quantity. No materials were consumed.',
    'craft.error.toolsMismatch':
        'A required tool is unavailable. No materials were consumed.',
    'craft.error.notMastered':
        'Complete one manual craft before using quick craft.',
    'craft.error.phaseLocked':
        'This recipe is locked. Complete its prerequisite chapter task first.',
    'craft.error.stationLocked':
        'Complete the recycling-sort task before using recycling-station recipes.',
    'craft.error.chapterProgressInvalid':
        'Chapter progress data is invalid. Crafting is paused to protect your progress.',
    'craft.error.questLocked': 'This recipe unlocks after {quest}.',
    'craft.error.waterLessonRequired':
        'Complete the water-filtering lesson before cooking soup. No materials were consumed.',
    'craft.error.waterLessonRecipe':
        'These lesson supplies are for filtering turbid water. No materials were consumed.',
    'craft.error.sampleUnsorted':
        'Sort the tutorial sample correctly first. You can correct a mistake on the exploration page.',
    'craft.error.unpickFirst':
        'Unpick the cloth before joining the thread ends.',
    'craft.error.prepareThreadFirst':
        'Unpick the cloth and join the thread into a spool before sewing.',
    'craft.error.supplyReserved':
        'These tutorial materials are reserved for their assigned steps.',
    'craft.error.alreadyIrreversible':
        'This operation has started and cannot be cancelled for free. Resume it to settle the result.',
    'craft.error.incompatible':
        'The content version used by this craft is unavailable. Materials remain untouched.',
    'craft.error.maintenanceLocked':
        'Material maintenance unlocks after completing Chapter 3.',
    'craft.error.profileUnknown':
        'This maintenance recipe is not enabled. Nothing was changed.',
    'craft.error.targetInvalid':
        'The selected object does not have the trait that can be removed.',
    'craft.error.auxiliaryRequired':
        'The required maintenance auxiliary does not match. No materials were consumed.',
    'craft.error.waterRequired':
        'A suitable water source or clean vessel is missing. No materials were consumed.',
    'craft.error.inputUnavailable':
        'Maintenance materials must be on the active grid and unlocked by other operations.',
    'craft.error.inputsChanged':
        'Maintenance inputs changed before settlement. Nothing was consumed; select them again.',
    'craft.error.operationChanged':
        'The maintenance operation changed or is incomplete. Reload the operation and continue.',
    'craft.error.rustTargetInvalid':
        'The selected metal is not rusty or cannot be treated.',
    'craft.error.rustClothRequired': 'Rust removal requires 1 cloth scrap.',
    'craft.error.rustWaterRequired':
        'Rust removal requires filtered water in a clean vessel.',
    'craft.error.generic':
        'Craft was not submitted. Materials and save data are unchanged. Please try again.',
    'craft.error.concurrentWrite':
        'The save changed elsewhere. Craft was not submitted; reload and try again.',
    'craft.error.notSubmitted':
        'Craft was not submitted. Materials and save data are unchanged.',
    'craft.error.outputSpace':
        'There is not enough room for the result. Move an item to another grid or storage, then retry.',
    'expedition.start': 'Enter the neighborhood (costs 1 stamina)',
    'expedition.node': 'Route node {current} / {total}',
    'expedition.position': 'Current location: {place}',
    'expedition.returned':
        'You are back. Items are stored in this trip; backpack space is checked when you collect them.',
    'expedition.mineralWaterReward':
        'Quality {quality} · choose a clean empty bottle; discard if you have none',
    'expedition.rewardDetails': 'Quality {quality} · {source}',
    'expedition.rewardSource.fixed.clothing_corner':
        'Street-corner clothing pile',
    'expedition.rewardSource.fixed.paper_wood_pile': 'Paper and lumber pile',
    'expedition.rewardSource.fixed.container_corner':
        'Container salvage corner',
    'expedition.rewardSource.fixed.metal_recycling_rack':
        'Metal recycling rack',
    'expedition.rewardSource.fixed.sorting_shed': 'Sorting shed',
    'expedition.rewardSource.fixed.waterfront_materials':
        'Waterfront materials point',
    'expedition.rewardSource.fixed.repair_district': 'Repair district',
    'expedition.rewardSource.fixed.market_exchange': 'Market exchange',
    'expedition.rewardSource.fixed.old_street_exchange':
        'Old Street fixed exchange point',
    'expedition.rewardSource.fixed.sorting_shed_chapter5':
        'New-district sorting shed',
    'expedition.rewardSource.fixedGeneric': 'Fixed-site find',
    'expedition.rewardSource.surprise.commonScraps':
        'Surprise find · common scraps',
    'expedition.rewardSource.surprise.intactBase':
        'Surprise find · intact materials',
    'expedition.rewardSource.surprise.containers': 'Surprise find · container',
    'expedition.rewardSource.surprise.optionalSpecial':
        'Surprise find · special item',
    'expedition.rewardSource.surpriseGeneric': 'Surprise find',
    'expedition.rewardSource.other': 'Scavenged item',
    'expedition.discardItem': 'Discard this item',
    'expedition.claimAll': 'Collect all items into backpack',
    'expedition.surveyFixed': 'Search fixed materials (2 stamina)',
    'expedition.surveyFixedShort': 'Fixed finds',
    'expedition.surveySurprise': 'Search for a surprise item (2 stamina)',
    'expedition.surveySurpriseShort': 'Surprise find',
    'expedition.alreadyInvestigated':
        'This node has been searched. Move to the next one or return for free.',
    'expedition.nextNode': 'Go to next node (1 stamina)',
    'expedition.nextNodeShort': 'Next stop',
    'expedition.returnFree': 'Return for free',
    'expedition.returnShort': 'Return',
    'expedition.chooseMaterial': 'Choose a material to search for',
    'expedition.findQuantity':
        'Find {quantity} item(s) · quality depends on the source',
    'expedition.chooseBottle': 'Choose an empty bottle for mineral water',
    'expedition.mineralQuality':
        'Mineral water quality {quality}; it fills the bottle and does not take another board cell.',
    'expedition.vesselQuality': 'Quality {quality} · clean empty bottle',
    'expedition.vesselOption': '{item} · {source} · item {number}',
    'expedition.cancelClaim': 'Cancel collection',
    'expedition.confirmDiscard': 'Confirm item discard',
    'expedition.keepReward': 'Keep',
    'expedition.confirmDiscardAction': 'Discard item',
    'expedition.discardPrompt':
        'Discard {item} × {quantity} (quality {quality})?\n\nDiscarded items cannot be recovered or searched again.',
    'orders.title': 'Neighborhood Orders',
    'orders.name.ss.order.recycle': 'Recycling Sort Order',
    'orders.name.ss.order.mending': 'Mending Order',
    'orders.name.ss.order.fish': 'Fish Catch Order',
    'orders.name.ss.order.board': 'Wooden Board Order',
    'orders.name.ss.order.packaging': 'Packaging Order',
    'orders.name.ss.order.meal': 'Meal Order',
    'orders.name.ss.order.failed_meal_recycle': 'Failed Meal Recovery Order',
    'orders.name.ss.order.insulated': 'Insulated Meal Box Order',
    'orders.name.ss.order.advanced_search': 'Old-Street Intact Material Order',
    'orders.name.ss.order.advanced_recycle': 'Recycling Workshop Order',
    'orders.name.ss.order.advanced_fish': 'Fish Processing Order',
    'orders.name.ss.order.advanced_workbench': 'Tool Repair Order',
    'orders.name.ss.order.advanced_cooking': 'Shared Meal Order',
    'orders.cycleSlots': 'Cycle orders ×2',
    'orders.cycleProgress': '{count} completed',
    'orders.neighborhoodProgress':
        'New neighborhood support orders {done}/{total}',
    'orders.chapterSection': 'Story / Chapter Orders',
    'orders.cycleSection': 'Regular Cycle Orders',
    'orders.none': 'No orders are available yet.',
    'orders.reward': '{count} tickets',
    'orders.phaseShort': 'Phase {phase}',
    'orders.replace': 'Replace for free',
    'orders.replacing': 'Replacing…',
    'orders.accept': 'Accept order',
    'orders.accepting': 'Accepting…',
    'orders.accepted':
        'Accepted. Only specified actions completed after acceptance count.',
    'orders.requiredSource':
        'Required source: {source}. Find and deliver it after accepting.',
    'orders.itemOption': '{name} · {quality} · item {number}',
    'orders.materialAvailability': 'Have {available} / need {required}',
    'orders.containerOption':
        '{name} (contains {contents} · {quality}) · item {number}',
    'orders.requiredRecipes':
        'Complete these recipes after accepting: {recipes}.',
    'orders.noMealContainers':
        'No matching meal container is in your backpack.',
    'orders.noPreparedMeal':
        'Put the shared meal in a reusable container, then place it in your backpack.',
    'orders.selectedCount': 'Selected {selected}; required {required}',
    'orders.tutorialCompleted': 'Completed',
    'orders.deliver': 'Deliver order',
    'orders.delivering': 'Delivering…',
    'orders.enterChapterFive': 'Enter the New Neighborhood (Chapter 5)',
    'orders.installChapterFive':
        'Open Game Library to install the Chapter 5 expansion',
    'orders.confirmTitle': 'Deliver {order}?',
    'orders.confirmConsume':
        'Turn in the soup and insulated meal box. Both will be consumed; you will receive {count} exchange tickets.',
    'orders.confirmReturn':
        'Turn in failed meals from {containers} containers. The containers will be returned marked for cleaning; you will receive {reward} exchange tickets.',
    'orders.confirmItems':
        'Deliver the {count} selected item(s) for {reward} exchange tickets.',
    'orders.cancelDelivery': 'Not yet',
    'orders.confirmDelivery': 'Confirm delivery',
    'orders.successDelivery':
        'Order complete. You received {count} exchange tickets.',
    'orders.successReplacement':
        'Order replaced for free. No items or tickets were spent.',
    'orders.error.operationFailed':
        '{operation} failed. Your save and items were not partially changed.',
    'orders.operation.enterChapterFive': 'Entering the New Neighborhood',
    'orders.operation.delivery': 'Order delivery',
    'orders.operation.acceptance': 'Accepting the order',
    'orders.operation.replacement': 'Replacing the order',
    'orders.error.chapter5PrerequisiteIncomplete':
        'Complete the Chapter 4 meal task before entering the New Neighborhood.',
    'orders.error.chapter5ExpansionNotInstalled':
        'The Chapter 5 expansion is not installed. Download it from Game Library first.',
    'orders.error.orderUnavailable':
        'This order is currently unavailable. Refresh the order list and try again.',
    'orders.error.orderChapterMalformed':
        'Chapter progress data is invalid. Orders have been disabled.',
    'orders.error.cycleOrderSlotsMalformed':
        'Cycle-order slot data is invalid. Orders have been disabled.',
    'orders.error.cycleOrderCursorMalformed':
        'Cycle-order replacement progress is invalid. No order was replaced.',
    'orders.error.cycleOrderNotActive':
        'This order is no longer in the active cycle list.',
    'orders.error.orderLocked':
        'This order’s unlock requirements are not complete.',
    'orders.error.orderNotAccepted':
        'Accept the order before completing its required actions.',
    'orders.error.orderAlreadyAccepted':
        'This order has already been accepted.',
    'orders.error.orderAlreadyCompleted': 'This order is already complete.',
    'orders.error.orderTutorialLocked':
        'Complete the prerequisite tutorial first.',
    'orders.error.tutorialStateMalformed':
        'The tutorial/order-task save is invalid. The order transaction was not completed and delivery is disabled.',
    'orders.error.orderSourceEventRequired':
        'The required item must be found at its specified location after accepting the order.',
    'orders.error.orderRecipeEventRequired':
        'Complete the required processing recipes after accepting the order.',
    'orders.error.orderSelectionInvalid':
        'The selected items do not match this order. No items were changed.',
    'orders.error.orderContainerMissing':
        'The required meal container is no longer available. Select it again.',
    'orders.error.orderItemMissing':
        'A selected item is no longer available. Select your items again.',
    'orders.error.orderItemNotAccepted':
        'This item does not meet the order requirements. No items were changed.',
    'orders.error.orderAcceptanceUnavailable':
        'This order cannot be accepted right now.',
    'orders.error.orderAcceptanceStateMalformed':
        'The order-acceptance record is invalid. The transaction was not completed.',
    'orders.error.recipeCompletionStateMalformed':
        'The recipe-completion record is invalid. The transaction was not completed.',
    'orders.error.inventoryMissing':
        'The backpack cannot be read right now. The transaction was not completed.',
    'orders.error.acceptedCycleOrderCannotBeReplaced':
        'An accepted cycle order cannot be replaced.',
    'orders.error.cycleOrderNoReplacement':
        'There are no other cycle orders available to replace it with.',
    'orders.error.cycleOrderUnavailable':
        'This cycle order cannot be replaced right now.',
    'orders.error.invalidOrderBalance':
        'The exchange-ticket balance is invalid. The order was not completed.',
    'orders.error.invalidCompletedOrderCount':
        'The completed-order record is invalid. The order was not completed.',
    'orders.error.orderCompletionStateMalformed':
        'The order-completion record is invalid. The transaction was not completed.',
    'orders.error.orderCompletionGroupInvalid':
        'The order-task progress is invalid. The transaction was not completed.',
    'orders.error.cycleStateMalformed':
        'The cycle-order data is malformed. Delivery has been disabled.',
    'orders.source.fixed:old_street_exchange':
        'Old Street fixed exchange point',
    'orders.recipe.ss.recipe.unpick_cloth': 'Unpick cloth for thread',
    'orders.recipe.ss.recipe.recycle_glue': 'Recycle adhesive',
    'relief.title': 'Government Relief',
    'relief.available':
        '{visible} meal(s) available{reserve}; one more every 24 hours. No daily login is required. Each meal restores {amount} stamina.',
    'relief.reserve': ' ({count} reserve meal(s))',
    'relief.ended':
        'The stable-life goal is complete; no new relief will accrue. {count} existing meal(s) remain. Chapter supply balance: {balance}.',
    'relief.endedShort': 'No new meals',
    'relief.stopWillHappen':
        'Relief will stop after the Phase 5 stable-life goal. You will be asked to confirm and receive 80 chapter-supply points.',
    'relief.stopWillHappenShort': 'Stops after Phase 5 · +80 supply',
    'relief.stopPrompt':
        'The stable-life goal is complete. Confirming will stop future relief while preserving current meals, and grant a separate one-time 80-point chapter supply. You can decide later.',
    'relief.stopPromptShort': 'Goal complete · Meals kept · +80 supply',
    'relief.processing': 'Processing…',
    'relief.finishAndClaim': 'Finish relief transition and claim supply',
    'relief.reviewOptions': 'Review relief and supply options',
    'relief.rollback':
        'Detected {count} device clock rollback(s); no duplicate relief was granted.',
    'relief.claiming': 'Claiming…',
    'relief.claimReserved': 'Use a reserved relief meal',
    'relief.claim': 'Claim relief meal',
    'relief.claimSupply': 'Claim chapter supply',
    'relief.claimSuccess':
        'Relief meal claimed: restored {restored} stamina; {count} meal(s) remain.',
    'relief.claimFull': 'Stamina is full. No relief was consumed.',
    'relief.noClaims': 'No relief meals are available.',
    'relief.claimFailed':
        'Could not claim relief; no claim was consumed. Please try again.',
    'relief.supplySuccess':
        'Chapter supply claimed: restored {restored}; {remaining} points remain.',
    'relief.supplyFailed':
        'Could not claim chapter supply; progress was unchanged. Please try again.',
    'relief.stopTitle': 'Stop future government relief?',
    'relief.stopBody':
        'After confirmation, no new government relief will accrue. Existing meals are preserved and can still be claimed. A separate one-time 80-point chapter supply will also be granted. Relief cannot be restarted.',
    'relief.notNow': 'Not now',
    'relief.confirmStop': 'Stop relief and claim supply',
    'relief.stopSuccess':
        'Future relief has stopped. {count} meal(s) remain, and {supply} chapter-supply points were granted.',
    'relief.stopFailed':
        'The relief transition did not finish; you can resume later.',
    'recovery.title': 'Recover Street Scrap Save',
    'recovery.damaged': 'The current save could not be verified',
    'recovery.healthy': 'No damaged save needs recovery',
    'recovery.preserveNotice':
        'Your original save will remain untouched. Review the backup time and progress before restoring; recovery creates a new save revision.',
    'recovery.healthyStatus':
        'Save status is healthy. No rollback is available.',
    'recovery.none':
        'No valid backup is available. Do not reset or overwrite this save.',
    'recovery.revision': 'Backup revision {revision}',
    'recovery.savedAt': 'Saved: {time}',
    'recovery.ruleset': 'Ruleset version: {version}{unsupported}',
    'recovery.unsupported': ' (not supported)',
    'recovery.choose': 'Choose backup',
    'recovery.confirmTitle': 'Restore this backup?',
    'recovery.confirmBody':
        'Load revision {revision} ({time}). The damaged save will not be overwritten before confirmation.',
    'recovery.reviewAgain': 'Review again',
    'recovery.restore': 'Restore this backup',
  };

  String text(String key, {Map<String, String> arguments = const {}}) {
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    final translations =
        normalizedLocale == 'en' || normalizedLocale.startsWith('en-')
        ? _en
        : _zhHant;
    var value = translations[key] ?? _zhHant[key] ?? key;
    for (final argument in arguments.entries) {
      value = value.replaceAll('{${argument.key}}', argument.value);
    }
    return value;
  }

  String checkpointPrompt(String prompt) {
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    if (normalizedLocale == 'en' || normalizedLocale.startsWith('en-')) {
      return _checkpointPromptsEn[prompt] ?? prompt;
    }
    return prompt;
  }

  String operationInstructions(String instructions) {
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    if (normalizedLocale == 'en' || normalizedLocale.startsWith('en-')) {
      return _operationInstructionsEn[instructions] ?? instructions;
    }
    return instructions;
  }

  String recipeQualityMode(String mode) {
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    if (normalizedLocale == 'en' || normalizedLocale.startsWith('en-')) {
      return _recipeQualityModesEn[mode] ?? mode;
    }
    return switch (mode) {
      'weighted-primary' => '依主材品質加權',
      'capped-at-primary' => '最高不超過主材品質',
      'preserve-primary' => '保留主材品質',
      _ => mode,
    };
  }

  String recipeFailureOutcome(String outcome) {
    final normalizedLocale = locale.toLowerCase().replaceAll('_', '-');
    if (normalizedLocale == 'en' || normalizedLocale.startsWith('en-')) {
      return _recipeFailureOutcomesEn[outcome] ?? outcome;
    }
    return outcome;
  }

  String stationName(String stationId) {
    final key = switch (stationId) {
      'recycler' => 'recipe.station.recycler',
      'tutorial' => 'recipe.station.tutorial',
      'workbench' => 'recipe.station.workbench',
      'kitchen' => 'recipe.station.kitchen',
      'dock' => 'recipe.station.dock',
      _ => null,
    };
    return key == null ? stationId : text(key);
  }

  String recipeDisplayName({
    required String operationId,
    required String inputItemId,
    String? outputItemId,
  }) {
    final action = text('recipes.action.$operationId');
    final input = itemName(inputItemId);
    if (outputItemId == null) {
      return text(
        'recipes.title.inputOnly',
        arguments: {'action': action, 'input': input},
      );
    }
    return text(
      'recipes.title.withOutput',
      arguments: {
        'action': action,
        'input': input,
        'output': itemName(outputItemId),
      },
    );
  }

  String fishingSpotName(String spotId, String fallbackName) {
    final key = switch (spotId) {
      'dock_entrance' => 'fishing.spot.dockEntrance',
      _ => null,
    };
    return key == null ? fallbackName : text(key);
  }

  String expeditionRewardSource(String source) {
    final key = switch (source) {
      'fixed:clothing_corner' =>
        'expedition.rewardSource.fixed.clothing_corner',
      'fixed:paper_wood_pile' =>
        'expedition.rewardSource.fixed.paper_wood_pile',
      'fixed:container_corner' =>
        'expedition.rewardSource.fixed.container_corner',
      'fixed:metal_recycling_rack' =>
        'expedition.rewardSource.fixed.metal_recycling_rack',
      'fixed:sorting_shed' => 'expedition.rewardSource.fixed.sorting_shed',
      'fixed:waterfront_materials' =>
        'expedition.rewardSource.fixed.waterfront_materials',
      'fixed:repair_district' =>
        'expedition.rewardSource.fixed.repair_district',
      'fixed:market_exchange' =>
        'expedition.rewardSource.fixed.market_exchange',
      'fixed:old_street_exchange' =>
        'expedition.rewardSource.fixed.old_street_exchange',
      'surprise:commonScraps' =>
        'expedition.rewardSource.surprise.commonScraps',
      'surprise:intactBase' => 'expedition.rewardSource.surprise.intactBase',
      'surprise:containers' => 'expedition.rewardSource.surprise.containers',
      'surprise:optionalSpecial' =>
        'expedition.rewardSource.surprise.optionalSpecial',
      _ when source.startsWith('fixed:') =>
        'expedition.rewardSource.fixedGeneric',
      _ when source.startsWith('surprise:') =>
        'expedition.rewardSource.surpriseGeneric',
      _ => 'expedition.rewardSource.other',
    };
    return text(key);
  }

  String maintenanceTitle(String title) {
    final key = switch (title) {
      '補線修整' => 'maintenance.title.threadRepair',
      '乾燥處理' => 'maintenance.title.drying',
      '擦拭去鏽' => 'maintenance.title.rustRemoval',
      '重新熱整' => 'maintenance.title.heatReshape',
      '重新乾燥燃料' => 'maintenance.title.fuelRedrying',
      '重新定位木板' => 'maintenance.title.boardAlignment',
      _ => null,
    };
    return key == null ? title : text(key);
  }

  static StreetScrapLocalizations of(BuildContext context) =>
      StreetScrapLocalizationsScope.maybeOf(context)?.localizations ??
      const StreetScrapLocalizations('zh-Hant');
}

/// Host-independent injection point for the active locale.
class StreetScrapLocalizationsScope extends InheritedWidget {
  const StreetScrapLocalizationsScope({
    super.key,
    required this.locale,
    required super.child,
  });

  final String locale;

  StreetScrapLocalizations get localizations =>
      StreetScrapLocalizations(locale);

  static StreetScrapLocalizationsScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StreetScrapLocalizationsScope>();

  @override
  bool updateShouldNotify(StreetScrapLocalizationsScope oldWidget) =>
      locale != oldWidget.locale;
}
