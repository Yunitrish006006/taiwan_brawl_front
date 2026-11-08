# 街角拾荒完整材料字典

本表對應 `../design/street-scrap-design.json` 的 111 項材料／裝備定義。尺寸是灰盒初值；「內容」隨容器占格，不額外占格。來源列顯示成功路徑，不代表完整數量／失敗／容器狀態已模擬。配方 ID 省略 `ss.recipe.` 前綴。

| ID／名稱 | 首次階段 | 占位 | 來源 | 後續配方／功能 |
|---|---|---|---|---|
| `cloth.rag_piece` 破布片 | 0 | 1×1 | 固定供應×3（階段0／體力3） | unpick_cloth；sew_strip |
| `cloth.edge_scrap` 布邊料 | 0 | 1×1 | 固定供應×3（階段0／體力3）；unpick_cloth | braid_binding；clean_metal |
| `cloth.repair_strip` 縫補布條 | 1 | 1×1 | sew_strip | patch_cloth；tool_handle；upgrade_rod |
| `cloth.patchwork` 拼接布 | 1 | 1×2 | patch_cloth | coat_cloth；upgrade_bag；cut_filter；insulate_cloth |
| `cloth.thread_spool` 線團 | 0 | 1×1 | 固定供應×1（階段0／體力3）；join_thread | sew_strip；patch_cloth；braid_rope；upgrade_bag；cut_filter；insulate_cloth；repair_line；insulated_box；weather_bag |
| `cloth.thread_end` 線頭 | 0 | 1×1 | 固定供應×3（階段0／體力3）；unpick_cloth | join_thread；repair_line |
| `cloth.binding` 綁帶 | 1 | 1×1 | braid_binding | braid_rope；upgrade_bag；pliers；awl_bone；tarp |
| `rope.coarse` 粗繩 | 1 | 1×1 | 固定供應×1（階段2／體力3）；braid_rope | crowbar；float；raft；weather_bag |
| `line.fishing` 釣線 | 2 | 1×1 | repair_line | basic_rod；advanced_rod；rig |
| `cloth.waterproof` 防水布 | 3 | 1×2 | coat_cloth | tarp；weather_bag |
| `cloth.insulation` 隔熱布 | 3 | 1×2 | insulate_cloth | insulated_box |
| `wood.chip` 碎木片 | 0 | 1×1 | 固定供應×3（階段0／體力3）；saw_driftwood；salvage_board | press_rod |
| `wood.sawdust` 木屑 | 0 | 1×1 | 固定供應×3（階段0／體力3）；saw_driftwood；salvage_board | sawdust_fuel |
| `wood.driftwood` 漂木 | 0 | 1×2 | 固定供應×2（階段0／體力3） | mix_fuel；make_charcoal；saw_driftwood |
| `wood.rod` 木條 | 3 | 1×2 | press_rod | nail_board；tool_handle；basic_rod；awl_bone |
| `wood.board` 木板 | 0 | 1×2 | nail_board；階段0驚喜原生板／章節1與3教學獎勵 | assemble_frame；wooden_crate；salvage_board；raft；reinforced_chest；weather_bag |
| `wood.frame` 木框 | 3 | 2×2 | assemble_frame | tarp；shelter |
| `adhesive.residue` 標籤殘膠 | 1 | 1×1 | 固定供應×2（階段1／體力3） | recycle_glue |
| `adhesive.recycled` 回收膠料 | 1 | 1×1 | recycle_glue | press_rod；assemble_frame；wooden_crate；seal_packaging |
| `adhesive.starch_paste` 澱粉糊 | 4 | 1×1 | starch_glue | 階段4起替代 press_rod 的回收膠料，1比1；不替代防水塗料。 |
| `metal.scrap` 金屬屑 | 1 | 1×1 | 固定供應×3（階段1／體力3） | compact_metal |
| `metal.shard` 金屬碎片 | 1 | 1×1 | 固定供應×3（階段1／體力3） | clean_metal；bend_hook |
| `metal.sheet` 金屬片 | 1 | 1×1 | 固定供應×1（階段1／體力3）；clean_metal | shape_bar；cut_wire；bend_ferrule；crowbar；pliers；pot；stove；meal_box；condenser |
| `metal.bar` 金屬條 | 3 | 1×1 | compact_metal；shape_bar | form_nails；awl_bone；stove |
| `metal.wire` 鐵線 | 1 | 1×1 | 固定供應×2（階段1／體力3）；cut_wire | bend_fastener；bend_hook |
| `metal.nail_bundle` 釘件束 | 1 | 1×1 | 固定供應×1（階段1／體力3）；form_nails | nail_board；assemble_frame；wooden_crate；stove |
| `metal.fastener` 金屬扣 | 3 | 1×1 | bend_fastener | float_part；pliers；upgrade_rod；meal_box；reinforced_chest |
| `metal.ferrule` 套環 | 3 | 1×1 | bend_ferrule | tool_handle |
| `metal.hook` 釣鉤 | 3 | 1×1 | bend_hook | basic_rod；rig |
| `plastic.scrap` 塑料碎片 | 1 | 1×1 | 固定供應×3（階段1／體力3） | press_plastic |
| `plastic.sheet` 塑料片 | 3 | 1×2 | press_plastic | float_part；seal_part |
| `plastic.float_part` 浮標零件 | 3 | 1×1 | float_part | advanced_rod |
| `plastic.seal` 防水接頭 | 3 | 1×1 | seal_part | shelter；condenser |
| `paper.scrap` 紙屑 | 0 | 1×1 | 固定供應×3（階段0／體力3） | mix_pulp；mix_fuel；sawdust_fuel |
| `paper.pulp` 紙漿 | 1 | 1×1 | mix_pulp | recycle_glue；form_paperboard |
| `paper.board` 乾燥紙板 | 3 | 1×2 | form_paperboard | seal_packaging |
| `paper.packaging` 防潮包材 | 3 | 1×1 | seal_packaging | toolkit；cook_kit；fish_pack |
| `water.turbid` 濁水 | 4 | 內容（隨容器） | 固定供應×1（階段4／體力3）；settle_muddy | mix_pulp；filter_turbid |
| `water.dirty` 髒水 | 4 | 內容（隨容器） | 固定供應×1（階段4／體力3） | filter_dirty |
| `water.muddy` 泥水 | 4 | 內容（隨容器） | 固定供應×1（階段4／體力3） | settle_muddy |
| `water.filtered` 過濾水 | 0 | 內容（隨容器） | 固定供應×1（階段0／體力2）；filter_turbid；filter_dirty | mix_pulp；wash_container；boil_water；distill_water；wash_filter；clean_food；starch_glue |
| `water.boiled` 開水 | 4 | 內容（隨容器） | boil_water | soup_basic；soup_vegetable；soup_fish；shared_meal |
| `water.distilled` 蒸餾水 | 5 | 內容（隨容器） | distill_water | 精密保養：1份加布邊料1，恢復金屬工具10次使用量；空瓶保留。 |
| `water.mineral` 礦泉水 | 5 | 內容（隨容器） | 固定供應×1（階段5／體力3） | 湯品替代開水，1比1，品質+3；普通水仍可完成主線。 |
| `material.mineral_pack` 礦物包 | 5 | 1×1 | 固定供應×1（階段5／體力3） | ss.order.wall：礦物包1與泥料2。 |
| `material.mud` 泥料 | 4 | 1×1 | settle_muddy | ss.order.wall，或3份交分類回收。 |
| `material.charcoal` 木炭 | 4 | 1×1 | make_charcoal | filter_turbid；filter_dirty |
| `material.filter_cloth` 濾布 | 4 | 1×1 | cut_filter | filter_turbid；filter_dirty；wash_filter |
| `material.waterproof_coating` 防水塗料 | 3 | 1×1 | 固定供應×1（階段3／體力3） | coat_cloth；seal_part |
| `material.glass_scrap` 玻璃碎料 | 1 | 1×1 | recycle_glass | 3份交分類回收。 |
| `fish.raw` 整魚 | 2 | 1×2 | fishing-third-attempt-guarantee | fillet_fish |
| `fish.meat` 魚肉 | 2 | 1×1 | fillet_fish | soup_fish；shared_meal；fish_pack |
| `fish.bone` 魚骨 | 2 | 1×1 | fillet_fish | awl_bone |
| `fish.pack` 魚貨包 | 3 | 1×2 | fish_pack | ss.order.advanced_fish；也可拆回魚肉2，包材不返還。 |
| `food.scrap` 食物碎屑 | 2 | 1×1 | 固定供應×2（階段2／體力3） | make_bait |
| `food.greens` 野菜 | 4 | 1×1 | 固定供應×2（階段4／體力3） | clean_food |
| `food.edible` 可食拾得物 | 4 | 1×1 | 固定供應×2（階段4／體力3） | clean_food |
| `food.cleaned` 清理食材 | 4 | 1×1 | clean_food | soup_basic；soup_vegetable；shared_meal |
| `food.starch` 澱粉食材 | 4 | 1×1 | 固定供應×1（階段4／體力3） | starch_glue |
| `herb.wild` 香草 | 4 | 1×1 | 固定供應×2（階段4／體力3） | dry_herb；herb_bait |
| `seasoning.salt` 鹽 | 4 | 1×1 | 固定供應×1（階段4／體力3） | blend_seasoning |
| `seasoning.packet` 調味包 | 4 | 1×1 | dry_herb | blend_seasoning |
| `seasoning.blend` 綜合香料 | 5 | 1×1 | blend_seasoning | 替代料理可選調味包1，品質+3，不與其他調味疊加。 |
| `fuel.mixed` 混合燃料 | 1 | 1×1 | mix_fuel | dry_fuel |
| `fuel.dry` 乾燥燃料 | 3 | 1×1 | 固定供應×1（階段3／體力3）；dry_fuel；sawdust_fuel | form_nails；press_plastic；boil_water；distill_water；make_charcoal；starch_glue；soup_basic；soup_vegetable；soup_fish；shared_meal；compact_metal；shape_bar；fuel_pack |
| `fuel.oilcloth` 可燃油布 | 3 | 1×1 | 固定供應×1（階段3／體力3） | fuel_pack |
| `fuel.efficient_pack` 節能燃料包 | 5 | 1×2 | fuel_pack | 替代所有乾燥燃料槽，共3個燃料單位，餘額存於原物件。 |
| `container.broken_bottle` 破瓶 | 0 | 1×1 | 固定供應×1（階段0／體力3） | recycle_glass |
| `container.used_intact` 完整舊瓶 | 0 | 1×2 | 固定供應×1（階段0／體力3） | wash_container |
| `container.clean` 清潔容器 | 0 | 1×2 | public-basin-wash；wash_container | float |
| `container.clean_jar` 清潔罐 | 1 | 1×2 | 固定供應×1（階段1／體力3） | pot；condenser |
| `container.meal_box` 餐盒 | 4 | 1×2 | meal_box | insulated_box |
| `container.meal_box_insulated` 保溫餐盒 | 4 | 1×2 | insulated_box | 可重用裝餐；ss.order.insulated 會連同容器交付。 |
| `bag.basic` 起始背包 | 0 | 裝備（不占格） | permanent-tutorial | upgrade_bag |
| `bag.reinforced` 修補背包 | 3 | 裝備（不占格） | upgrade_bag | weather_bag |
| `bag.weatherproof` 耐候收納袋 | 5 | 裝備（不占格） | weather_bag | 裝備背包6×4，升級一次，不額外占背包格。 |
| `storage.wooden_crate` 木箱 | 3 | 2×2 | wooden_crate | reinforced_chest |
| `storage.reinforced_chest` 加固箱櫃 | 5 | 2×2 | reinforced_chest | 地盤放置容量20，家具位1。 |
| `bait.basic` 基礎魚餌 | 2 | 1×1 | make_bait | herb_bait |
| `bait.herb` 香草餌 | 4 | 1×1 | herb_bait | 釣魚消耗1，精準時額外魚品質+3。 |
| `tool.needle` 針具 | 0 | 1×1 | permanent-tutorial | unpick_cloth；sew_strip；patch_cloth；upgrade_bag；cut_filter；insulate_cloth；insulated_box |
| `tool.paper_mould` 抄紙模具 | 3 | 站點設施 | permanent-station | form_paperboard |
| `tool.awl` 修補錐 | 3 | 1×2 | awl_bone | toolkit |
| `tool.crowbar` 撬具 | 3 | 1×2 | crowbar | 使用於額外翻找選項，每次扣1耐久；普通翻找不需要。 |
| `tool.pliers` 分類鉗 | 3 | 1×2 | pliers | toolkit |
| `tool.kit` 維修工具組 | 5 | 2×2 | toolkit | 存放並使用原鉗與錐，子物件不重複占格、不洗耐久。 |
| `tool.rod_basic` 簡易釣竿 | 2 | 1×3 | renewable-loaner；basic_rod | upgrade_rod |
| `tool.rod_repaired` 修補釣竿 | 3 | 1×3 | upgrade_rod | advanced_rod |
| `tool.rod_advanced` 改良釣竿 | 5 | 1×3 | advanced_rod | 釣魚容錯乘1.2，單次扣1耐久。 |
| `tool.pot` 簡易鍋具 | 3 | 2×2 | pot | cook_kit |
| `tool.stove` 便攜爐架 | 3 | 2×2 | stove | cook_kit |
| `tool.cook_kit` 外出料理組 | 5 | 2×3 | cook_kit | 可選炊具交換單，交1套得10券；收藏記錄首次取得。 |
| `tool.condenser` 冷凝器 | 5 | 2×2 | condenser | distill_water |
| `toolpart.handle` 工具柄 | 3 | 1×2 | tool_handle | crowbar；pot |
| `toolpart.rig` 備用釣組 | 3 | 1×1 | rig | 消耗1修復釣竿10次，不超最大耐久。 |
| `toolpart.float` 簡易浮標 | 2 | 1×2 | float | 掛於釣點，基礎竿容錯乘1.05；不與升級竿容錯疊加。 |
| `structure.raft` 小型浮架 | 3 | 2×2 | raft | 放置於碼頭設施位，浮架釣點可在魚骨與漂木的失敗副產物中選一；仍不保證成功魚。 |
| `structure.tarp` 避雨棚布 | 3 | 2×2 | tarp | shelter |
| `structure.shelter` 可折雨棚 | 5 | 2×2 | shelter | 階段5穩定住所任務；地盤家具位1。 |
| `meal.soup_basic` 基礎湯 | 4 | 內容（隨容器） | soup_basic | 自用恢復基礎20乘品質，或ss.order.meal交付。 |
| `meal.soup_fish` 魚湯 | 4 | 內容（隨容器） | soup_fish | 自用恢復基礎36乘品質，或ss.order.meal交付。 |
| `meal.soup_vegetable` 素食湯 | 4 | 內容（隨容器） | soup_vegetable | 自用恢復基礎32乘品質，或ss.order.meal交付。 |
| `meal.shared` 共享餐 | 5 | 內容（隨容器） | shared_meal | 自用恢復基礎45乘品質，或ss.order.advanced_cooking交付。 |
| `meal.failed` 失敗餐 | 4 | 內容（隨容器） | 料理失手分支 | 自用恢復4，或3份交回收單，返還原餐盒。 |
| `meal.relief_box` 政府救助便當 | 0 | 救助信箱 | daily-until-stable | 從信箱消耗1恢復40，不生成可交易餐盒。 |
| `bundle.cloth_scrap` 布邊料束 | 0 | 1×2 | 手動打包 cloth.edge_scrap×4 | 手動拆回4份cloth.edge_scrap，保留每份品質與來源；不能直接加工。 |
| `bundle.thread_end` 線頭束 | 0 | 1×2 | 手動打包 cloth.thread_end×4 | 手動拆回4份cloth.thread_end，保留每份品質與來源；不能直接加工。 |
| `bundle.wood_chip` 碎木片束 | 0 | 1×2 | 手動打包 wood.chip×4 | 手動拆回4份wood.chip，保留每份品質與來源；不能直接加工。 |
| `bundle.metal_scrap` 金屬屑束 | 1 | 1×2 | 手動打包 metal.scrap×4 | 手動拆回4份metal.scrap，保留每份品質與來源；不能直接加工。 |
| `bundle.plastic_scrap` 塑料碎片束 | 1 | 1×2 | 手動打包 plastic.scrap×4 | 手動拆回4份plastic.scrap，保留每份品質與來源；不能直接加工。 |
| `bundle.paper_scrap` 紙屑束 | 0 | 1×2 | 手動打包 paper.scrap×4 | 手動拆回4份paper.scrap，保留每份品質與來源；不能直接加工。 |

階段是首次可用時間，不是限制後期取得；較晚配方仍可製作同一種早期材料。表內來源名稱為查核鍵，不作 UI 顯示文字。
