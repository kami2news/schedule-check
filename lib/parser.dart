import 'dart:math' as math;

import 'genre.dart';
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

  /// 読み取りに自信がないときの注意（この候補は最初はチェックしない）
  String? warning;

  /// 補足（「23:59 締切 → 終日として登録」など）
  String? hint;

  /// 同じ連絡から作った予定とタスクを結びつける番号（勤務と終了報告など）
  int? linkGroup;

  /// この予定の終了時刻に、同じ番号のタスクの期限を合わせる
  bool linkEnd = false;

  /// 系統（「就活」「病院」など。genre.dart）。判断できなければ null
  String? genre;

  /// 読み取り時に選んだカレンダー（取り込み画面で変えたら、系統の振り分けを覚える）
  String? suggestedCalendarId;

  /// 同じ内容でほかにも行う日（「2月9日（火）・10日（水）・12日（金）」の 10日・12日）。
  /// 読み終わったあと、日付だけを変えた候補に分ける
  List<DateTime> alsoOn = [];

  /// 時限の範囲が昼休みなどをはさむとき、2 つ目以降のまとまり（通しの分の開始・終了）。
  /// 読み終わったあと、時刻だけを変えた候補に分ける
  List<(int, int)> splitRest = [];

  Candidate copyOn(DateTime d) => Candidate(
        title: title,
        date: d,
        type: type,
        source: source,
        startMin: startMin,
        endMin: endMin,
        url: url,
        note: note,
        place: place,
        calendarId: calendarId,
        showAs: showAs,
        endOffset: endOffset,
      )
        ..selected = selected
        ..warning = warning
        ..hint = hint
        ..genre = genre
        ..suggestedCalendarId = suggestedCalendarId
        ..splitRest = [...splitRest];
}

class ParseResult {
  ParseResult(this.candidates, this.skipped, [this.unreadable = const []]);
  final List<Candidate> candidates;

  /// 日付らしいが読み取れなかった行（「2026/02/30」など）。前の予定のメモには入れない
  final List<String> unreadable;

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
/// 「1限～10限」のように、区切りの前にも「限」が付く形も読む
final _periodRe = RegExp(
    r'(1[0-2]|[1-9１-９])\s*((?:時限|限|コマ)目?\s*)?(?:([・,、\-〜~～])\s*(1[0-2]|[1-9１-９])\s*)?(?:時限目?|限目?|コマ目?)');

/// 取り込み中に使う時限の時刻（parseText が設定する）
List<(int, int)> _periods = const [];

/// 直前の _extractTime が時限から時刻を決め、その範囲が昼休みなどをはさんだときの 2 つ目以降のまとまり
List<(int, int)> _lastSplit = const [];

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
    // 「9:00--18:00」のような続いた区切り
    .replaceAllMapped(RegExp(r'(\d)\s*([-〜~～－])[-〜~～－]+\s*(?=\d)'), (m) => '${m.group(1)}${m.group(2)}')
    // 「午前中」: 配達は 8〜12 時、それ以外は 9〜12 時
    .replaceAll(RegExp(r'午前中'),
        RegExp(r'お届け|配達|配送|宅配').hasMatch(s) ? ' 8:00〜12:00 ' : ' 9:00〜12:00 ')
    // 「10時半」→「10:30」
    .replaceAllMapped(RegExp(r'(\d{1,2})\s*時\s*半'), (m) => '${m.group(1)}:30')
    // 「22:00-翌6:00」: 「翌」は取り除く（夜に始まり朝に終わる範囲として読む）
    .replaceAllMapped(RegExp(r'([-〜~～–ー]\s*)翌\s*(?=\d)'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'Osaka,\s*Sapporo,\s*Tokyo'), ' ')
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
        (m) => '${int.parse(m.group(1)!) % 12}')
    // 「AM 10:00」「PM 3:00」（前に付く形）
    .replaceAllMapped(RegExp(r'\b([AaPp])\.?[Mm]\.?\s*(\d{1,2})(?=\s*[:：時])'), (m) {
      final h = int.parse(m.group(2)!) % 12 + (m.group(1)!.toLowerCase() == 'p' ? 12 : 0);
      return '$h';
    })
    // 「夜8時」「夕方5時」: 午後の時刻
    .replaceAllMapped(RegExp(r'(?:夜|晩|夕方|夕)\s*(\d{1,2})(?=\s*[:：時])'), (m) {
      final h = int.parse(m.group(1)!);
      return h >= 1 && h <= 11 ? '${h + 12}' : '$h';
    })
    .replaceAll(RegExp(r'朝\s*(?=\d{1,2}\s*[:：時])'), '');

const _timeTok = r'(\d{1,2})(?:[:：](\d{2})|時(?!間)(?:(\d{1,2})分?)?)';

/// 「08:12発 … 10:07着」
final _depArrRe = RegExp(r'(\d{1,2})[:：](\d{2})\s*発.{0,20}?(\d{1,2})[:：](\d{2})\s*着');

/// 「出発：羽田 07:45 → 到着：那覇 10:25」
final _arrowRe = RegExp(
    r'(\d{1,2})[:：](\d{2})[^\d\n]{0,20}?(?:→|⇒|->|➡|⇨)[^\d\n]{0,20}?(\d{1,2})[:：](\d{2})');

/// 「開場 16:00 / 開演 17:00」: 予定の開始は開演
final _kaienRe = RegExp(r'開演\s*[:：]?\s*(\d{1,2})[:：](\d{2})');

/// 「8:30集合 18:00解散」: 終わりの時刻
final _endWordRe = RegExp(r'(\d{1,2})[:：](\d{2})\s*(?:解散|終了|終わり|閉会)');

