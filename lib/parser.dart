import 'dart:math' as math;

import 'models.dart';

enum ImportType { event, shift, lecture, task }

extension ImportTypeX on ImportType {
  String get label {
    switch (this) {
      case ImportType.event:
        return '予定';
      case ImportType.shift:
        return 'シフト';
      case ImportType.lecture:
        return '授業';
      case ImportType.task:
        return 'タスク（締切）';
    }
  }

  /// 対応する既定のカレンダー id（タスクは null）
  String? get calendarId {
    switch (this) {
      case ImportType.event:
        return 'other';
      case ImportType.shift:
        return 'shift';
      case ImportType.lecture:
        return 'lecture';
      case ImportType.task:
        return null;
    }
  }
}

/// 貼り付けた文章から見つかった「予定／タスクの候補」
class Candidate {
  Candidate({
    required this.title,
    required this.date,
    required this.type,
    required this.source,
    this.startMin,
    this.endMin,
    this.url = '',
    this.note = '',
    this.place = '',
    this.calendarId = 'other',
    this.showAs = ShowAs.busy,
    this.endOffset = 0,
  });

  /// 終了が開始日の何日後か（夜勤など、日をまたぐ予定は 1）
  int endOffset;

  String title;

  /// 登録先のカレンダー（タスクのときは使わない）
  String calendarId;
  ShowAs showAs;
  DateTime date;
  ImportType type;
  int? startMin;
  int? endMin;

  /// Zoom などのリンク
  String url;

  /// 続く行から拾った補足（ミーティングID・パスコードなど）
  String note;
  String place;
  final String source;
  bool selected = true;

  /// 同じ連絡から作った予定とタスクを結びつける番号（勤務と終了報告など）
  int? linkGroup;

  /// この予定の終了時刻に、同じ番号のタスクの期限を合わせる
  bool linkEnd = false;
}

class ParseResult {
  ParseResult(this.candidates, this.skipped);
  final List<Candidate> candidates;

  /// 日付が見つからず読み飛ばした行の数
  final int skipped;
}

final _ymdRe = RegExp(
    r'(\d{4})\s*[/\-.年]\s*(\d{1,2})\s*[/\-.月]\s*(\d{1,2})\s*日?');
final _mdKanjiRe = RegExp(r'(\d{1,2})\s*月\s*(\d{1,2})\s*日');
final _mdSlashRe = RegExp(r'(?<![\d:/])(\d{1,2})/(\d{1,2})(?![\d:/])');
final _relRe = RegExp(r'明後日|明日|今日|本日');

/// 英語の日付（「Nov 20, 2026」「November 20」）
final _enDateRe = RegExp(
    r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?(?:\s+(\d{4}))?\b',
    caseSensitive: false);
const _enMonths = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

/// 「来週金曜」「今週の水曜日」「再来週月曜」
final _relWeekRe = RegExp(r'(今週|来週|再来週)\s*の?\s*([月火水木金土日])(?:曜日?)?');

/// 「3限」「3・4限」「2〜3時限」「5コマ目」
final _periodRe = RegExp(
    r'(1[0-2]|[1-9１-９])\s*(?:[・,、\-〜~～]\s*(1[0-2]|[1-9１-９])\s*)?(?:時限目?|限目?|コマ目?)');

/// 取り込み中に使う時限の時刻（parseText が設定する）
List<(int, int)> _periods = const [];

int _digit(String s) {
  if (s.length > 1) return int.parse(s); // 10〜12
  final c = s.codeUnitAt(0);
  return c >= 0xFF10 ? c - 0xFF10 : c - 0x30;
}

/// _extractTime の終了時刻を (その日の中の分, 何日後か) に分ける。
/// ちょうど 24:00 は同じ日の 23:59、24:00 を超える分は翌日
(int?, int) _splitEnd(int? end) {
  if (end == null) return (null, 0);
  if (end > 24 * 60) return (end - 24 * 60, 1);
  return (math.min(end, 23 * 60 + 59), 0);
}

/// 「正午」「午後3時」「午前9:30」を、ふつうの時刻の書き方に直す
String _plainTimeWords(String s) => s
    .replaceAll('正午', '12:00')
    // 時差の表記（Zoom の「大阪、札幌、東京」、GMT+9 など）は時刻ではない
    .replaceAll(RegExp(r'大阪、札幌、東京|[（(]?\s*(?:GMT|UTC)\s*[+＋]\s*0?9(?::?00)?\s*[)）]?|日本時間|\bJST\b'), ' ')
    // 「3:00 PM」「04:00 PM」
    .replaceAllMapped(RegExp(r'(\d{1,2})[:：](\d{2})\s*([AaPp])\.?[Mm]\.?'), (m) {
      final h = int.parse(m.group(1)!) % 12 + (m.group(3)!.toLowerCase() == 'p' ? 12 : 0);
      return '$h:${m.group(2)}';
    })
    // 「午後1:00～2:00」: 後ろの時刻も午後
    .replaceAllMapped(
        RegExp(r'午後\s*(\d{1,2})((?:\s*[:：]\s*\d{2})|\s*時(?:\s*\d{1,2}\s*分)?)\s*([〜~～\-–ー]|から)\s*(\d{1,2})(?=\s*[:：時])'),
        (m) {
      final a = int.parse(m.group(1)!) % 12 + 12;
      var b = int.parse(m.group(4)!);
      if (b < 12) b += 12;
      return '$a${m.group(2)}${m.group(3)}$b';
    })
    .replaceAllMapped(RegExp(r'午後\s*(\d{1,2})(?=\s*[:：時])'),
        (m) => '${int.parse(m.group(1)!) % 12 + 12}')
    .replaceAllMapped(RegExp(r'午前\s*(\d{1,2})(?=\s*[:：時])'),
        (m) => '${int.parse(m.group(1)!) % 12}');

