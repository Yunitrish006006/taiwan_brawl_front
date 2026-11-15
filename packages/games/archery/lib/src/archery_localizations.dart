/// Package-owned player-facing copy for the Archery game.
class ArcheryLocalizations {
  const ArcheryLocalizations(this.locale);

  final String locale;

  String text(String key) {
    final normalized = locale.toLowerCase().replaceAll('_', '-');
    final table = normalized == 'en' || normalized.startsWith('en-')
        ? _en
        : normalized == 'ja' || normalized.startsWith('ja-')
        ? _ja
        : _zhHant;
    return table[key] ?? _zhHant[key] ?? key;
  }
}

const _zhHant = <String, String>{
  'Archery Game': '弓箭射擊遊戲',
  'Score': '分數',
  'Best': '最高分',
  'Draw Strength': '拉弦體力',
  'Drawing...': '拉弦中...',
  'Long press to draw': '長按拉弦',
  'Level': '等級',
  'Target is stationary': '標靶固定',
  'Target is moving': '標靶移動中',
};

const _en = <String, String>{
  'Archery Game': 'Archery Game',
  'Score': 'Score',
  'Best': 'Best',
  'Draw Strength': 'Draw Strength',
  'Drawing...': 'Drawing...',
  'Long press to draw': 'Long press to draw',
  'Level': 'Level',
  'Target is stationary': 'Target is stationary',
  'Target is moving': 'Target is moving',
};

const _ja = <String, String>{
  'Archery Game': 'アーチェリーゲーム',
  'Score': 'スコア',
  'Best': '最高得点',
  'Draw Strength': '弓を引く体力',
  'Drawing...': '引いています...',
  'Long press to draw': '長押しで弓を引く',
  'Level': 'レベル',
  'Target is stationary': '標的は固定',
  'Target is moving': '標的が移動中',
};