/// 「10-15」のような時だけの範囲（シフト連絡など）。日付を取り除いた残りにだけ使う
final _bareHoursRe = RegExp(r'(?<![\d/:：.])([0-2]?\d)\s*[-〜~～]\s*([0-2]?\d)(?:\s*時(?!間))?(?![\d/:：.時])');

final _rangeRe =
    RegExp(_timeTok + r'\s*(?:[-〜~～–—ー]|から)\s*' + _timeTok);
final _singleRe = RegExp(_timeTok);

final _taskWords = RegExp(r'締切|締め切り|〆|提出|期限|まで');
final _shiftWords = RegExp(r'シフト|バイト|勤務|出勤|早番|遅番|中番|日勤|夜勤');
final _lectureWords =
    RegExp(r'授業|講義|演習|ゼミ|実験|休講|補講|試験|テスト|[0-9１-９]\s*(?:時限|限)');

/// URL の前に付きがちなラベル（「Zoom:」「URL：」など）
final _linkLabelRe = RegExp(
    r'(?:(?:zoom|teams|google\s*meet|meet|webex)\s*)?(?:url|リンク|会議URL|参加URL|参加用URL|ミーティングURL|zoom|teams|meet|webex)\s*[:：]?\s*$',
    caseSensitive: false);

/// 所要時間（「約1時間」「1時間半」「90分程度」）。開始時刻だけのときに終了時刻を決める
final _durationRe = RegExp(
    r'[（(]?\s*(?:約|およそ|所要(?:時間)?\s*[:：]?\s*)?(?:(\d{1,2})\s*時間\s*(?:(\d{1,2})\s*分|(半))?|(?:\d{1,3}\s*[〜~～\-]\s*)?(\d{2,3})\s*分)\s*(?:間|程度|ほど|くらい|ぐらい|前後)?\s*[）)]?');

/// 補足の行の所要時間（「所要時間：60分」「時間は約2時間ほど」）を分で返す
int? _durationMins(String line) {
  if (!RegExp(r'所要|約\s*\d|およそ|程度|ほど|前後|くらい|ぐらい|^\s*\d').hasMatch(line)) return null;
  if (RegExp(r'前まで|前に|分前').hasMatch(line)) return null;
  final du = _durationRe.firstMatch(line);
  if (du == null) return null;
  final mins = du.group(4) != null
      ? int.parse(du.group(4)!)
      : du.group(1) == null
          ? 0
          : int.parse(du.group(1)!) * 60 +
              (du.group(3) != null ? 30 : int.tryParse(du.group(2) ?? '') ?? 0);
  return mins > 0 && mins <= 12 * 60 ? mins : null;
}

/// 文章の中の「面談日時」「説明会の日程」から、予定の名前（「面談」「説明会」）を拾う
final _hintRe = RegExp(r'([^\s、。「」■□◆●【】]{1,10}?)の?(?:日時|日程)(?:が|は|に|を|について|の)');
/// 挨拶などメモに入れなくてよい行
final _greetingRe = RegExp(r'^(よろしく|宜しく|お疲れ|おつかれ|お世話|以上|ありがとう)');
final _placeRe = RegExp(r'^\s*(?:場所|会場|教室|集合場所|集合|住所|所在地|劇場|映画館|劇場名|会場名|宿泊施設|宿泊先)\s*[:：]\s*(.+)$');

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

const _junk = r'[\s　・⋅·●■□◆◇▼▽▶►★☆○◎*＊\-–—―━─＝=:：,，、。/／〜~～|｜]';
final _trimHead = RegExp('^$_junk+');
final _trimTail = RegExp('$_junk+\$');

/// 「（水）」「(水曜日)」などの曜日表記
final _weekdayRe = RegExp(
    r'[（(]\s*[月火水木金土日](?:曜日?)?\s*[)）]|(?<=^|\s)[月火水木金土日](?:曜日?)?(?=\s|$)|\b(?:Mon|Tues|Wednes|Thurs|Fri|Satur|Sun)day\b,?');

/// 行頭の見出しラベル（「日時：」「【件名】」など）。group(1) がラベル名
final _labelRe = RegExp(
    r'^(?:[【\[〈<（(]\s*)?([^\s:：【】\[\]〈〉<>（）()]{1,14}(?:日時|日程)|[^\s:：【】\[\]〈〉<>（）()]{1,6}(?:期限|締切|締め切り|日|期間|時間)|When|Date|Time|時刻|開始時刻|時間帯|お届け時間|件名|トピック|タイトル|題名|内容|用件|日時|日程|日付|時間|開催日時?|実施日時?|期日|期限|提出期限|提出締切|締切|締め切り|〆切|イベント名?|科目名?|講義名?|授業名?|シフト|勤務)\s*(?:[】\]〉>）)]\s*[:：]?|[:：])\s*');

/// タイトルとして使えるラベル行（「件名: 〜」「内容：〜」）
final _titleLabelRe = RegExp(
    r'^(?:[【\[〈<（(]\s*)?(?:件名|[Ss]ubject|会社名|企業名|社名|サービス名|タイトル|題名|内容|用件|トピック|[Tt]opic|議題|列車名|便名|会議名|ミーティング名|作品名?|公演名|演目|イベント名?|科目名?|講義名?|授業名?)\s*(?:[】\]〉>）)]\s*[:：]?|[:：])\s*(.+)$');

/// メモ向きの行（ミーティングID・パスコード・持ち物など）
final _noteLineRe = RegExp(
    r'^(?:[※＊*]|.*(?:ID|ＩＤ|[Ii][Dd]\s*[:：]|パスコード|パスワード|[Pp]asscode|[Pp]assword|持ち物|備考|注意|服装)|(?:人数|会費|料金|金額|定員|形式|担当|電話|TEL|コース|プラン|お支払い方法)\s*[:：])');

