/// Read-only catalog of all field events that can occur during a battle.
/// Mirrors the event definitions in royale_field_events.js.
class RoyaleFieldEventInfo {
  const RoyaleFieldEventInfo({
    required this.id,
    required this.category,
    required this.tone,
    required this.titleZhHant,
    required this.titleEn,
    required this.descriptionZhHant,
    required this.descriptionEn,
    this.duration = 0,
    this.fieldEffect,
    this.isShield = false,
  });

  final String id;
  final String category;

  /// 'positive' | 'negative' | 'mixed'
  final String tone;

  final String titleZhHant;
  final String titleEn;
  final String descriptionZhHant;
  final String descriptionEn;

  /// 持續效果時長（ms），0 表示即時觸發型
  final int duration;

  /// 啟動的持續場地效果 kind，如 'power_outage'
  final String? fieldEffect;

  /// 是否為護盾型事件
  final bool isShield;

  bool get isPersistent => duration > 0 && fieldEffect != null;

  String localizedTitle(String locale) {
    if (locale == 'zh-Hant') return titleZhHant;
    return titleEn;
  }

  String localizedDescription(String locale) {
    if (locale == 'zh-Hant') return descriptionZhHant;
    return descriptionEn;
  }
}

const List<RoyaleFieldEventInfo> kFieldEventCatalog = [
  // ── 交通 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'mountain_monkey',
    category: 'traffic',
    tone: 'negative',
    titleZhHant: '山道猴子肇事',
    titleEn: 'Road Monkey Incident',
    descriptionZhHant: '山道猴子式駕駛擦撞後溜之大吉。\n'
        '50% 肇逃 → 體力 -90；70% 可獲保險理賠 +20；30% 肇事者被逮 +25。',
    descriptionEn:
        '50% hit-and-run → physical HP −90. '
        '70% insurance +20, 30% caught bonus +25.',
  ),
  RoyaleFieldEventInfo(
    id: 'road_three_treasures',
    category: 'traffic',
    tone: 'negative',
    titleZhHant: '馬路三寶肇事',
    titleEn: 'Traffic Hazard Trio',
    descriptionZhHant: '馬路三寶危險駕駛。\n'
        '30% 肇逃 → 體力 -85，有 20% 機率嚴重殘廢；80% 保險理賠。',
    descriptionEn:
        '30% hit-and-run → HP −85 (20% severe disability). '
        '80% insurance, 25% caught bonus.',
  ),
  RoyaleFieldEventInfo(
    id: 'drunk_driver',
    category: 'traffic',
    tone: 'negative',
    titleZhHant: '酒癮慣犯肇事',
    titleEn: 'Drunk Driver Repeat Offender',
    descriptionZhHant: '酒癮慣犯再度肇事。\n80% 肇逃 → 體力 -110；保險理賠機率僅 30%；45% 被逮 +35。',
    descriptionEn:
        '80% hit-and-run → HP −110. Only 30% insurance, 45% caught bonus +35.',
  ),
  RoyaleFieldEventInfo(
    id: 'malicious_hit_run',
    category: 'traffic',
    tone: 'negative',
    titleZhHant: '惡意肇逃',
    titleEn: 'Deliberate Hit-and-Run',
    descriptionZhHant: '蓄意車禍肇逃，傷害必然 (體力 -130 )。\n保險核賠機率 90%，被逮可得 +40。',
    descriptionEn:
        'Guaranteed hit-and-run → HP −130. '
        '90% insurance payout; 50% caught bonus +40.',
  ),
  RoyaleFieldEventInfo(
    id: 'truck_driver',
    category: 'traffic',
    tone: 'negative',
    titleZhHant: '大卡車肇事',
    titleEn: 'Semi-Truck Accident',
    descriptionZhHant: '大卡車強行變道後肇逃 (85%)，傷害較重 (體力 -150)。\n保險給付 75%，被逮 +38。',
    descriptionEn:
        '85% hit-and-run → HP −150. 75% insurance, 35% caught bonus +38.',
  ),
  RoyaleFieldEventInfo(
    id: 'severely_disabled',
    category: 'traffic',
    tone: 'negative',
    titleZhHant: '雷殘事故',
    titleEn: 'Catastrophic Crash',
    descriptionZhHant: '嚴重殘廢事故，無保險理賠。\n體力 -220，精神 -50，強制入院。',
    descriptionEn: 'Catastrophic injury — no insurance. HP −220 · Spirit HP −50.',
  ),

  // ── 治安 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'fraud_epidemic',
    category: 'security',
    tone: 'negative',
    titleZhHant: '詐騙集團猖獗',
    titleEn: 'Fraud Gang Rampage',
    descriptionZhHant: '詐騙盛行 25 秒，金錢持續 -2.2/秒。\n隨機一方：25% 買到毒商品 (體力 -20、精神 -30)，否則被騙走 -10 金。',
    descriptionEn:
        'Persistent: money −2.2/s for 25s. '
        'Random side: 25% poisoned goods (HP −20, Spirit −30) or scammed −10 money.',
    duration: 25000,
    fieldEffect: 'fraud_epidemic',
  ),

  // ── 政治 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'world_war',
    category: 'politics',
    tone: 'negative',
    titleZhHant: '世界大戰爆發',
    titleEn: 'World War Outbreak',
    descriptionZhHant: '全球衝突爆發！雙方立即受到砲擊 (體力 -80)，並持續流失體力 -6/秒，共 20 秒。',
    descriptionEn:
        'Both sides take HP −80 immediately. '
        'Persistent: HP −6/s for 20s.',
    duration: 20000,
    fieldEffect: 'world_war',
  ),

  // ── 家庭 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'cockroach_poison',
    category: 'family',
    tone: 'negative',
    titleZhHant: '蟑螂藥下毒',
    titleEn: 'Cockroach Bait Incident',
    descriptionZhHant: '有人下了蟑螂藥。雙方體力持續 -5/秒，共 12 秒。',
    descriptionEn: 'Persistent: HP −5/s for both sides for 12s.',
    duration: 12000,
    fieldEffect: 'cockroach_poison',
  ),
  RoyaleFieldEventInfo(
    id: 'power_outage',
    category: 'family',
    tone: 'negative',
    titleZhHant: '全區停電',
    titleEn: 'Power Outage',
    descriptionZhHant: '突然停電 18 秒！雙方體能能量 -0.5/秒、精神能量 -0.4/秒。',
    descriptionEn: 'Persistent: physical energy −0.5/s · spirit energy −0.4/s for 18s.',
    duration: 18000,
    fieldEffect: 'power_outage',
  ),
  RoyaleFieldEventInfo(
    id: 'water_outage',
    category: 'family',
    tone: 'negative',
    titleZhHant: '全區停水',
    titleEn: 'Water Outage',
    descriptionZhHant: '停水 15 秒！雙方體能能量 -0.8/秒。',
    descriptionEn: 'Persistent: physical energy −0.8/s for both sides for 15s.',
    duration: 15000,
    fieldEffect: 'water_outage',
  ),
  RoyaleFieldEventInfo(
    id: 'dinosaur_parent',
    category: 'family',
    tone: 'positive',
    titleZhHant: '恐龍家長護航',
    titleEn: 'Dinosaur Parent Shields',
    descriptionZhHant: '恐龍家長強勢護航，隨機護住一方，使其完全抵擋下一個負面場地事件。',
    descriptionEn:
        'Shields a random side from the next negative field event.',
    isShield: true,
  ),
  RoyaleFieldEventInfo(
    id: 'asian_parent',
    category: 'family',
    tone: 'negative',
    titleZhHant: '亞洲家長管教',
    titleEn: 'Asian Parent Outburst',
    descriptionZhHant: '亞洲家長嚴格施壓，雙方：精神 -45、體能能量 -0.8、精神能量 -1.0。',
    descriptionEn:
        'Both sides: Spirit HP −45 · physical energy −0.8 · spirit energy −1.0.',
  ),

  // ── 公司 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'good_boss',
    category: 'company',
    tone: 'positive',
    titleZhHant: '好老闆犒賞',
    titleEn: 'Good Boss Rewards',
    descriptionZhHant: '好老闆加薪又給補品！雙方：金錢 +22、精神 +28。',
    descriptionEn: 'Both sides: money +22 · spirit HP +28.',
  ),
  RoyaleFieldEventInfo(
    id: 'exploitative_boss',
    category: 'company',
    tone: 'negative',
    titleZhHant: '慣老闆強制加班',
    titleEn: 'Exploitative Boss Overtime',
    descriptionZhHant: '無薪加班！雙方精神 -55，並持續過勞效果 -8 精神/秒，共 20 秒。',
    descriptionEn:
        'Both sides: Spirit HP −55. '
        'Persistent: spirit HP −8/s for 20s.',
    duration: 20000,
    fieldEffect: 'overwork',
  ),

  // ── 回復 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'rehabilitation',
    category: 'recovery',
    tone: 'mixed',
    titleZhHant: '強制戒毒療程',
    titleEn: 'Mandatory Rehabilitation',
    descriptionZhHant: '雙方各自擲骰：40% 成功清除過勞/詐騙效果並恢復體力 +20、精神 +40；'
        '60% 失敗，精神 -20、精神能量 -0.5。',
    descriptionEn:
        'Each side: 40% clear overwork/fraud effects and heal (HP +20, Spirit +40); '
        '60% fail → Spirit HP −20 · spirit energy −0.5.',
  ),
  RoyaleFieldEventInfo(
    id: 'hospital',
    category: 'recovery',
    tone: 'mixed',
    titleZhHant: '緊急住院',
    titleEn: 'Emergency Hospitalization',
    descriptionZhHant: '雙方緊急送醫：體力 +80，但醫療費用 -12 金。',
    descriptionEn: 'Both sides: HP +80 · money −12.',
  ),

  // ── 食品 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'food_poisoning',
    category: 'food',
    tone: 'negative',
    titleZhHant: '食品中毒',
    titleEn: 'Food Poisoning',
    descriptionZhHant: '外食中毒！雙方體力 -60、體能能量 -0.9。',
    descriptionEn: 'Both sides: HP −60 · physical energy −0.9.',
  ),

  // ── 外送 ──────────────────────────────────────────────────────────
  RoyaleFieldEventInfo(
    id: 'delivery_surge',
    category: 'delivery',
    tone: 'mixed',
    titleZhHant: '外送尖峰潮',
    titleEn: 'Delivery Surge Rush',
    descriptionZhHant: '外送需求爆炸，雙方各自隨機：\n'
        '・50% 大賺 → 金錢 +18、體能 -0.6\n'
        '・50% 過勞 → 體力 -30、體能 -1.0、精神 -15',
    descriptionEn:
        'Each side randomly: '
        '50% profit (money +18, energy −0.6) or '
        '50% burnout (HP −30, energy −1.0, spirit −15).',
  ),
];
