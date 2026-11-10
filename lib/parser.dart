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
  });

  String title;
  DateTime date;
  ImportType type;
  int? startMin;
  int? endMin;
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

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final d = _extractDate(line, today);
    if (d == null) {
      skipped++;
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

    var title = rest.replaceAll(_trimHead, '').replaceAll(_trimTail, '');
    title = title.replaceAll(RegExp(r'[\s　]+'), ' ');
    if (title.isEmpty) {
      title = line.length > 30 ? line.substring(0, 30) : line;
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

    out.add(Candidate(
      title: title,
      date: d.date,
      type: type,
      source: line,
      startMin: start,
      endMin: type == ImportType.task ? null : end,
    ));
  }
  return ParseResult(out, skipped);
}

/// 候補の終了時刻の既定値（開始+60分、23:59 まで）
int defaultEnd(int startMin) => math.min(startMin + 60, 23 * 60 + 59);
