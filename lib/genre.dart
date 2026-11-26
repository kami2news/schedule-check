import 'models.dart';

/// 取り込んだ予定の「系統」（授業・バイト・就活・病院…）。
/// 文章の語から判断し、本人のマイカレンダーへの振り分けに使う。
class Genre {
  const Genre(this.label, this.words, this.calendarNames);

  /// 画面に出す名前
  final String label;

  /// 文章にこの語があれば、この系統とみなす
  final RegExp words;

  /// この語を名前に含むカレンダーがあれば、そこに入れる（「就活」「就職活動」など）
  final List<String> calendarNames;
}

/// 判断する順（先にあるものを優先）
final kGenres = <Genre>[
  Genre('バイト', RegExp(r'シフト|バイト|アルバイト|勤務|出勤|早番|遅番|中番|日勤|夜勤|労働条件|作業日|作業時間'),
      ['バイト', 'シフト', '仕事', '勤務', 'アルバイト']),
  Genre('就活', RegExp(r'説明会|選考|面接|インターン|エントリーシート|適性検査|新卒|\d{2}卒|採用|内定|OB訪問|OG訪問|就活|就職|座談会|ES提出|リクルーター|キャリア面談|就活サポート'),
      ['就活', '就職', '選考', 'インターン', 'キャリア']),
  Genre('授業', RegExp(r'授業|講義|演習|ゼミ|実験|休講|補講|試験|小テスト|履修|[0-9]\s*(?:時限|限)|レポート|課題|シラバス|学期|単位'),
      ['授業', '大学', '学校', '講義', 'ゼミ', '試験']),
  Genre('病院', RegExp(r'病院|クリニック|医院|歯科|眼科|皮膚科|内科|外科|耳鼻|整形|診察|診療|検診|健康診断|受診|通院|薬局'),
      ['病院', '通院', '健康', '医療']),
  Genre('移動・旅行', RegExp(r'新幹線|乗車|搭乗|便名|飛行機|空港|ホテル|チェックイン|チェックアウト|宿泊|旅行|帰省|のぞみ|ひかり|こだま'),
      ['旅行', '移動', 'お出かけ', '帰省']),
  Genre('配達', RegExp(r'お届け|配達|配送|宅配|宅急便|荷物|置き配'), ['配達', '荷物', '買い物']),
  Genre('お店の予約', RegExp(r'美容院|美容室|サロン|カット|カラー|ネイル|来店|ショップ|店舗'), ['予約', 'お店', '美容']),
  Genre('遊び・イベント', RegExp(r'ライブ|公演|開演|開場|飲み会|忘年会|新年会|歓迎会|送別会|打ち上げ|映画|カラオケ|イベント|フェス|コンサート|演奏会'),
      ['遊び', 'プライベート', 'イベント', '趣味']),
];

const _generic = {'予定', 'その他', 'メイン', 'マイカレンダー'};

Genre? genreByLabel(String? label) =>
    label == null ? null : kGenres.where((g) => g.label == label).firstOrNull;

/// まず [near]（その予定の行・タイトル）で、なければ [whole]（文章全体）で系統を決める
Genre? detectGenre(String near, String whole) {
  for (final text in [near, whole]) {
    for (final g in kGenres) {
      if (g.words.hasMatch(text)) return g;
    }
  }
  return null;
}

/// 本人のマイカレンダーから入れ先を選ぶ。見つからなければ null（種類の既定のカレンダーを使う）
///
/// 1. カレンダーに設定した「振り分けのキーワード」がその予定の行・タイトルにある
/// 2. カレンダーの名前がその予定の行・タイトルにある
/// 3. 振り分けのキーワードが文章全体にある
/// 4. カレンダーに「この系統の予定を入れる」と設定してある
/// 5. カレンダーの名前が系統に合う（「就活」「病院」など）
CalendarDef? pickCalendar(
    List<CalendarDef> cals, String near, String whole, Genre? genre) {
  CalendarDef? byKeyword(String text) {
    CalendarDef? best;
    var bestLen = 0;
    for (final c in cals) {
      for (final k in c.keywords) {
        final w = k.trim();
        if (w.isNotEmpty && w.length > bestLen && text.contains(w)) {
          best = c;
          bestLen = w.length;
        }
      }
    }
    return best;
  }

  final k1 = byKeyword(near);
  if (k1 != null) return k1;
  final byName = [...cals]..sort((a, b) => b.name.length.compareTo(a.name.length));
  for (final c in byName) {
    final n = c.name.trim();
    // 「予定」のような一般的な名前は、文の中にあっても手がかりにしない（「お届け予定」など）
    if (n.length >= 2 && !_generic.contains(n) && near.contains(n)) return c;
  }
  final k2 = byKeyword(whole);
  if (k2 != null) return k2;
  if (genre == null) return null;
  for (final c in cals) {
    if (c.genres.contains(genre.label)) return c;
  }
  for (final name in genre.calendarNames) {
    for (final c in cals) {
      if (c.name.contains(name)) return c;
    }
  }
  return null;
}
