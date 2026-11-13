import 'models.dart';

/// 通知の選択肢（分）。時刻のある予定・タスク用
const kTimedReminders = <int>[0, 5, 10, 15, 30, 60, 120, 1440];

/// 終日の予定・時刻なしの期限用（当日 0:00 からの分。マイナスは当日の朝）
const kAllDayReminders = <int>[-540, -420, 360, 900, 2340];

/// 通知の表示名
String reminderLabel(int? m, {required bool allDay}) {
  if (m == null) return 'なし';
  if (allDay) {
    // 0:00 からさかのぼる分 → 「何日前の何時」
    final at = -m; // 当日 0:00 からの分（マイナスは前日以前）
    final daysBefore = at >= 0 ? 0 : ((-at) + 1439) ~/ 1440;
    final minOfDay = at + daysBefore * 1440;
    final day = switch (daysBefore) { 0 => '当日', 1 => '前日', _ => '$daysBefore日前' };
    return '$day ${fmtMin(minOfDay)}';
  }
  if (m == 0) return '開始時刻';
  if (m % 1440 == 0) return '${m ~/ 1440}日前';
  if (m % 60 == 0) return '${m ~/ 60}時間前';
  return '$m分前';
}

/// 鳴らす通知1件
class ReminderItem {
  ReminderItem({
    required this.key,
    required this.at,
    required this.title,
    required this.body,
    this.event,
    this.task,
    this.date,
  });

  /// 同じ通知を2回出さないための識別子（予定 id + 回の日付 など）
  final String key;
  final DateTime at;
  final String title;
  final String body;
  final Event? event;
  final TaskItem? task;

  /// 予定の回の日付
  final DateTime? date;
}

DateTime _at(DateTime day, int? startMin) =>
    DateTime(day.year, day.month, day.day).add(Duration(minutes: startMin ?? 0));

/// 予定の、その回の通知の内容
String _eventBody(Event e, DateTime day, DateTime now) {
  final parts = <String>[];
  final today = dateOnly(now);
  final d = dateOnly(day);
  final when = d == today
      ? '今日 ${fmtDate(d)}'
      : d == addDays(today, 1)
          ? '明日 ${fmtDate(d)}'
          : fmtDate(d);
  parts.add('$when ${e.timeLabel}');
  if (e.place.isNotEmpty) parts.add(e.place);
  return parts.join('・');
}

/// [from] より後、[to] まで（含む）に鳴らす通知を、時刻順に返す
List<ReminderItem> remindersBetween(
    List<Event> events, List<TaskItem> tasks, DateTime from, DateTime to) {
  final out = <ReminderItem>[];
  bool inRange(DateTime t) => t.isAfter(from) && !t.isAfter(to);

  for (final e in events) {
    final r = e.reminder;
    if (r == null) continue;
    // 通知時刻が範囲内 ⇔ 開始が (from + r, to + r] の範囲。その日付を調べる
    var day = dateOnly(from.add(Duration(minutes: r))).subtract(Duration(days: 1));
    final last = dateOnly(to.add(Duration(minutes: r)));
    for (var i = 0; !day.isAfter(last) && i < 400; i++, day = addDays(day, 1)) {
      if (!e.occursOn(day)) continue;
      final at = _at(day, e.startMin).subtract(Duration(minutes: r));
      if (!inRange(at)) continue;
      out.add(ReminderItem(
        key: 'e:${e.id}@${day.toIso8601String().substring(0, 10)}',
        at: at,
        title: e.title,
        body: _eventBody(e, day, at),
        event: e,
        date: day,
      ));
    }
  }

  for (final t in tasks) {
    final r = t.reminder;
    if (r == null || t.done || t.due == null) continue;
    final at = _at(t.due!, t.dueMin).subtract(Duration(minutes: r));
    if (!inRange(at)) continue;
    final d = dateOnly(t.due!);
    final today = dateOnly(at);
    final day = d == today
        ? '今日 ${fmtDate(d)}'
        : d == addDays(today, 1)
            ? '明日 ${fmtDate(d)}'
            : fmtDate(d);
    out.add(ReminderItem(
      key: 't:${t.id}@${t.due!.toIso8601String().substring(0, 10)}-${t.dueMin}',
      at: at,
      title: t.title,
      body: '期限 $day${t.dueMin == null ? '' : ' ${fmtMin(t.dueMin!)}'}',
      task: t,
    ));
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
