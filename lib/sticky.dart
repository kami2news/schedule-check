/// 付箋: 予定のメモ（ほかの人の予定・連絡文など）を、カレンダーの上に貼っておく
class StickyNote {
  StickyNote({
    required this.id,
    required this.text,
    this.x = 1,
    this.y = 0,
    this.collapsed = false,
  });

  final String id;
  String text;

  /// 貼る位置（カレンダーの範囲に対する割合。0〜1。x=1 は右端に寄せる）
  double x;
  double y;

  /// たたんで見出しだけにしているか
  bool collapsed;

  /// 見出し（1 行目）
  String get heading {
    final first = text.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty,
        orElse: () => '');
    return first.isEmpty ? '付箋' : first;
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'x': x, 'y': y, if (collapsed) 'collapsed': true};

  factory StickyNote.fromJson(Map<String, dynamic> j) => StickyNote(
        id: j['id'] as String,
        text: j['text'] as String? ?? '',
        x: (j['x'] as num?)?.toDouble() ?? 1,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        collapsed: j['collapsed'] == true,
      );
}
