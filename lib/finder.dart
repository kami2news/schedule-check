import 'dart:math' as math;

import 'models.dart';

// ---------------------------------------------------------------------------
// 検索
// ---------------------------------------------------------------------------

/// 検索結果の1件（予定かタスク）
class SearchHit {
  SearchHit.event(this.event, this.date) : task = null;
  SearchHit.task(this.task)
      : event = null,
        date = task!.due;

  final Event? event;
  final TaskItem? task;

  /// 予定なら表示する日（繰り返しは次の回）、タスクなら期限
  final DateTime? date;
}

String _fold(String s) => s
    .toLowerCase()
    // 全角英数を半角に
    .replaceAllMapped(RegExp('[０-９Ａ-Ｚａ-ｚ]'),
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0))
    .replaceAll(RegExp(r'[\s　]+'), '');

bool _hit(String query, List<String> fields) {
  final words = query.split(RegExp(r'[\s　]+')).where((w) => w.isNotEmpty).map(_fold);
  final hay = fields.map(_fold).join('\n');
  return words.every(hay.contains);
}

/// 繰り返しの予定の、[from] 以降で最初の回（1年先まで探す）
DateTime? nextOccurrence(Event e, DateTime from) {
  var d = dateOnly(from);
  for (var i = 0; i < 400; i++) {
    if (e.occursOn(d)) return d;
    d = addDays(d, 1);
  }
  return null;
}

/// タイトル・場所・メモ・リンクから探す。スペース区切りの語はすべて含むものだけ。
/// これからの予定（近い順）→ 過去の予定（新しい順）→ タスク の順に並べる
List<SearchHit> searchAll(
    String query, List<Event> events, List<TaskItem> tasks, DateTime now) {
  if (query.trim().isEmpty) return [];
  final today = dateOnly(now);
  final upcoming = <SearchHit>[], past = <SearchHit>[];
  for (final e in events) {
    if (!_hit(query, [e.title, e.place, e.note, e.url])) continue;
    final d = e.weekly ? (nextOccurrence(e, today) ?? e.firstDate) : e.firstDate;
    final hit = SearchHit.event(e, d);
    (!d.isBefore(today) ? upcoming : past).add(hit);
  }
  upcoming.sort((a, b) => a.date!.compareTo(b.date!));
  past.sort((a, b) => b.date!.compareTo(a.date!));
  final ts = [
    for (final t in tasks)
      if (_hit(query, [t.title, t.note, t.url])) SearchHit.task(t)
  ]..sort((a, b) => compareTasks(a.task!, b.task!));
  return [...upcoming, ...past, ...ts];
}

// ---------------------------------------------------------------------------
// 空き時間
// ---------------------------------------------------------------------------

/// 空き時間の1枠
class FreeSlot {
  FreeSlot(this.date, this.start, this.end);
  final DateTime date;
  final int start;
  final int end;

  int get minutes => end - start;

  /// 「11/16(月) 13:00〜17:00」
  String get label => '${fmtDate(date)} ${fmtMin(start)}〜${fmtMin(end)}';
}

/// 空き時間の探し方
class FreeTimeOptions {
  const FreeTimeOptions({
    this.days = 14,
    this.dayStart = 9 * 60,
    this.dayEnd = 19 * 60,
    this.minMinutes = 60,
    this.weekends = false,
    this.buffer = 0,
    this.allDayBusy = true,
  });

  /// 何日先まで探すか
  final int days;

  /// 1日のうち候補にする時間帯
  final int dayStart;
  final int dayEnd;

  /// これより短い空きは出さない
  final int minMinutes;

  /// 土日も候補にするか
  final bool weekends;

  /// 予定の前後に空けておく時間（移動など）
  final int buffer;

  /// 終日の予定がある日は空いていないとみなす
  final bool allDayBusy;
}

/// [from] の日から、予定の入っていない時間を探す。
/// 「空き時間」に設定した予定と、[ignoreCalendars] のカレンダーの予定は無視する
List<FreeSlot> findFreeSlots(
  List<Event> events,
  DateTime from,
  FreeTimeOptions o, {
  DateTime? now,
  Set<String> ignoreCalendars = const {},
}) {
  final out = <FreeSlot>[];
  final first = dateOnly(from);
  for (var i = 0; i < o.days; i++) {
    final day = addDays(first, i);
    if (!o.weekends && (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday)) {
      continue;
    }
    final todays = events.where((e) =>
        e.occursOn(day) &&
        e.showAs != ShowAs.free &&
        !ignoreCalendars.contains(e.calendarId));
    if (o.allDayBusy && todays.any((e) => e.startMin == null)) continue;

    // 予定のある時間（前後に余裕を足す）
    final busy = <(int, int)>[
      for (final e in todays.where((e) => e.startMin != null))
        (
          e.startMin! - o.buffer,
          (e.endMin ?? e.startMin! + 60) + o.buffer,
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    var cursor = o.dayStart;
    // 今日は今の時刻（30分単位に切り上げ）より後だけ
    if (now != null && day == dateOnly(now)) {
      final m = now.hour * 60 + now.minute;
      cursor = math.max(cursor, ((m + 29) ~/ 30) * 30);
    }
    for (final (s, e) in busy) {
      if (s > cursor) {
        final end = math.min(s, o.dayEnd);
        if (end - cursor >= o.minMinutes) out.add(FreeSlot(day, cursor, end));
      }
      cursor = math.max(cursor, e);
      if (cursor >= o.dayEnd) break;
    }
    if (o.dayEnd - cursor >= o.minMinutes) out.add(FreeSlot(day, cursor, o.dayEnd));
  }
  return out;
}

/// 候補日を、メールやメッセージに貼れる文章にする
String formatSlots(List<FreeSlot> slots) =>
    slots.map((s) => '・${s.label}').join('\n');