/// 件名の前に付く【重要】などのタグ
final _tagRe = RegExp(
    r'[【\[](?:重要|至急|再送|再掲|訂正|変更|お知らせ|ご案内|連絡|案内|リマインド|リマインダー|reminder|日程変更)[】\]]',
    caseSensitive: false);

/// 文頭に残りやすい助詞（「11/20までに提出」→「までに」）
/// 1文字の助詞は、後ろがひらがなのときは語の一部（「のぞみ」「はやぶさ」）なので取らない
final _headParticleRe = RegExp(r'^(?:まで(?:に)?|から|より|頃|ごろ|(?:に|は|の|で|を|が)(?![ぁ-ゖ]))\s*');

/// 文末の丁寧表現（「提出してください」→「提出」）
final _politeTailRe = RegExp(
    r'(?:を|が|は)?(?:行います|おこないます|実施します|実施いたします|開催します|開催いたします|あります|ございます|いたします|致します|します|してください|して下さい|をお願いします|お願いします|お願い致します|お願いいたします|となります|になります|です|ます|ください|下さい)$');
final _tailParticleRe = RegExp(r'(?:を|が|は|に|の)$');

/// 案内文の定型の語尾（「〜のご案内」）
final _noticeTailRe =
    RegExp(r'(?:のご案内|のお知らせ|について|に関して|の件|のお願い|のご連絡|ご案内|お知らせ)$');

/// タイトルとしては情報が少ない語
final _genericRe = RegExp(
    r'^(?:締切|締め切り|〆切|提出|期限|予定|開始|集合|日程|日時|開催|実施|当日|ご?予約|ご?予約内容|ご?予約確認|ご?来店|ご案内|お知らせ|リマインド|確認|詳細|カレンダーに追加|カレンダーに登録(?:する)?|(?:あなたの)?ご?参加日|ご?予約日時?|予約の詳細|当日の詳細|ご予約の内容|DATE|TIME|PLACE|WHEN|Date|Time)$');

/// 「予約日時」「サービス名」「担当者」「当日の詳細」のような、値の前に付く見出しの語（タイトルにはしない）
final _labelishRe = RegExp(
    r'^.{0,8}(?:日時|日程|日付|参加日|予約日|開催日|時間|時刻|名|者|場所|会場|形式|内容|詳細|方法|情報|先)$');

/// 予定の名前になる語（「会社説明会」「面接」「空き家活用インターン」）。文の中からでも拾う
final _eventNounRe = RegExp(
    r'[^\s、。！!？?「」『』【】（）()の・：:]{0,16}?(?:説明選考会|説明会|選考会|面接|面談|相談会|セミナー|インターン(?:シップ)?|座談会|懇親会|会議|ミーティング|研修|講習|ワークショップ|勉強会|発表会|交流会|見学会)');

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
  // 「山田 花子 様」「お申込者：山田様」のような宛名
  if (RegExp(r'(?:様|さん|殿)\s*[)）]?\s*$').hasMatch(line)) return null;
  final tm = _titleLabelRe.firstMatch(line);
  final t = _cleanTitle(tm != null ? tm.group(1)! : line).title;
  if (t.isEmpty || t.length > 40 || _genericRe.hasMatch(t)) return null;
  return t;
}

/// 補足行から時刻を拾う（日付の行に時刻がなかったとき用）
/// 直前の _extractTime で「14:00-13:00」のような逆転した範囲を見つけたら、その文字列
String? _reversedRange;

/// 日付の形をしているが、ありえない日付（「2026/02/30」「13/45」）を見つける
final _dateLikeRe = RegExp(
    r'\d{4}\s*[/\-.年]\s*\d{1,2}\s*[/\-.月]\s*\d{1,2}|(?<![\d:/])\d{1,2}/\d{1,2}(?![\d:/])|\d{1,2}\s*月\s*\d{1,2}\s*日');

/// 時刻の形をしているもの（読み取れなかった「25:00」「12:60」を見つける）
final _timeLikeRe = RegExp(r'(?<![\d/])\d{1,2}:\d{2}(?!\d)');

/// 全角の数字・コロン・スラッシュを半角に
String _halfWidth(String s) => s
    .replaceAllMapped(RegExp('[０-９]'),
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0))
    // 「１０：００」の「：」だけ半角に（「日程：11/25」の見出しの「：」はそのまま）
    .replaceAllMapped(RegExp(r'(?<=\d)\s*：\s*(?=\d)'), (_) => ':')
    .replaceAll('／', '/')
    // 令和（「令和8年」「R8.12.22」）は西暦に直す
    .replaceAllMapped(RegExp(r'令和\s*(\d{1,2})\s*年'), (m) => '${2018 + int.parse(m.group(1)!)}年')
    .replaceAllMapped(
        RegExp(r'(?<![A-Za-z])R\s*(\d{1,2})\s*[./]\s*(\d{1,2})\s*[./]\s*(\d{1,2})(?!\d)'),
        (m) => '${2018 + int.parse(m.group(1)!)}/${m.group(2)}/${m.group(3)}');