const _timeTok = r'(\d{1,2})(?:[:：](\d{2})|時(?!間)(?:(\d{1,2})分?)?)';

/// 「08:12発 … 10:07着」
final _depArrRe = RegExp(r'(\d{1,2})[:：](\d{2})\s*発.{0,20}?(\d{1,2})[:：](\d{2})\s*着');

/// 「10-15」のような時だけの範囲（シフト連絡など）。日付を取り除いた残りにだけ使う
final _bareHoursRe = RegExp(r'(?<![\d/:：.])([0-2]?\d)\s*[-〜~～]\s*([0-2]?\d)(?![\d/:：.時])');

final _rangeRe =
    RegExp(_timeTok + r'\s*(?:[-〜~～–—ー]|から)\s*' + _timeTok);
final _singleRe = RegExp(_timeTok);

final _taskWords = RegExp(r'締切|締め切り|〆|提出|期限|まで');
final _shiftWords = RegExp(r'シフト|バイト|勤務|出勤');
final _lectureWords =
    RegExp(r'授業|講義|ゼミ|実験|休講|補講|試験|テスト|[0-9１-９]\s*(?:時限|限)');

/// URL の前に付きがちなラベル（「Zoom:」「URL：」など）
final _linkLabelRe = RegExp(
    r'(?:(?:zoom|teams|google\s*meet|meet|webex)\s*)?(?:url|リンク|会議URL|参加URL|参加用URL|ミーティングURL|zoom|teams|meet|webex)\s*[:：]?\s*$',
    caseSensitive: false);

/// 所要時間（「約1時間」「1時間半」「90分程度」）。開始時刻だけのときに終了時刻を決める
final _durationRe = RegExp(
    r'[（(]?\s*(?:約|およそ|所要(?:時間)?\s*[:：]?\s*)?(?:(\d{1,2})\s*時間\s*(?:(\d{1,2})\s*分|(半))?|(\d{2,3})\s*分)\s*(?:間|程度|ほど|くらい|ぐらい)?\s*[）)]?');

/// 文章の中の「面談日時」「説明会の日程」から、予定の名前（「面談」「説明会」）を拾う
final _hintRe = RegExp(r'([^\s、。「」■□◆●【】]{1,10}?)の?(?:日時|日程)(?:が|は|に|を|について|の)');
/// 挨拶などメモに入れなくてよい行
final _greetingRe = RegExp(r'^(よろしく|宜しく|お疲れ|おつかれ|お世話|以上|ありがとう)');
final _placeRe = RegExp(r'^\s*(?:場所|会場|教室|集合場所|集合|住所|所在地)\s*[:：]\s*(.+)$');

/// お店・施設の名前の見出し（予約メールの「サロン名」「店舗名」など）。予定のタイトルに使い、場所にも入れる
const _nameLabels =
    r'(?:サロン|店|店舗|お店|施設|病院|医院|クリニック|歯科|会場|ホテル|会社|教室)名?';
final _nameLabelRe = RegExp('^(?:$_nameLabels)\\s*[:：]\\s*(.+)\$');

/// 「■来店日時」「【予約内容】」「サロン名：」のように、見出しだけの行（値は次の行）
final _headingOnlyRe = RegExp(
    r'^(?:[■□◆◇●○▼▽▶★☆]\s*([^\s:：【】\[\]]{1,14})\s*[:：]?|[【\[]\s*([^】\]]{1,14})\s*[】\]]\s*[:：]?|([^\s:：【】\[\]■□◆◇●]{1,14})\s*[:：])$');

/// 「■見出し」の次の行に値がある書き方を「見出し：値」の1行にまとめる
List<String> _joinHeadingValues(List<String> lines) {
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final m = _headingOnlyRe.firstMatch(lines[i].trim());
    final label = m == null ? null : (m.group(1) ?? m.group(2) ?? m.group(3))!.trim();
    final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
    if (label != null &&
        next.isNotEmpty &&
        !_headingOnlyRe.hasMatch(next) &&
        // 次の行が「日程：〜」のように自分の見出しを持つなら、この行は段落の見出し（タイトル）
        !RegExp(r'^[^\s:：]{1,10}[:：]').hasMatch(next) &&
        !_labelRe.hasMatch(next) &&
        !_tagRe.hasMatch('【$label】')) {
      out.add('$label：$next');
      i++;
      continue;
    }
    out.add(lines[i]);
  }
  return out;
}

const _junk = r'[\s　・⋅·●■□◆◇▼▽▶►★☆○◎*＊\-–—:：,，、。/／〜~～|｜]';
final _trimHead = RegExp('^$_junk+');
final _trimTail = RegExp('$_junk+\$');

/// 「（水）」「(水曜日)」などの曜日表記
final _weekdayRe = RegExp(r'[（(]\s*[月火水木金土日](?:曜日?)?\s*[)）]');

/// 行頭の見出しラベル（「日時：」「【件名】」など）。group(1) がラベル名
final _labelRe = RegExp(
    r'^(?:[【\[〈<（(]\s*)?([^\s:：【】\[\]〈〉<>（）()]{1,6}(?:日時|日程)|時刻|開始時刻|時間帯|お届け時間|件名|トピック|タイトル|題名|内容|用件|日時|日程|日付|時間|開催日時?|実施日時?|期日|期限|提出期限|提出締切|締切|締め切り|〆切|イベント名?|科目名?|講義名?|授業名?|シフト|勤務)\s*(?:[】\]〉>）)]\s*[:：]?|[:：])\s*');

