// 予定の共有（端末の中で完結する部分）。
// - メールで招待された人の予定（相手のカレンダー）を、自分の予定と区別して並べるための id の付け方
// - リンクで共有するときに、AI がそのまま読める文章と、閲覧ページ用の一覧を作る
import 'models.dart';

/// 共有されている相手の予定・カレンダーの id の頭（自分のものと混ざらないように）
const kSharePrefix = 'share~';

/// 相手（[owner] = 相手の uid）の id を、この端末で使う id にする
String sharedId(String owner, String raw) => '$kSharePrefix$owner~$raw';

/// この端末の id から、相手と元の id を取り出す（共有のものでなければ null）
({String owner, String raw})? parseSharedId(String id) {
  if (!id.startsWith(kSharePrefix)) return null;
  final rest = id.substring(kSharePrefix.length);
  final i = rest.indexOf('~');
  if (i <= 0) return null;
  return (owner: rest.substring(0, i), raw: rest.substring(i + 1));
}

/// 予定の id とカレンダー（と、繰り返しから切り出した回の元の予定 [seriesId]）を付け替えた写し
Event rewrapEvent(Event e,
    {required String id, required String calendarId, String? Function(String)? series}) {
  final j = e.toJson();
  j['id'] = id;
  j['calendar'] = calendarId;
  final s = j['seriesId'] as String?;
  if (s != null && series != null) j['seriesId'] = series(s);
  return Event.fromJson(j);
}

/// 共有されている相手1人分の予定（メールで招待されたもの）
class SharedSource {
  SharedSource({
    required this.owner,
    required this.ownerName,
    required this.canEdit,
    this.events = const [],
    this.calendars = const [],
  });

  /// 相手の uid
  final String owner;

  /// 相手の名前（なければメールアドレス）
  final String ownerName;

  /// 編集できるか（招待で「編集可」になっているか）
  final bool canEdit;

  /// 相手のデータ（元の id のまま）
  final List<Event> events;
  final List<CalendarDef> calendars;

  /// この端末で並べる形（id とカレンダーを付け替え、カレンダー名に相手の名前を添える）
  late final List<CalendarDef> wrappedCalendars = [
    for (final c in calendars)
      CalendarDef(
          id: sharedId(owner, c.id),
          name: '${c.name}（$ownerName）',
          colorValue: c.colorValue),
  ];

  late final List<Event> wrappedEvents = [
    for (final e in events)
      rewrapEvent(e,
          id: sharedId(owner, e.id),
          calendarId: sharedId(owner, e.calendarId),
          series: (s) => sharedId(owner, s)),
  ];
}

// ---- リンクで共有（表示のみ・AI 向け） ----

/// 共有する範囲: 今日の7日前から90日先まで
({DateTime from, DateTime to}) shareRange(DateTime now) {
  final today = dateOnly(now);
  return (from: addDays(today, -7), to: addDays(today, 90));
}

/// 閲覧ページ・AI 向けに出す1件（繰り返しは回ごとに展開したもの）
class ShareItem {
  ShareItem({
    required this.date,
    required this.title,
    required this.calendar,
    required this.color,
    this.start,
    this.end,
    this.endOffset = 0,
    this.place = '',
  });

  final DateTime date;
  final String title;
  final String calendar;
  final int color;
  final int? start;
  final int? end;
  final int endOffset;
  final String place;

  bool get allDay => start == null;

  /// 「9:00〜10:30」「終日」「23:00〜翌5:00」
  String get timeLabel {
    if (start == null) {
      return endOffset > 0 ? '終日（${endOffset + 1}日間）' : '終日';
    }
    final next = endOffset == 1 ? '翌' : endOffset > 1 ? '$endOffset日後の' : '';
    return '${fmtMin(start!)}〜$next${fmtMin(end ?? start!)}';
  }

  Map<String, dynamic> toJson() => {
        'd': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        't': title,
        'c': calendar,
        'col': color,
        if (start != null) 's': start,
        if (end != null) 'e': end,
        if (endOffset != 0) 'o': endOffset,
        if (place.isNotEmpty) 'p': place,
      };

  factory ShareItem.fromJson(Map<String, dynamic> j) {
    final p = (j['d'] as String).split('-').map(int.parse).toList();
    return ShareItem(
      date: DateTime(p[0], p[1], p[2]),
      title: j['t'] as String? ?? '',
      calendar: j['c'] as String? ?? '',
      color: j['col'] as int? ?? 0xFF0F6CBD,
      start: j['s'] as int?,
      end: j['e'] as int?,
      endOffset: j['o'] as int? ?? 0,
      place: j['p'] as String? ?? '',
    );
  }
}

/// 期間内の予定を日ごとに並べる（[eventsOn] は「その日に始まる・かかる予定」を返す関数。
/// 日をまたぐ予定は始まる日にだけ入れる）。メモ・リンク（会議の URL など）は含めない
List<ShareItem> buildShareItems({
  required DateTime from,
  required DateTime to,
  required List<Event> Function(DateTime day) eventsOn,
  required CalendarDef Function(String id) calendarOf,
}) {
  final out = <ShareItem>[];
  for (var d = dateOnly(from); !d.isAfter(to); d = addDays(d, 1)) {
    for (final e in eventsOn(d)) {
      final s = e.sliceOn(d);
      if (s == null || !s.isStart) continue;
      final cal = calendarOf(e.calendarId);
      out.add(ShareItem(
        date: d,
        title: e.title,
        calendar: cal.name,
        color: cal.colorValue,
        start: e.startMin,
        end: e.endMin,
        endOffset: e.endOffset,
        place: e.place,
      ));
    }
  }
  return out;
}

/// AI がそのまま読める文章（Markdown に近い形）
String buildShareText({
  required String ownerName,
  required DateTime now,
  required DateTime from,
  required DateTime to,
  required List<ShareItem> items,
  required List<TaskItem> tasks,
}) {
  final b = StringBuffer();
  final at = '${fmtLongDate(now)} ${fmtMin(now.hour * 60 + now.minute)}';
  b.writeln('# $ownerNameさんの予定');
  b.writeln('期間: ${fmtLongDate(from)}〜${fmtLongDate(to)}（$at 時点。時刻は日本時間・24時間制）');
  b.writeln('この内容は表示のみの共有です。');
  b.writeln();
  b.writeln('## 予定');
  if (items.isEmpty) b.writeln('（予定はありません）');
  DateTime? day;
  for (final it in items) {
    if (it.date != day) {
      day = it.date;
      b.writeln();
      b.writeln('### ${fmtLongDate(it.date)}');
    }
    final place = it.place.isEmpty ? '' : ' ＠${it.place}';
    b.writeln('- ${it.timeLabel} ${it.title}（${it.calendar}）$place');
  }
  final open = tasks.where((t) => !t.done).toList()
    ..sort((a, b) => (a.due ?? DateTime(9999)).compareTo(b.due ?? DateTime(9999)));
  b.writeln();
  b.writeln('## 未完了のタスク');
  if (open.isEmpty) b.writeln('（ありません）');
  for (final t in open) {
    final due = t.due == null
        ? '期限なし'
        : '期限 ${fmtLongDate(t.due!)}${t.dueMin == null ? '' : ' ${fmtMin(t.dueMin!)}'}';
    b.writeln('- ${t.title}（$due${t.important ? '・重要' : ''}）');
  }
  return b.toString();
}