/// 「【12月】」のあとに「1.」「4.」のような日の番号の行が並び、その下に予定が書いてある形
/// （日ごとの仕事の一覧など）を、「12月4日 西尾/国際展示場 16:30-21:30」のように日付つきの行に直す。
/// 「24:00-6:00」のように 24 時以降に始まる時刻は、翌日の 0:00〜 にする
String _expandDayList(String text, DateTime today) {
  final lines = text.split(RegExp(r'\r?\n'));
  final dayLine = RegExp(r'^\s*([0-9０-９]{1,2})\s*(?:[.．。、)）]|日)?\s*(?:[（(]\s*[月火水木金土日](?:曜日?)?\s*[)）])?\s*$');
  final dayHead = RegExp(r'^\s*([0-9０-９]{1,2})\s*[.．]\s*(\S.*)$');
  if (lines.where((l) => dayLine.hasMatch(l)).length < 3) return text;
  int? month;
  int? day;
  final out = <String>[];
  for (final raw in lines) {
    final l = _halfWidth(raw);
    final mm = _monthOnlyRe.firstMatch(l);
    final dm = dayLine.firstMatch(l);
    if (dm != null && month != null) {
      day = int.parse(dm.group(1)!);
      out.add('');
      continue;
    }
    if (dm == null && mm != null && _extractDate(l, today) == null && !l.contains(RegExp(r'\d{1,2}[:：]\d{2}'))) {
      month = int.parse(mm.group(1)!);
      day = null;
      out.add(raw);
      continue;
    }
    var body = l;
    var d = day;
    final hm = dayHead.firstMatch(l);
    if (month != null && hm != null && _extractDate(l, today) == null) {
      d = int.parse(hm.group(1)!);
      day = d;
      body = hm.group(2)!;
    }
    if (month == null || d == null || body.trim().isEmpty || _extractDate(body, today) != null ||
        !RegExp(r'\d{1,2}\s*[:：時]').hasMatch(body)) {
      out.add(raw);
      continue;
    }
    // 24 時以降の開始（「24:00-6:00」「25:30〜」）は翌日に
    var dd = DateTime(today.year, month, d);
    body = body.replaceFirstMapped(
        RegExp(r'(?<![\d:])(2[4-9])[:：](\d{2})(?=\s*[-〜~～－])'), (m) {
      dd = addDays(dd, 1);
      return '${int.parse(m.group(1)!) - 24}:${m.group(2)}';
    });
    out.add('${dd.month}月${dd.day}日 $body');
  }
  return out.join('\n');
}

/// 月だけの見出し（「12月シフト確定」「【2026年12月】」）
final _monthOnlyRe = RegExp(r'(?<!\d)(\d{1,2})\s*月(?!\s*\d)');

/// 行頭の日だけの日付（「5日(土)」「5(土)」）
final _dayOnlyRe = RegExp(
    r'^\s*(\d{1,2})\s*(?:日\s*(?:[（(]\s*[月火水木金土日](?:曜日?)?\s*[)）])?|[（(]\s*[月火水木金土日](?:曜日?)?\s*[)）])');

/// 日付のすぐ後ろに「・10日」「、2月10日」「・12/3」と続く日付（曜日は先に取り除いてある）
final _alsoDayRe = RegExp(
    r'(?:^|(?<=\s))\s*[・、，,]\s*(?:(\d{1,2})\s*月\s*(\d{1,2})\s*日|(\d{1,2})/(\d{1,2})(?![\d:/])|(\d{1,2})\s*日(?![間後前]))');

/// 「12/2 10:00 A、12/3 13:00 B」のように1行に複数の日付があれば分ける
final _multiSplitRe = RegExp(
    r'(?:[、，,；;]|\s[/／|｜]\s)\s*(?=(?:\d{4}\s*[/\-.年]\s*)?\d{1,2}\s*(?:/|月)\s*\d{1,2})');

