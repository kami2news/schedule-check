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

  EventKind? get eventKind {
    switch (this) {
      case ImportType.event:
        return EventKind.other;
      case ImportType.shift:
        return EventKind.shift;
      case ImportType.lecture:
        return EventKind.lecture;
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
  });

  String title;
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

const _timeTok = r'(\d{1,2})(?:[:：](\d{2})|時(?:(\d{1,2})分?)?)';
final _rangeRe =
    RegExp(_timeTok + r'\s*(?:[-〜~～–—ー]|から)\s*' + _timeTok);
final _singleRe = RegExp(_timeTok);

final _taskWords = RegExp(r'締切|締め切り|〆|提出|期限|まで');
final _shiftWords = RegExp(r'シフト|バイト|勤務|出勤');
final _lectureWords = RegExp(r'授業|講義|ゼミ|実験|休講|補講|試験|テスト');

/// URL の前に付きがちなラベル（「Zoom:」「URL：」など）
final _linkLabelRe = RegExp(
    r'(zoom|teams|meet|webex|url|リンク|会議URL|参加URL|参加用URL|ミーティングURL)\s*[:：]?\s*$',
    caseSensitive: false);
/// 挨拶などメモに入れなくてよい行
final _greetingRe = RegExp(r'^(よろしく|宜しく|お疲れ|おつかれ|お世話|以上|ありがとう)');
final _placeRe = RegExp(r'^\s*(?:場所|会場|教室|集合場所|集合)\s*[:：]\s*(.+)$');

final _trimHead = RegExp(r'^[\s　・●■□◆◇▼▽*\-–—:：,、。/【】]+');
final _trimTail = RegExp(r'[\s　・●■□◆◇▼▽*\-–—:：,、。/【】]+$');

int? _toMin(Match m, int hourGroup, int minGroupA, int minGroupB) {
  final h = int.parse(m.group(hourGroup)!);
  final mi =
      int.tryParse(m.group(minGroupA) ?? m.group(minGroupB) ?? '') ?? 0;
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
    if (dt.isBefore(today.subtract(const Duration(days: 180)))) {
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

  m = _relRe.firstMatch(s);
  if (m != null) {
    final word = m.group(0)!;
    final add = word == '明後日' ? 2 : (word == '明日' ? 1 : 0);
    final dt = DateTime(today.year, today.month, today.day + add);
    return (date: dt, rest: s.replaceRange(m.start, m.end, ' '));
  }
  return null;
}

ParseResult parseText(String text, DateTime now) {
  final today = dateOnly(now);
  final out = <Candidate>[];
  var skipped = 0;

  // 直前の候補に続く行（空行で区切られるまで）は、その候補の補足として扱う
  Candidate? open;

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      open = null;
      continue;
    }

    // URL は日付・時刻の誤検出を避けるため先に取り除く
    final urls = [for (final m in urlPattern.allMatches(line)) m.group(0)!];
    var body = line.replaceAll(urlPattern, ' ');

    final d = _extractDate(body, today);
    if (d == null) {
      final target = open;
      if (target == null) {
        skipped++;
        continue;
      }
      // 補足行: リンク・場所・メモに振り分ける
      if (urls.isNotEmpty && target.url.isEmpty) {
        target.url = urls.first;
        final restUrls = urls.skip(1).join(' ');
        final label = body.replaceAll(_linkLabelRe, '').trim();
        final extra = [label, restUrls].where((x) => x.isNotEmpty).join(' ');
        if (extra.isNotEmpty) target.note = _addLine(target.note, extra);
        continue;
      }
      if (_greetingRe.hasMatch(line)) continue;
      final p = _placeRe.firstMatch(line);
      if (p != null && target.place.isEmpty) {
        target.place = p.group(1)!.trim();
        continue;
      }
      target.note = _addLine(target.note, line);
      continue;
    }

    var rest = d.rest;
    int? start;
    int? end;
    final r = _rangeRe.firstMatch(rest);
    if (r != null) {
      start = _toMin(r, 1, 2, 3);
      end = _toMin(r, 4, 5, 6);
      if (start != null && end != null) {
        rest = rest.replaceRange(r.start, r.end, ' ');
        if (end <= start) end = null;
      } else {
        start = null;
        end = null;
      }
    }
    if (start == null) {
      final s = _singleRe.firstMatch(rest);
      if (s != null) {
        final v = _toMin(s, 1, 2, 3);
        if (v != null) {
          start = v;
          rest = rest.replaceRange(s.start, s.end, ' ');
        }
      }
    }

    var title = rest.replaceAll(RegExp(r'[\s　]+'), ' ').trim();
    title = title.replaceAll(_linkLabelRe, '');
    title = title.replaceAll(_trimHead, '').replaceAll(_trimTail, '');
    if (title.isEmpty) {
      final b = body.trim();
      title = b.length > 30 ? b.substring(0, 30) : b;
    }

    ImportType type;
    if (_taskWords.hasMatch(line)) {
      type = ImportType.task;
    } else if (_shiftWords.hasMatch(line)) {
      type = ImportType.shift;
    } else if (_lectureWords.hasMatch(line)) {
      type = ImportType.lecture;
    } else {
      type = ImportType.event;
    }

    final c = Candidate(
      title: title,
      date: d.date,
      type: type,
      source: line,
      startMin: start,
      endMin: type == ImportType.task ? null : end,
      url: urls.isEmpty ? '' : urls.first,
      note: urls.length > 1 ? urls.skip(1).join('\n') : '',
    );
    out.add(c);
    open = c;
  }
  return ParseResult(out, skipped);
}

String _addLine(String base, String line) =>
    base.isEmpty ? line : '$base\n$line';

/// 候補の終了時刻の既定値（開始+60分、23:59 まで）
int defaultEnd(int startMin) => math.min(startMin + 60, 23 * 60 + 59);