/// タイトルとして使えるラベル行（「件名: 〜」「内容：〜」）
final _titleLabelRe = RegExp(
    r'^(?:[【\[〈<（(]\s*)?(?:件名|タイトル|題名|内容|用件|トピック|[Tt]opic|議題|会議名|ミーティング名|イベント名?|科目名?|講義名?|授業名?)\s*(?:[】\]〉>）)]\s*[:：]?|[:：])\s*(.+)$');

/// メモ向きの行（ミーティングID・パスコード・持ち物など）
final _noteLineRe = RegExp(
    r'^(?:[※＊*]|.*(?:ID|ＩＤ|[Ii][Dd]\s*[:：]|パスコード|パスワード|[Pp]asscode|[Pp]assword|持ち物|備考|注意|服装))');

/// 件名の前に付く【重要】などのタグ
final _tagRe = RegExp(
    r'[【\[](?:重要|至急|再送|再掲|訂正|変更|お知らせ|ご案内|連絡|案内|リマインド|リマインダー|reminder|日程変更)[】\]]',
    caseSensitive: false);

/// 文頭に残りやすい助詞（「11/20までに提出」→「までに」）
final _headParticleRe = RegExp(r'^(?:まで(?:に)?|から|より|頃|ごろ|に|は|の|で|を|が)\s*');

/// 文末の丁寧表現（「提出してください」→「提出」）
final _politeTailRe = RegExp(
    r'(?:を|が|は)?(?:行います|おこないます|実施します|実施いたします|開催します|開催いたします|あります|ございます|いたします|致します|します|してください|して下さい|をお願いします|お願いします|お願い致します|お願いいたします|となります|になります|です|ます|ください|下さい)$');
final _tailParticleRe = RegExp(r'(?:を|が|は|に|の)$');

/// 案内文の定型の語尾（「〜のご案内」）
final _noticeTailRe =
    RegExp(r'(?:のご案内|のお知らせ|について|に関して|の件|のお願い|のご連絡|ご案内|お知らせ)$');

/// タイトルとしては情報が少ない語
final _genericRe = RegExp(
    r'^(?:締切|締め切り|〆切|提出|期限|予定|開始|集合|日程|日時|開催|実施|当日|ご?予約|ご?予約内容|ご?予約確認|ご?来店|ご案内|お知らせ|リマインド|確認|詳細)$');

/// 「みなと歯科クリニックです。」のような名乗りの文から、送り主（店・病院など）の名前を拾う
final _orgHintRe = RegExp(
    r'^(?:こちらは)?\s*([^\s、。「」]{2,24}?(?:歯科|クリニック|病院|医院|サロン|美容室|美容院|整骨院|接骨院|眼科|皮膚科|内科|薬局|店|ホテル|事務局|センター))(?:です|でございます)');

/// 本文の一文（見出しとしては使わない）
final _sentenceRe = RegExp(r'(?:ます|です|ください|下さい|でしょう)[。.!！]?$|。$');

/// 文字列をタイトル向けに整える。返り値の label は取り除いた見出しラベル
({String title, String label}) _cleanTitle(String s) {
  var t = s.replaceAll(RegExp(r'[\s　]+'), ' ').trim();
  t = t.replaceAll(_weekdayRe, ' ');
  t = t.replaceAll(_tagRe, ' ');
  t = t.replaceAll(_trimHead, '');
  var label = '';
  final m = _labelRe.firstMatch(t);
  if (m != null) {
    label = m.group(1)!;
    t = t.substring(m.end);
  }
  t = t.replaceAll(_linkLabelRe, '');
  for (var i = 0; i < 2; i++) {
    t = t.replaceAll(_trimHead, '').replaceAll(_trimTail, '');
    t = t.replaceFirst(_headParticleRe, '');
    t = t.replaceFirst(_politeTailRe, '');
    t = t.replaceFirst(_noticeTailRe, '');
    t = t.replaceFirst(_tailParticleRe, '');
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  // 対応の取れていない括弧だけが残った場合は外す
  if (RegExp(r'^[（(【\[]').hasMatch(t) && !RegExp(r'[)）】\]]').hasMatch(t)) {
    t = t.substring(1).trim();
  }
  if (RegExp(r'[)）】\]]$').hasMatch(t) && !RegExp(r'[（(【\[]').hasMatch(t)) {
    t = t.substring(0, t.length - 1).trim();
  }
  return (title: t, label: label);
}

/// 見出し行として使えるならタイトル候補を返す
String? _asHeading(String line) {
  if (_sentenceRe.hasMatch(line) || _greetingRe.hasMatch(line)) return null;
  final tm = _titleLabelRe.firstMatch(line);
  final t = _cleanTitle(tm != null ? tm.group(1)! : line).title;
  if (t.isEmpty || t.length > 30 || _genericRe.hasMatch(t)) return null;
  return t;
}

/// 補足行から時刻を拾う（日付の行に時刻がなかったとき用）
({int? start, int? end, String rest}) _extractTime(String src) {
  final s = _plainTimeWords(src);
  // 「新横浜 08:12発 → 京都 10:07着」
  final da = _depArrRe.firstMatch(s);
  if (da != null) {
    final a = int.parse(da.group(1)!) * 60 + int.parse(da.group(2)!);
    final b = int.parse(da.group(3)!) * 60 + int.parse(da.group(4)!);
    if (a < 24 * 60 && b < 24 * 60) {
      return (start: a, end: b > a ? b : b + 24 * 60, rest: s.replaceRange(da.start, da.end, ' '));
    }
  }
  final r = _rangeRe.firstMatch(s);
  if (r != null) {
    final a = _toMin(r, 1, 2, 3);
    var b = _toMin(r, 4, 5, 6);
    if (a != null && b != null) {
      if (b <= a) {
        // 「22:00〜5:00」のように夜に始まり朝までに終わるなら、翌日に終わる予定。
        // 24:00 を足した値で返す（受け取る側で「翌日」に直す）。それ以外は終了時刻なし
        b = a >= 12 * 60 && b <= 12 * 60 ? b + 24 * 60 : null;
      }
      return (start: a, end: b, rest: s.replaceRange(r.start, r.end, ' '));
    }
  }
  final m = _singleRe.firstMatch(s);
  if (m != null) {
    final v = _toMin(m, 1, 2, 3);
    if (v != null) {
      return (start: v, end: null, rest: s.replaceRange(m.start, m.end, ' '));
    }
  }
  // 時刻がなければ時限（「3限」「3・4限」）から決める
  final p = _periodRe.firstMatch(s);
  if (p != null && _periods.isNotEmpty) {
    final a = _digit(p.group(1)!);
    final b = p.group(2) == null ? a : _digit(p.group(2)!);
    if (a <= b && b <= _periods.length) {
      return (
        start: _periods[a - 1].$1,
        end: _periods[b - 1].$2,
        rest: s.replaceRange(p.start, p.end, ' '),
      );
    }
  }
  return (start: null, end: null, rest: s);
}

int? _toMin(Match m, int hourGroup, int minGroupA, int minGroupB) {
  final h = int.parse(m.group(hourGroup)!);
  final mi =
      int.tryParse(m.group(minGroupA) ?? m.group(minGroupB) ?? '') ?? 0;
  if (h == 24 && mi == 0) return 24 * 60; // 24:00（その日の終わり）
  if (h > 23 || mi > 59) return null;
  return h * 60 + mi;
}

DateTime? _validDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  if (dt.month != m) return null; // 2/31 などを除外
  return dt;
}