({int? start, int? end, String rest}) _extractTime(String src) {
  _lastSplit = const [];
  final s = _plainTimeWords(src);
  // 「新横浜 08:12発 → 京都 10:07着」
  final kn = _kaienRe.firstMatch(s);
  if (kn != null && s.contains('開場')) {
    final a = int.parse(kn.group(1)!) * 60 + int.parse(kn.group(2)!);
    if (a < 24 * 60) {
      final rest = s
          .replaceRange(kn.start, kn.end, ' ')
          .replaceAll(RegExp(r'開場\s*[:：]?\s*\d{1,2}[:：]\d{2}\s*[/／]?'), ' ');
      return (start: a, end: null, rest: rest);
    }
  }
  final da = _depArrRe.firstMatch(s) ?? _arrowRe.firstMatch(s);
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
        if (b == null) _reversedRange = r.group(0);
      }
      return (start: a, end: b, rest: s.replaceRange(r.start, r.end, ' '));
    }
  }
  // 表からのコピー（「10:00<タブ>18:00」）: タブで並んだ2つの時刻は開始と終了
  final tb = RegExp(r'(\d{1,2})[:：](\d{2})\s*\t\s*(\d{1,2})[:：](\d{2})').firstMatch(s);
  if (tb != null) {
    final a = int.parse(tb.group(1)!) * 60 + int.parse(tb.group(2)!);
    final b = int.parse(tb.group(3)!) * 60 + int.parse(tb.group(4)!);
    if (a < 24 * 60 && b <= 24 * 60) {
      return (start: a, end: b > a ? b : b + 24 * 60, rest: s.replaceRange(tb.start, tb.end, ' '));
    }
  }
  // 「13-15時」: 後ろにだけ「時」が付く範囲
  final hh = RegExp(r'(?<![\d/:：.])(\d{1,2})\s*[-〜~～]\s*(\d{1,2})\s*時(?![間\d])').firstMatch(s);
  if (hh != null) {
    final a = int.parse(hh.group(1)!), b = int.parse(hh.group(2)!);
    if (a < b && b <= 24) {
      return (start: a * 60, end: b * 60, rest: s.replaceRange(hh.start, hh.end, ' '));
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
    var b = p.group(4) == null ? a : _digit(p.group(4)!);
    // 「2限・4限」は離れた2つの時限（範囲ではない）。先の時限だけにする。「1限・2限」は続きなので範囲
    if (p.group(2) != null && '・,、'.contains(p.group(3)!) && b != a + 1) b = a;
    if (a <= b && b <= _periods.length) {
      // 時限は通しの分（24:00 を超えると翌日）。開始はその日の時刻にし、
      // 終了が翌日にかかるときは 24:00 を超えた値のまま返す（後で終了日を翌日にする）
      // 昼休みなどをはさむ範囲は、休みの前後で別の予定にする（2 つ目以降は _lastSplit に）
      final blocks = periodBlocks(_periods, a - 1, b - 1);
      final ps = blocks.first.$1, pe = blocks.first.$2;
      final shift = ps - ps % (24 * 60);
      // 2 つ目以降も 1 つ目の日を基準にした通しの分にする（24:00 を超えれば翌日）
      _lastSplit = [for (final (x, y) in blocks.skip(1)) (x - shift, y - shift)];
      return (
        start: ps - shift,
        end: pe - shift,
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
  // 振り分けのキーワード（「ユニティー」など）や系統「バイト」の設定があるカレンダーを先に使う
  final calId = pickCalendar(cals, company, whole, genreByLabel('バイト'))?.id ??
      (cals.where((c) => ['ユニティー', '労働', 'バイト', 'シフト']
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
  final today = dateOnly(now);
  text = _expandDayList(text, today);
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
  // 1行に並んだ日付を分けたとき、分けた各部分の種類の手がかりに元の行全体を使う
  // （「11/28 10:00-15:00 / 11/29 13:00-18:00 バイト」は両方シフト）
  final wholeLine = <String, String>{};
  final lines = _joinHeadingValues([
    for (final l in text.split(RegExp(r'\r?\n')))
      ...() {
        // HTML の表から変換されたメール（「| 予約日時 |」）は、行の頭と終わりの縦棒を外す
        final whole = _halfWidth(l.replaceAllMapped(_mdLinkRe, (m) => '${m.group(1)} ${m.group(2)}'))
            .replaceAll(RegExp(r'^\s*\|\s*|\s*\|\s*$'), '');
        final parts = whole.split(_multiSplitRe);
        if (parts.length > 1) {
          for (final x in parts) {
            wholeLine[x.trim()] = whole;
          }
        }
        return parts;
      }(),
  ]);
  final unreadable = <String>[];
  final consumed = <int>{};
  out.addAll(_parseWorkNotices(lines, consumed, cals, text));
  // Moodle のタイムライン（課題の提出期限など）
  out.addAll(_parseMoodle(lines, consumed, today));

  // 段落の前置きの文（種類の手がかり）
  var context = '';
  // 「12月シフト」のような月だけの見出し（続く「5日(土)」の月）
  int? ctxMonth;
  // 前置きの文から拾った予定の名前（「面接にご予約いただき…」の「面接」）
  String? eventHint;
  // 見出しが「件名：」などで明示されたタイトルか、「会社名：」か
  var headingExplicit = false;
  var headingCompany = false;
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

    var d = _extractDate(body, today);
    // 「12月シフト確定」のあとの「5日(土) 9-17」: 見出しの月を補う
    if (d == null && ctxMonth != null) {
      final dm = _dayOnlyRe.firstMatch(body);
      if (dm != null) {
        d = _extractDate(body.replaceRange(dm.start, dm.end, '$ctxMonth月${dm.group(1)}日 '), today);
      }
    }
    if (d == null) {
      final mm = _monthOnlyRe.firstMatch(body);
      if (mm != null) ctxMonth = int.parse(mm.group(1)!);
    }
    // 日付の形なのに読めない行（ありえない日付）は、前の予定のメモに入れず知らせる
    if (d == null && _dateLikeRe.hasMatch(body)) {
      unreadable.add(line);
      skipped++;
      continue;
    }
    if (d == null && open == null && afterBlank != null) {
      final prev = afterBlank;
      // 「11/27（金）」のあと空行をはさんで「12:00〜12:30」だけの行
      if (prev.startMin == null && prev.type != ImportType.task &&
          RegExp(r'^\s*\d{1,2}[:：]\d{2}\s*(?:[-〜~～–]\s*\d{1,2}[:：]\d{2})?\s*$').hasMatch(body)) {
        final tt = _extractTime(body);
        if (tt.start != null) {
          prev.startMin = tt.start;
          final (e, off) = _splitEnd(tt.end);
          prev.endMin = e;
          prev.endOffset = off;
          continue;
        }
      }
      // 「■所要時間：60分」「時間は約2時間ほどを予定しております」
      if (prev.startMin != null && prev.endMin == null && prev.type != ImportType.task) {
        final mins = _durationMins(body);
        if (mins != null) {
          prev.endMin = math.min(prev.startMin! + mins, 23 * 60 + 59);
          continue;
        }
      }
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
          // 予定の名前の手がかり（「」の中を優先）
          final quoted = RegExp(r'[「『]([^」』]{2,30})[」』]').allMatches(body)
              .map((m) => _eventNounRe.firstMatch(m.group(1)!)?.group(0))
              .whereType<String>();
          final noun = quoted.isNotEmpty ? quoted.first : _eventNounRe.firstMatch(body)?.group(0);
          // 「〜さんがあなたを Zoom ミーティングに招待しています」のような定型文からは拾わない
          if (noun != null && !RegExp(r'招待').hasMatch(body)) {
            eventHint = noun.replaceAll(_trimHead, '');
          }
          if (h != null) {
            heading = h;
            // 「件名：」「トピック：」「会社名：」のようにタイトルと明示された見出し
            final tl = _titleLabelRe.firstMatch(body.replaceAll(_trimHead, ''));
            headingExplicit = tl != null;
            headingCompany = tl != null && RegExp(r'^\s*[【\[]?\s*(?:会社名|企業名|社名)').hasMatch(body.replaceAll(_trimHead, ''));
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
            target.splitRest = _lastSplit;
          }
          // 「集合：9:00 ○○大学 正門前」は残りを場所にする
          final gather = RegExp(r'^\s*(?:集合(?:場所|時間|時刻)?|待ち合わせ)\s*[:：]?\s*');
          final restText = _cleanTitle(tt.rest.replaceFirst(gather, '')).title;
          if (gather.hasMatch(body) && restText.isNotEmpty && target.place.isEmpty) {
            target.place = restText;
          } else if (restText.isNotEmpty) {
            target.note = _addLine(target.note, line);
          }
          continue;
        }
      }
      // 「所要時間：1時間前後」: 終わりの時刻がまだなければ入れる
      if (target.startMin != null && target.endMin == null && target.type != ImportType.task) {
        final mins = _durationMins(body);
        if (mins != null) {
          target.endMin = math.min(target.startMin! + mins, 23 * 60 + 59);
          continue;
        }
      }
      // 「解散予定 16:00」「終了 17:00」: 終わりの時刻がまだなければ入れる
      if (target.startMin != null &&
          target.endMin == null &&
          target.type != ImportType.task &&
          RegExp(r'解散|終了|終わり|閉会').hasMatch(line)) {
        final tt = _extractTime(body);
        if (tt.start != null && tt.end == null && tt.start! > target.startMin!) {
          target.endMin = tt.start;
          target.note = _addLine(target.note, line);
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
              target.splitRest = _lastSplit;
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
    // 「2月9日（火）・10日（水）・12日（金）」「12/2・12/3」: 続けて書かれた日付（同じ内容で別の日）
    final alsoOn = <DateTime>[];
    while (true) {
      final m = _alsoDayRe.firstMatch(rest);
      if (m == null) break;
      final mo = int.tryParse(m.group(1) ?? m.group(3) ?? '') ?? d.date.month;
      final day = int.parse(m.group(2) ?? m.group(4) ?? m.group(5)!);
      var dt = _validDate(d.date.year, mo, day);
      if (dt != null && !dt.isAfter(d.date)) dt = _validDate(d.date.year + 1, mo, day);
      if (dt == null || dt.difference(d.date).inDays > 60) break;
      alsoOn.add(dt);
      rest = rest.replaceRange(m.start, m.end, ' ');
    }
    // 「12月1日(火)〜12月3日(木)」: 数日にわたる予定
    var spanDays = 0;
    for (final sep in RegExp(r'[〜~～–ー\-]\s*(?=\d)').allMatches(rest)) {
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
    _reversedRange = null;
    final t = _extractTime(rest);
    final splitRest = _lastSplit;
    rest = t.rest;
    var start = t.start;
    var end = t.end;
    String? warning;
    if (_reversedRange != null) {
      warning = '終了が開始より前になっています（$_reversedRange）。時刻を確かめてください';
    }
    // 「8:30集合 18:00解散」
    if (start != null && end == null) {
      final ew = _endWordRe.firstMatch(rest);
      if (ew != null) {
        final e = int.parse(ew.group(1)!) * 60 + int.parse(ew.group(2)!);
        if (e > start && e <= 24 * 60) {
          end = e;
          rest = rest.replaceRange(ew.start, ew.end, ' ');
        }
      }
    }
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

    // 「2月15日〜17日 9:00〜17:00」: 期間に時刻の範囲が付いていれば、毎日その時間に行う予定
    if (spanDays > 0 && spanDays <= 31 && start != null && end != null && end > start &&
        end <= 24 * 60) {
      for (var k = 1; k <= spanDays; k++) {
        alsoOn.add(addDays(d.date, k));
      }
      spanDays = 0;
    }
    // 「25:00」「12:60」のように読めない時刻: 終日にせず、注意を付けてタイトルからも外す
    if (start == null) {
      final bad = _timeLikeRe.allMatches(rest).map((m) => m.group(0)!).toList();
      if (bad.isNotEmpty) {
        warning = '時刻（${bad.join('、')}）を読み取れませんでした。時刻を指定してください';
        rest = rest
            .replaceAll(RegExp(r'\d{1,2}:\d{2}\s*(?:[-〜~～–ー]\s*\d{1,2}:\d{2})?'), ' ');
      }
    }
    // 同じ行の場所（「場所：A棟201」「会場：〜」「@渋谷」）
    var place = '';
    final ip = RegExp(r'(?:場所|会場|教室)\s*[:：]\s*(\S+)|(?<=^|\s)[@＠]\s*(\S+)').firstMatch(rest);
    if (ip != null) {
      place = (ip.group(1) ?? ip.group(2))!;
      rest = rest.replaceRange(ip.start, ip.end, ' ');
    }
    // 「（受付9:30～）」のような時刻入りのかっこ書きは、タイトルではなくメモへ
    final sideNotes = <String>[];
    rest = rest.replaceAllMapped(RegExp(r'[（(][^（()）]*\d{1,2}(?:[:：]\d{2}|時(?!間))[^（()）]*[)）]'), (m) {
      sideNotes.add(m.group(0)!);
      return ' ';
    });
    final cleaned = _cleanTitle(rest);
    var title = cleaned.title;
    var weak = title.isEmpty || _genericRe.hasMatch(title);
    var borrowed = false;
    if (weak) {
      // 「予約日時」「当日の詳細」のような見出しの語より、前置きで拾った予定の名前を使う
      // 優先順: 予定の名前を含む見出し → 前置きの文の予定の名前 → 見出し（「担当者」のような語でないもの）
      final hd = heading != null && _labelishRe.hasMatch(heading) ? null : heading;
      final h = (hd != null && headingCompany && eventHint != null && !hd.contains(eventHint)
              ? '$hd $eventHint'
              : null) ??
          (hd != null && (headingExplicit || _eventNounRe.hasMatch(hd)) ? hd : null) ??
          eventHint ??
          hd ??
          heading ??
          subject;
      if (h != null) {
        // 「提出」など短い語だけ残った場合は見出しと組み合わせる
        title = title.isEmpty || h.contains(title) ? h : '$h $title';
        // 「申込締切：〜」のように見出しと別の締め切りなら、何の締め切りかを添える
        final lb = cleaned.label;
        final pre = lb.replaceFirst(RegExp(r'(?:期限|締切|締め切り)$'), '');
        if (pre.isNotEmpty && pre != lb && !h.contains(pre)) title = '$h（$lb）';
        weak = false;
        borrowed = true;
      } else if (title.isEmpty && cleaned.label.isNotEmpty &&
          !RegExp(r'^(?:日時|日程|日付|時間|開催日|実施日)').hasMatch(cleaned.label)) {
        // 「提出期限」など。「来店日時」「予約日時」は「来店」「予約」にする
        title = cleaned.label.replaceFirst(RegExp(r'(?:日時|日程|予定日|日)$'), '');
      }
    }

    final kindText = '$line $title ${wholeLine[line] ?? ''}';
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

    // 系統（授業・バイト・就活・病院…）を判断し、本人のマイカレンダーに振り分ける
    final genre = detectGenre(kindText, '$context $text');
    var calId = pickCalendar(cals, kindText, text, genre)?.id ??
        (genre?.label == 'バイト' && type == ImportType.event
            ? 'shift'
            : type.calendarId ?? 'other');
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
      note: [...sideNotes, if (urls.length > 1) ...urls.skip(1)].join('\n'),
      place: place,
    );
    if (warning != null) {
      c.warning = warning;
      c.selected = false;
    }
    c.alsoOn = alsoOn;
    if (start != null) c.splitRest = splitRest;
    c.genre = genre?.label;
    c.suggestedCalendarId = calId;
    out.add(c);
    open = c;
    needsTitle = weak ? c : null;
    fromHeading = borrowed ? c : null;
  }
  // 続けて書かれた日付（「・10日・12日」）: 続く行の時限・場所なども含めて、同じ内容で日付だけ変えた候補にする
  for (var i = 0; i < out.length; i++) {
    final c = out[i];
    if (c.alsoOn.isEmpty) continue;
    final copies = [for (final d in c.alsoOn) c.copyOn(d)];
    c.alsoOn = [];
    out.insertAll(i + 1, copies);
    i += copies.length;
  }
  // 昼休みなどをはさむ時限の範囲: 休みの前後で別の予定にする
  for (var i = 0; i < out.length; i++) {
    final c = out[i];
    if (c.splitRest.isEmpty || c.type == ImportType.task || c.startMin == null) {
      c.splitRest = [];
      continue;
    }
    final copies = <Candidate>[];
    for (final (bs, be) in c.splitRest) {
      final t = periodToEvent(bs, be);
      // 通しの分で日をまたいだ分だけ日付を進める
      final x = c.copyOn(addDays(c.date, bs ~/ (24 * 60)))
        ..startMin = t.start
        ..endMin = t.end
        ..endOffset = t.endOffset
        ..splitRest = []
        ..hint ??= '昼休みなどの休みの前後で分けました';
      copies.add(x);
    }
    c.hint ??= '昼休みなどの休みの前後で分けました';
    c.splitRest = [];
    out.insertAll(i + 1, copies);
    i += copies.length;
  }
  // 締め切りは終日が基本（0:00 は前日、23:59 はその日の終日。ほかの時刻は残す）
  for (final c in out) {
    if (c.type != ImportType.task || c.linkGroup != null) continue;
    final before = c.startMin;
    final (d, m) = normalizeDeadline(c.date, c.startMin);
    if (before != null && m == null) {
      c.hint = before <= 0
          ? '0:00 締切 → 前日（${fmtDate(d)}）の終日として登録'
          : '${fmtMin(math.min(before, 23 * 60 + 59))} 締切 → 終日として登録';
    }
    c.date = d;
    c.startMin = m;
  }
  // 文のままのタイトル（「説明会でお会いしましょう。…」）は、予定の名前の部分だけにする
  for (final c in out) {
    final t = c.title;
    if (_sentenceRe.hasMatch(t) || t.contains('。') || t.contains('ご連絡いたしました')) {
      final n = _eventNounRe.firstMatch(t)?.group(0);
      if (n != null) c.title = n.replaceAll(_trimHead, '');
    }
  }
  // 決まった書式（勤務連絡・Moodle）で読んだ候補にも系統を付ける
  for (final c in out) {
    c.genre ??= detectGenre('${c.source} ${c.title}', text)?.label;
    c.suggestedCalendarId ??= c.calendarId;
  }
  // タイトルの後始末: 「γ【〇〇面談：28卒】山田様〇〇大学」→「〇〇面談」、「【会社説明会】」→「会社説明会」
  for (final c in out) {
    var t = c.title
        .replaceFirst(RegExp(r'^[α-ωΑ-Ω]\s*'), '')
        .replaceAll(RegExp(r'\s*[：:]\s*\d{2}卒'), '')
        .replaceFirst(RegExp(r'】[^【】]*(?:様|さん)[^【】]*$'), '】')
        .trim();
    final br = RegExp(r'^【([^【】]+)】$').firstMatch(t);
    if (br != null) t = br.group(1)!.trim();
    if (t.isNotEmpty) c.title = t;
  }
  // 就活の予定は「どこの」が分かるよう、文章から会社・団体の名前を拾ってタイトルの頭に付ける
  final org = _findOrg(lines);
  if (org != null) {
    for (final c in out) {
      if (c.genre != '就活' || c.title.contains(org)) continue;
      c.title = c.title.isEmpty ? org : '$org ${c.title}';
    }
  }
  // 同じ日時の予定が文章の中に何度も出てくる（冒頭の文・詳細欄・Zoom の招待文）ときは 1 つにまとめる。
  // 情報の多いもの（終了時刻・リンク・場所があり、タイトルが文でないもの）を残し、足りない所を補う
  for (var i = 0; i < out.length; i++) {
    final a = out[i];
    if (a.type == ImportType.task || a.linkGroup != null || a.startMin == null) continue;
    for (var j = i + 1; j < out.length; j++) {
      final b = out[j];
      if (b.type == ImportType.task || b.linkGroup != null) continue;
      if (b.date != a.date || b.startMin != a.startMin) continue;
      if (a.endMin != null && b.endMin != null && a.endMin != b.endMin) continue;
      // 同じタイトルの重複は、2 件目に注意を付けて残す（下の処理）
      if (a.title.trim() == b.title.trim() && a.endMin == b.endMin) continue;
      final keep = _score(b) > _score(a) ? b : a;
      final drop = identical(keep, a) ? b : a;
      if (keep.endMin == null && drop.endMin != null) {
        keep.endMin = drop.endMin;
        keep.endOffset = drop.endOffset;
      }
      if (keep.url.isEmpty) keep.url = drop.url;
      if (keep.place.isEmpty) keep.place = drop.place;
      out[i] = keep;
      out.removeAt(j);
      j = i;
    }
  }
  // 同じ文章の中の重複と、候補どうしの時間の重なり
  final seen = <String, Candidate>{};
  for (final c in out) {
    final key = '${c.type.name}|${c.title.trim()}|${c.date}|${c.startMin}|${c.endMin}';
    if (seen.containsKey(key)) {
      c.warning ??= 'この文章の中に同じ予定がもう1つあります';
      c.selected = false;
      continue;
    }
    seen[key] = c;
  }
  final timed = [
    for (final c in out)
      if (c.type != ImportType.task && c.startMin != null && c.warning == null) c
  ];
  for (var i = 0; i < timed.length; i++) {
    for (var j = 0; j < timed.length; j++) {
      if (i == j) continue;
      final a = timed[i], b = timed[j];
      if (a.date != b.date) continue;
      final ae = a.endMin ?? a.startMin! + 60, be = b.endMin ?? b.startMin! + 60;
      if (a.startMin! < be && b.startMin! < ae) {
        a.hint ??= '取り込む候補「${b.title}」と時間が重なっています';
      }
    }
  }
  return ParseResult(out, skipped, unreadable);
}

/// 文章の中の会社・団体の名前（いちばん前に出てくるもの）。「株式会社」などは外す
String? _findOrg(List<String> lines) {
  const ng = r'[^\s　、。，,のはがを（(【「『：:！!？?]';
  final res = [
    // 英字の名前（「Sample Project 運営事務局」）
    RegExp(r'([A-Z][A-Za-z0-9&.\-]*(?: [A-Z][A-Za-z0-9&.\-]*){0,3})\s*(?:運営)?事務局'),
    // 「【サンプル精機】会社説明会」「サンプル精機 2028年新卒採用」
    RegExp('【($ng{2,20})】\\s*(?:会社)?(?:説明会|面接|選考|インターン|座談会|セミナー)'),
    RegExp('($ng{2,20}?)\\s*\\d{4}年度?新卒採用'),
    RegExp('(?:株式会社|（株）|㈱|有限会社)\\s*($ng{2,20})'),
    RegExp('($ng{2,20}?)\\s*(?:株式会社|（株）|㈱|有限会社)'),
    RegExp('($ng{2,20}?)[\\s　]*(?:新卒)?(?:採用|人事)(?:担当|チーム|事務局|本部|部)'),
    RegExp('^\\s*($ng{2,20})です。\\s*\$'),
    RegExp('($ng{2,20}?)\\s*(?:運営)?事務局'),
  ];
  for (final l in lines.take(400)) {
    String? found;
    var pos = 1 << 30;
    for (final re in res) {
      final m = re.firstMatch(l);
      if (m != null && m.start < pos) {
        pos = m.start;
        found = m.group(1);
      }
    }
    if (found == null) continue;
    final o = found.replaceAll(RegExp(r'^(?:こんにちは|お世話になっております|新卒)|様$|さん$'), '').trim();
    if (o.length >= 2 && !RegExp(r'^(?:新卒|採用|弊社|当社|貴社|御社|上記|下記)').hasMatch(o)) return o;
  }
  return null;
}

/// 同じ日時の候補のうち、どれを残すかの点数
int _score(Candidate c) {
  var s = 0;
  if (c.endMin != null) s += 2;
  if (c.url.isNotEmpty) s += 1;
  if (c.place.isNotEmpty) s += 1;
  final t = c.title;
  if (t.isEmpty || _genericRe.hasMatch(t) || _labelishRe.hasMatch(t)) s -= 2;
  if (_sentenceRe.hasMatch(t) || t.contains('。') || t.contains('、') || t.length > 30) s -= 3;
  if (_eventNounRe.hasMatch(t)) s += 1;
  return s;
}

String _addLine(String base, String line) =>
    base.isEmpty ? line : '$base\n$line';

/// 候補の終了時刻の既定値（開始+60分、23:59 まで）
int defaultEnd(int startMin) => math.min(startMin + 60, 23 * 60 + 59);