/// 1行から日付を1つ取り出し、その部分を除いた文字列を返す
({DateTime date, String rest})? _extractDate(String s, DateTime today) {
  var m = _ymdRe.firstMatch(s);
  if (m != null) {
    final dt = _validDate(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
    if (dt != null) {
      return (date: dt, rest: s.replaceRange(m.start, m.end, ' '));
    }
  }

  DateTime withYear(int mo, int d) {
    var dt = _validDate(today.year, mo, d);
    if (dt == null) return DateTime(0);
    // 半年以上前の日付は来年のものとみなす
    if (dt.isBefore(today.subtract(Duration(days: 180)))) {
      dt = _validDate(today.year + 1, mo, d) ?? dt;
    }
    return dt;
  }

  for (final re in [_mdKanjiRe, _mdSlashRe]) {
    m = re.firstMatch(s);
    if (m != null) {
      final dt = withYear(int.parse(m.group(1)!), int.parse(m.group(2)!));
      if (dt.year != 0) {
        return (date: dt, rest: s.replaceRange(m.start, m.end, ' '));
      }
    }
  }

  m = _enDateRe.firstMatch(s);
  if (m != null) {
    final mo = _enMonths.indexOf(m.group(1)!.toLowerCase().substring(0, 3)) + 1;
    final d = int.parse(m.group(2)!);
    final dt = m.group(3) != null
        ? _validDate(int.parse(m.group(3)!), mo, d)
        : withYear(mo, d);
    if (dt != null && dt.year != 0) {
      return (date: dt, rest: s.replaceRange(m.start, m.end, ' '));
    }
  }

  m = _relWeekRe.firstMatch(s);
  if (m != null) {
    final weeks = const {'今週': 0, '来週': 1, '再来週': 2}[m.group(1)!]!;
    // 週の始まり（日曜）からの日数
    final wd = '日月火水木金土'.indexOf(m.group(2)!);
    final offset = weekStartsOnSunday ? wd : (wd + 6) % 7;
    final dt = addDays(startOfWeek(today), weeks * 7 + offset);
    return (date: dt, rest: s.replaceRange(m.start, m.end, ' '));
  }

  m = _relRe.firstMatch(s);
  if (m != null) {
    final word = m.group(0)!;
    final add = word == '明後日' ? 2 : (word == '明日' ? 1 : 0);
    final dt = DateTime(today.year, today.month, today.day + add);
    return (date: dt, rest: s.replaceRange(m.start, m.end, ' '));
  }
  return null;
}

final _tentativeRe = RegExp(r'[（(]仮[)）]|仮予約|仮押さえ|仮決定|未定|調整中|予備日');
final _awayRe = RegExp(r'有給|有休|欠勤|お休み|休暇|不在|外出');
final _elsewhereRe = RegExp(r'在宅|リモート勤務|テレワーク');

/// [calendars] を渡すと、行にカレンダー名（「部活」「病院」など）が含まれる場合にそのカレンダーを選ぶ
// ---- 勤務連絡（作業日・作業時間・現場名…の書式） ----

final _workDayRe = RegExp(r'作業日\s*[:：]\s*(\d{4})[/年-](\d{1,2})[/月-](\d{1,2})');
final _workTimeRe = RegExp(
    r'作業時間\s*[:：]\s*(\d{1,2})[:：](\d{2})\s*[-〜~～–ー]\s*(\d{1,2})[:：](\d{2})(?:\s*[（(]\s*休憩\s*([0-9:：]+)\s*[)）])?');
const _fieldStop = r'(?=\s+(?:作業時間|現場名|現場住所|作業内容|時給|連絡事項)|\n|$)';
final _siteRe = RegExp('現場名\\s*[:：]\\s*(.+?)$_fieldStop');
final _addrRe = RegExp('現場住所\\s*[:：]\\s*(.+?)$_fieldStop');
final _jobRe = RegExp('作業内容\\s*[:：]\\s*(.+?)$_fieldStop');

/// 「作業日: / 作業時間: / 現場名: / 現場住所: / 作業内容:」の書式の勤務連絡を読む。
/// 夜勤（日付をまたぐ）は翌日に終わる1つの予定にし、終了時刻に「終了報告」のタスクも作る。
List<Candidate> _parseWorkNotices(List<String> lines, Set<int> consumed,
    List<CalendarDef> cals, String whole) {
  final out = <Candidate>[];
  // 勤務先の名前（タイトルの頭に付ける）
  final company = RegExp(r'ユニティー|unity', caseSensitive: false).hasMatch(whole)
      ? 'ユニティー'
      : '';
  // 「ユニティー」「労働」「バイト」という名前のカレンダーがあればそれを使う
  final calId = (cals.where((c) => ['ユニティー', '労働', 'バイト', 'シフト']
              .any((n) => c.name.contains(n)))
          .map((c) => c.id)
          .firstOrNull) ??
      (cals.any((c) => c.id == 'shift') ? 'shift' : cals.first.id);

  // 返信メールの引用などで同じ通知が何度も出てくるので、同じ勤務は1回だけにする
  final seen = <String>{};
  var group = 0;
  for (var i = 0; i < lines.length; i++) {
    final dm = _workDayRe.firstMatch(lines[i]);
    if (dm == null) continue;
    // 作業日の行から、次の作業日の行の手前まで（最大8行）を1件として読む
    final idx = <int>[i];
    for (var j = i + 1; j < lines.length && j <= i + 8; j++) {
      if (_workDayRe.hasMatch(lines[j])) break;
      idx.add(j);
    }
    final block = idx.map((k) => lines[k].trim()).join('\n');
    final tm = _workTimeRe.firstMatch(block);
    if (tm == null) continue;

    final date = DateTime(int.parse(dm.group(1)!), int.parse(dm.group(2)!),
        int.parse(dm.group(3)!));
    final start = int.parse(tm.group(1)!) * 60 + int.parse(tm.group(2)!);
    var end = int.parse(tm.group(3)!) * 60 + int.parse(tm.group(4)!);
    final site = _siteRe.firstMatch(block)?.group(1)?.trim() ?? '';
    final addr = _addrRe.firstMatch(block)?.group(1)?.trim() ?? '';
    final job = _jobRe.firstMatch(block)?.group(1)?.trim() ?? '';
    final rest = tm.group(5);
    final title = [company, site.isEmpty ? '勤務' : site]
        .where((x) => x.isNotEmpty)
        .join(' ');
    final note = [
      if (job.isNotEmpty) '作業内容: $job',
      if (rest != null) '休憩: $rest',
    ].join('\n');
    final source = lines[i].trim();

    // 使った行は、通常の解析では読まない（重複の勤務でも読み飛ばす）
    for (final k in idx) {
      final l = lines[k];
      if (l.contains(RegExp(r'作業日|作業時間|現場名|現場住所|作業内容'))) {
        consumed.add(k);
      }
    }

    if (!seen.add('${date.toIso8601String()} $start $end $site')) continue;

    group++;
    // 夜勤（終了が開始以前）は、翌日に終わる1つの予定にする
    final overnight = end <= start;
    final endDate = overnight ? date.add(const Duration(days: 1)) : date;
    out.add(Candidate(
      title: title,
      date: date,
      type: ImportType.shift,
      source: source,
      startMin: start,
      endMin: end,
      endOffset: overnight ? 1 : 0,
      place: addr,
      note: note,
      calendarId: calId,
    ));
    // 追加した勤務の終了時刻に、終了報告を結びつける
    for (final c in out.reversed) {
      if (c.type == ImportType.shift) {
        c.linkGroup = group;
        c.linkEnd = true;
        break;
      }
    }
    for (final c in out.where((c) => c.type == ImportType.shift && c.linkGroup == null)) {
      c.linkGroup = group;
    }
    out.add(Candidate(
      title: '終了報告（${site.isEmpty ? fmtDate(date) : site}）',
      date: endDate,
      type: ImportType.task,
      source: source,
      startMin: end,
      note: '作業が終わったら終了報告を送る',
    )..linkGroup = group);
  }
  return out;
}

/// Markdown のリンク「[文字](URL)」
final _mdLinkRe = RegExp(r'\[([^\]]+)\]\((https?://[^)\s]+)\)');

/// 時刻だけの行（「23:59」）
final _timeOnlyRe = RegExp(r'^\s*(\d{1,2})[:：](\d{2})\s*$');

/// Moodle の画面をコピーすると入る、アイコンの代替テキストだけの行
final _moodleIconRe = RegExp(
    r'^(?:(?:活動|アクティビティ|コース|サイト|ユーザ|ユーザー|グループ|カテゴリ)\s*イベント|(?:Activity|Course|Site|User|Group|Category) event)$',
    caseSensitive: false);

/// Moodle のタイムライン（直近の課題・小テストの一覧）を読む。
///
/// ```
/// 2026年 11月 15日(日曜日)        ← 日付だけの行
/// 23:59                           ← 時刻だけの行
/// 活動イベント                    ← アイコンの代替テキスト（あれば飛ばす）
/// 第6週課題 https://moodle…       ← 課題名（リンク）
/// 「課題」の提出期限 · 2026理-環境統計基礎-大木真人-月3・4-秋
/// ```
/// 同じ日付の下に「時刻・課題名・説明」が何件も続く形にも対応する。
/// 課題名は科目をまたいで重なりやすい（「第6週課題」など）ので、科目名を添える
List<Candidate> _parseMoodle(List<String> lines, Set<int> consumed, DateTime today) {
  final out = <Candidate>[];
  int? nextLine(int i) {
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    return i < lines.length && !consumed.contains(i) ? i : null;
  }

  for (var i = 0; i < lines.length; i++) {
    if (consumed.contains(i)) continue;
    final head = lines[i].trim();
    if (head.isEmpty) continue;
    final d = _extractDate(head, today);
    if (d == null) continue;
    // 日付（と曜日・時刻）だけの行か
    var rest = d.rest.replaceAll(_weekdayRe, ' ').replaceAll(RegExp(r'[,、\s]'), '');
    int? headTime;
    final ht = _timeOnlyRe.firstMatch(rest);
    if (ht != null) {
      headTime = int.parse(ht.group(1)!) * 60 + int.parse(ht.group(2)!);
      rest = '';
    }
    if (rest.isNotEmpty) continue;

    var j = i + 1;
    var found = 0;
    while (true) {
      final used = <int>[];
      var k = nextLine(j);
      if (k == null) break;
      int? time;
      final tm = _timeOnlyRe.firstMatch(lines[k]);
      if (tm != null) {
        time = int.parse(tm.group(1)!) * 60 + int.parse(tm.group(2)!);
        used.add(k);
        k = nextLine(k + 1);
        if (k == null) break;
      } else if (found == 0 && headTime != null) {
        time = headTime;
      } else {
        break; // 時刻だけの行が続かなければ、この形ではない
      }
      if (time > 24 * 60) break;

      // コピーすると混ざる、アイコンの代替テキスト（「活動イベント」など）は飛ばす
      if (_moodleIconRe.hasMatch(lines[k].trim())) {
        used.add(k);
        k = nextLine(k + 1);
        if (k == null) break;
      }

      // 課題名の行
      final tl = lines[k].trim();
      if (_timeOnlyRe.hasMatch(tl) || _extractDate(tl, today) != null) break;
      final url = urlPattern.firstMatch(tl)?.group(0) ?? '';
      var title = tl.replaceAll(urlPattern, ' ').trim();
      if (title.isEmpty) break;
      used.add(k);

      // 説明の行（「「課題」の提出期限 · 科目名」）
      var desc = '';
      final n = nextLine(k + 1);
      if (n != null &&
          !_timeOnlyRe.hasMatch(lines[n]) &&
          RegExp(r'·|期限|締切|終了|開始').hasMatch(lines[n]) &&
          _extractDate(lines[n], today) == null) {
        desc = lines[n].trim();
        used.add(n);
      }
      // 説明の行（「〜の提出期限 · 科目名」など）が無ければ Moodle の形ではない
      // （予約メールの「日時の行 → 店名の行」などを課題と取り違えないため）
      if (desc.isEmpty) break;
      // 科目名: 「2026理-環境統計基礎-大木真人-月3・4-秋」の2つ目
      final course = desc.contains('·') ? desc.split('·').last.trim() : '';
      final segs = course.split(RegExp(r'[-‐－]'));
      if (segs.length >= 2 && RegExp(r'^\d{4}').hasMatch(segs[0]) && segs[1].trim().isNotEmpty) {
        title = '$title（${segs[1].trim()}）';
      } else if (course.isNotEmpty) {
        title = '$title（$course）';
      }
      // 「開始」だけの通知（小テストの公開など）は予定、それ以外は締め切り
      final opens = desc.contains('開始') && !RegExp(r'期限|締切|終了').hasMatch(desc);
      out.add(Candidate(
        title: title,
        date: d.date,
        type: opens ? ImportType.event : ImportType.task,
        source: [head, for (final u in used) lines[u].trim()].join(' / '),
        startMin: time,
        url: url,
        note: desc,
      ));
      consumed.addAll(used);
      found++;
      j = used.last + 1;
    }
    if (found > 0) consumed.add(i);
  }
  return out;
}

/// [periods] は時限の時刻（「3限」を時刻に直すのに使う）
ParseResult parseText(String text, DateTime now,
    {List<CalendarDef>? calendars, List<(int, int)>? periods}) {
  _periods = periods ?? const [];
  final cals = calendars ?? defaultCalendars();
  // 長い名前から順に照合する（「試験」より「追試験」を優先）
  final byName = [...cals]..sort((a, b) => b.name.length.compareTo(a.name.length));
  final today = dateOnly(now);
  final out = <Candidate>[];
  var skipped = 0;

  // 直前の候補に続く行（空行で区切られるまで）は、その候補の補足として扱う
  Candidate? open;
  // タイトルが取れなかった候補（続く行からタイトルを補う）
  Candidate? needsTitle;
  // 見出し行・件名（タイトルが取れない日付行に使う）
  String? heading;
  String? subject;
  // 見出しからタイトルを借りた候補（続く「内容：」行があればそちらを優先）
  Candidate? fromHeading;

  // 勤務連絡（ユニティーの「労働条件通知」など）は決まった書式なので先に読み取る
  // Markdown のリンク「[文字](URL)」は「文字 URL」に直してから読む
  final lines = _joinHeadingValues([
    for (final l in text.split(RegExp(r'\r?\n')))
      l.replaceAllMapped(_mdLinkRe, (m) => '${m.group(1)} ${m.group(2)}'),
  ]);
  final consumed = <int>{};
  out.addAll(_parseWorkNotices(lines, consumed, cals, text));
  // Moodle のタイムライン（課題の提出期限など）
  out.addAll(_parseMoodle(lines, consumed, today));

  // 段落の前置きの文（種類の手がかり）
  var context = '';
  // 空行の直前に作った候補（会議のリンクなど、空行をはさんだ補足を受け付ける）
  Candidate? afterBlank;
  for (var li = 0; li < lines.length; li++) {
    if (consumed.contains(li)) continue;
    final rawLine = lines[li];
    final line = rawLine.trim();
    if (line.isEmpty) {
      // 予定を含む段落が終わったら、その見出しは次の段落に持ち越さない
      if (open != null) {
        heading = null;
        context = '';
        // 空行のあとでも、会議のリンク・ID・パスコードの行ならその予定に付ける（Zoom の招待文など）
        afterBlank = open;
      }
      open = null;
      needsTitle = null;
      fromHeading = null;
      continue;
    }

    // URL は日付・時刻の誤検出を避けるため先に取り除く
    final urls = [for (final m in urlPattern.allMatches(line)) m.group(0)!];
    final body = line.replaceAll(urlPattern, ' ').trim();

    final d = _extractDate(body, today);
    if (d == null && open == null && afterBlank != null) {
      final prev = afterBlank;
      if (urls.isNotEmpty && prev.url.isEmpty && isMeetingLink(urls.first)) {
        prev.url = urls.first;
        continue;
      }
      if (_noteLineRe.hasMatch(line) && !_sentenceRe.hasMatch(line)) {
        prev.note = _addLine(prev.note, line);
        continue;
      }
      // 「Zoomミーティングに参加する」などの案内の見出しは読み飛ばす
      if (RegExp(r'(?:ミーティング|会議|Zoom|Teams|Meet).{0,10}参加|参加する$|[Jj]oin')
          .hasMatch(line)) {
        continue;
      }
    }
    if (d != null) afterBlank = null;
    if (d == null) {
      final target = open;
      if (target == null) {
        skipped++;
        if (urls.isEmpty) {
          final h = _asHeading(body);
          // 見出しにならない文でも「面談日時が近づいて…」なら「面談」を名前の候補にする
          final hint = h == null && heading == null
              ? (_hintRe.firstMatch(body)?.group(1) ?? _orgHintRe.firstMatch(body)?.group(1))
              : null;
          if (hint != null && !_genericRe.hasMatch(hint)) heading = hint;
          // 段落の前置き（「来週のシフトです」など）は、種類の手がかりに使う
          context = '$context $body';
          if (h != null) {
            heading = h;
            if (RegExp(r'^(?:件名|subject)', caseSensitive: false)
                .hasMatch(body)) {
              subject = h;
            }
          }
        }
        continue;
      }
      // 補足行: リンク・場所・タイトル・メモに振り分ける
      if (urls.isNotEmpty && target.url.isEmpty) {
        target.url = urls.first;
        final restUrls = urls.skip(1).join(' ');
        // 「■Zoom URL：」のような見出しだけならメモに残さない
        final label = body
            .replaceAll(_linkLabelRe, '')
            .replaceAll(_trimHead, '')
            .replaceAll(_trimTail, '')
            .trim();
        final extra = [label, restUrls].where((x) => x.isNotEmpty).join(' ');
        if (extra.isNotEmpty) target.note = _addLine(target.note, extra);
        continue;
      }
      if (_greetingRe.hasMatch(line)) continue;
      // 「時間帯：14時～16時」「新横浜 08:12発 → 京都 10:07着」: 時刻がまだなければ入れる
      if (target.startMin == null && needsTitle != target && !_sentenceRe.hasMatch(line)) {
        final tt = _extractTime(body);
        if (tt.start != null) {
          target.startMin = tt.start;
          if (target.type != ImportType.task) {
            final (e, off) = _splitEnd(tt.end);
            target.endMin = e;
            target.endOffset = off;
          }
          final restText = _cleanTitle(tt.rest).title;
          if (restText.isNotEmpty) target.note = _addLine(target.note, line);
          continue;
        }
      }
      final p = _placeRe.firstMatch(line);
      if (p != null && target.place.isEmpty) {
        target.place = p.group(1)!.trim();
        continue;
      }
      // 「サロン名：〜」「店舗名：〜」: タイトルがまだ弱ければ店名をタイトルに、場所にも入れる
      final nm = _nameLabelRe.firstMatch(line.replaceAll(_trimHead, ''));
      if (nm != null) {
        final name = nm.group(1)!.trim();
        if (needsTitle == target || fromHeading == target) {
          final prefix = target.title;
          target.title = prefix.isEmpty || prefix == name ? name : '$name（$prefix）';
          needsTitle = null;
          fromHeading = null;
        }
        if (target.place.isEmpty) target.place = name;
        continue;
      }
      final tl = _titleLabelRe.firstMatch(line);
      if (tl != null && fromHeading == target) {
        final c = _cleanTitle(tl.group(1)!).title;
        if (c.isNotEmpty) {
          target.title = c;
          fromHeading = null;
          continue;
        }
      }
      if (needsTitle == target && !_noteLineRe.hasMatch(line)) {
        var src = tl != null ? tl.group(1)! : body;
        if (target.startMin == null) {
          final t = _extractTime(src);
          if (t.start != null) {
            target.startMin = t.start;
            if (target.type != ImportType.task) {
              final (e, off) = _splitEnd(t.end);
              target.endMin = e;
              target.endOffset = off;
            }
            src = t.rest;
          }
        }
        final c = _cleanTitle(src).title;
        if (c.isNotEmpty && !_sentenceRe.hasMatch(src.trim())) {
          target.title = c;
          needsTitle = null;
          continue;
        }
      }
      target.note = _addLine(target.note, line);
      continue;
    }

    var rest = d.rest.replaceAll(_weekdayRe, ' ');
    // 「12月1日(火)〜12月3日(木)」: 数日にわたる予定
    var spanDays = 0;
    for (final sep in RegExp(r'[〜~～–ー]\s*(?=\d)').allMatches(rest)) {
      final d2 = _extractDate(rest.substring(sep.end), today);
      // 区切りのすぐ後ろが日付のときだけ
      if (d2 == null || !d2.rest.startsWith(' ')) continue;
      final diff = (d2.date.difference(d.date).inHours / 24).round();
      if (diff >= 1 && diff <= 60) {
        spanDays = diff;
        rest = '${rest.substring(0, sep.start)} ${d2.rest.replaceAll(_weekdayRe, ' ')}';
      }
      break;
    }
    final t = _extractTime(rest);
    rest = t.rest;
    var start = t.start;
    var end = t.end;
    // 「11/18(水) 10-15」のような時だけの範囲
    if (start == null) {
      final bh = _bareHoursRe.firstMatch(rest);
      if (bh != null) {
        final a = int.parse(bh.group(1)!), b = int.parse(bh.group(2)!);
        if (a >= 5 && a < b && b <= 24) {
          start = a * 60;
          end = b * 60;
          rest = rest.replaceRange(bh.start, bh.end, ' ');
        }
      }
    }
    // 「10:00〜 約1時間」: 所要時間から終了時刻を決め、タイトルからは外す
    if (start != null) {
      final du = _durationRe.firstMatch(rest);
      if (du != null) {
        final mins = du.group(4) != null
            ? int.parse(du.group(4)!)
            : int.parse(du.group(1)!) * 60 +
                (du.group(3) != null ? 30 : int.tryParse(du.group(2) ?? '') ?? 0);
        if (mins > 0 && mins <= 24 * 60) {
          end ??= start + mins;
          rest = rest.replaceRange(du.start, du.end, ' ');
        }
      }
    }

    final cleaned = _cleanTitle(rest);
    var title = cleaned.title;
    var weak = title.isEmpty || _genericRe.hasMatch(title);
    var borrowed = false;
    if (weak) {
      final h = heading ?? subject;
      if (h != null) {
        // 「提出」など短い語だけ残った場合は見出しと組み合わせる
        title = title.isEmpty || h.contains(title) ? h : '$h $title';
        weak = false;
        borrowed = true;
      } else if (title.isEmpty && cleaned.label.isNotEmpty &&
          !RegExp(r'^(?:日時|日程|日付|時間|開催日|実施日)').hasMatch(cleaned.label)) {
        // 「提出期限」など。「来店日時」「予約日時」は「来店」「予約」にする
        title = cleaned.label.replaceFirst(RegExp(r'(?:日時|日程)$'), '');
      }
    }

    final kindText = '$line $title';
    // 前置きの文（「来週のシフトです」）も種類の手がかりにする
    final ctxText = '$kindText $context';
    // 「10時から正午まで」の「まで」は時間の範囲。締め切りの「まで」とは分ける
    final taskHit = _taskWords
        .allMatches(kindText)
        .any((m) => m.group(0) != 'まで' || end == null);
    // シフト連絡の「休み」の日は予定にしない
    if (start == null &&
        _shiftWords.hasMatch(ctxText) &&
        RegExp(r'休み|休日|^OFF$|オフ').hasMatch(_cleanTitle(rest).title)) {
      skipped++;
      continue;
    }
    ImportType type;
    if (taskHit) {
      type = ImportType.task;
    } else if (_shiftWords.hasMatch(kindText) ||
        (!_lectureWords.hasMatch(kindText) && _shiftWords.hasMatch(context))) {
      type = ImportType.shift;
    } else if (_lectureWords.hasMatch(kindText)) {
      type = ImportType.lecture;
    } else {
      type = ImportType.event;
    }

    var calId = type.calendarId ?? 'other';
    for (final cal in byName) {
      if (cal.name.trim().isNotEmpty && kindText.contains(cal.name.trim())) {
        calId = cal.id;
        break;
      }
    }
    if (!cals.any((x) => x.id == calId)) calId = cals.first.id;
    final showAs = _tentativeRe.hasMatch(line)
        ? ShowAs.tentative
        : _awayRe.hasMatch(line)
            ? ShowAs.away
            : _elsewhereRe.hasMatch(line)
                ? ShowAs.workingElsewhere
                : ShowAs.busy;

    if (showAs == ShowAs.tentative) {
      title = title.replaceAll(RegExp(r'[（(]仮[)）]'), '').trim();
    }

    // シフト連絡の行（「11/16(月) 17:00-22:00」）は名前が無いので「シフト」
    if (title.isEmpty && type == ImportType.shift) title = 'シフト';

    final c = Candidate(
      calendarId: calId,
      showAs: showAs,
      title: title,
      date: d.date,
      type: type,
      source: line,
      // 24:00 は締め切りなら「その日いっぱい」、予定なら 23:59 として扱う
      startMin: type == ImportType.task || start == null
          ? start
          : math.min(start, 23 * 60 + 59),
      endMin: type == ImportType.task ? null : _splitEnd(end).$1,
      endOffset: type == ImportType.task
          ? 0
          : (spanDays > 0 ? spanDays : _splitEnd(end).$2),
      url: urls.isEmpty ? '' : urls.first,
      note: urls.length > 1 ? urls.skip(1).join('\n') : '',
    );
    out.add(c);
    open = c;
    needsTitle = weak ? c : null;
    fromHeading = borrowed ? c : null;
  }
  // 締め切りは終日が基本（0:00 は前日、23:59 はその日の終日。ほかの時刻は残す）
  for (final c in out) {
    if (c.type != ImportType.task || c.linkGroup != null) continue;
    final (d, m) = normalizeDeadline(c.date, c.startMin);
    c.date = d;
    c.startMin = m;
  }
  return ParseResult(out, skipped);
}

String _addLine(String base, String line) =>
    base.isEmpty ? line : '$base\n$line';

/// 候補の終了時刻の既定値（開始+60分、23:59 まで）
int defaultEnd(int startMin) => math.min(startMin + 60, 23 * 60 + 59);
