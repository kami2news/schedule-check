import 'package:flutter/material.dart';

const weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// 週の開始曜日。Outlook（日本語版）に合わせて日曜始まり。月曜始まりにするなら false
const kWeekStartsOnSunday = true;

DateTime startOfWeek(DateTime d) {
  final offset = kWeekStartsOnSunday ? d.weekday % 7 : d.weekday - 1;
  return DateTime(d.year, d.month, d.day - offset);
}

String fmtLongDate(DateTime d) =>
    '${d.year}年${d.month}月${d.day}日（${weekdayNames[d.weekday - 1]}）';

String fmtDate(DateTime d) =>
    '${d.month}/${d.day}(${weekdayNames[d.weekday - 1]})';

String fmtMin(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Outlook の「マイカレンダー」に相当する、色と名前を持つカレンダー
class CalendarDef {
  CalendarDef({required this.id, required this.name, required this.colorValue});

  final String id;
  String name;
  int colorValue;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'color': colorValue};

  factory CalendarDef.fromJson(Map<String, dynamic> j) => CalendarDef(
        id: j['id'] as String,
        name: j['name'] as String,
        colorValue: j['color'] as int,
      );
}

/// 最初から用意しておくカレンダー（以前の「予定・シフト・授業」の種類と同じ id）
List<CalendarDef> defaultCalendars() => [
      CalendarDef(id: 'other', name: '予定', colorValue: 0xFF038387),
      CalendarDef(id: 'shift', name: 'シフト', colorValue: 0xFFCA5010),
      CalendarDef(id: 'lecture', name: '授業', colorValue: 0xFF4F6BED),
    ];

/// カレンダーに選べる色（Fluent 2 の共有カラーパレットから）
const kCalendarColors = <int>[
  0xFF0F6CBD, // ブルー
  0xFF4F6BED, // コーンフラワー
  0xFF0099BC, // シアン
  0xFF038387, // ティール
  0xFF00B294, // シーフォーム
  0xFF13A10E, // グリーン
  0xFF8BBF26, // ライム
  0xFFEAA300, // マリーゴールド
  0xFFF7630C, // パンプキン
  0xFFCA5010, // ダークオレンジ
  0xFFD13438, // レッド
  0xFFC50F1F, // クランベリー
  0xFFE43BA6, // ピンク
  0xFFC239B3, // ベリー
  0xFF8764B8, // パープル
  0xFF5C2E91, // グレープ
  0xFF8E562E, // ブラウン
  0xFF7A7574, // グレー
];

/// 予定の表示方法（Outlook の「表示方法」）
enum ShowAs { free, tentative, busy, workingElsewhere, away }

extension ShowAsX on ShowAs {
  String get label => switch (this) {
        ShowAs.free => '空き時間',
        ShowAs.tentative => '仮の予定',
        ShowAs.busy => '予定あり',
        ShowAs.workingElsewhere => '他の場所で仕事中',
        ShowAs.away => '外出中',
      };
}

class Event {
  Event({
    required this.id,
    required this.title,
    this.calendarId = 'other',
    required this.date,
    this.startMin,
    this.endMin,
    this.weekly = false,
    this.repeatUntil,
    this.place = '',
    this.note = '',
    this.url = '',
    this.showAs = ShowAs.busy,
  });

  final String id;
  String title;

  /// 所属するカレンダー（[CalendarDef.id]）
  String calendarId;

  /// 表示方法（予定あり・仮の予定など）
  ShowAs showAs;

  /// 初回（単発の場合はその日）の日付
  DateTime date;

  /// 0:00 からの経過分。null なら終日
  int? startMin;
  int? endMin;

  /// true の場合、[date] と同じ曜日に毎週繰り返す（時間割・固定シフト用）
  bool weekly;
  DateTime? repeatUntil;
  String place;
  String note;

  /// Zoom / Teams などのリンク
  String url;

  bool get allDay => startMin == null;

  String get timeLabel {
    if (startMin == null) return '終日';
    if (endMin == null) return fmtMin(startMin!);
    return '${fmtMin(startMin!)}–${fmtMin(endMin!)}';
  }

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final first = dateOnly(date);
    if (!weekly) return d == first;
    if (d.isBefore(first)) return false;
    if (d.weekday != first.weekday) return false;
    if (repeatUntil != null && d.isAfter(dateOnly(repeatUntil!))) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'calendar': calendarId,
        'showAs': showAs.name,
        'date': date.toIso8601String(),
        'startMin': startMin,
        'endMin': endMin,
        'weekly': weekly,
        'repeatUntil': repeatUntil?.toIso8601String(),
        'place': place,
        'note': note,
        'url': url,
      };

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        title: j['title'] as String,
        // 以前のデータは 'kind'（shift / lecture / other）をそのまま id にする
        calendarId:
            (j['calendar'] as String?) ?? (j['kind'] as String?) ?? 'other',
        showAs: ShowAs.values.firstWhere((v) => v.name == j['showAs'],
            orElse: () => ShowAs.busy),
        date: DateTime.parse(j['date'] as String),
        startMin: j['startMin'] as int?,
        endMin: j['endMin'] as int?,
        weekly: (j['weekly'] as bool?) ?? false,
        repeatUntil: j['repeatUntil'] == null
            ? null
            : DateTime.parse(j['repeatUntil'] as String),
        place: (j['place'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
      );
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.due,
    this.dueMin,
    this.done = false,
    this.important = false,
    this.note = '',
    this.url = '',
  });

  final String id;
  String title;
  DateTime? due;
  int? dueMin;
  bool done;

  /// 「重要」（星）マーク
  bool important;
  String note;

  /// 提出先や資料などのリンク
  String url;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'due': due?.toIso8601String(),
        'dueMin': dueMin,
        'done': done,
        'important': important,
        'note': note,
        'url': url,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        title: j['title'] as String,
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        dueMin: j['dueMin'] as int?,
        done: (j['done'] as bool?) ?? false,
        important: (j['important'] as bool?) ?? false,
        note: (j['note'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
      );
}

/// 期限の早い順（期限なしは最後）
int compareTasks(TaskItem a, TaskItem b) {
  if (a.due == null && b.due == null) return a.title.compareTo(b.title);
  if (a.due == null) return 1;
  if (b.due == null) return -1;
  final c = dateOnly(a.due!).compareTo(dateOnly(b.due!));
  if (c != 0) return c;
  return (a.dueMin ?? 24 * 60).compareTo(b.dueMin ?? 24 * 60);
}

/// 文字列中の URL（http/https）
final urlPattern = RegExp('https?://[^\\s<>"\'「」（）()、。]+');

/// リンクの種類に応じた表示名（Zoom / Teams / Meet / Webex / リンク）
String linkLabel(String url) {
  final u = url.toLowerCase();
  if (u.contains('zoom.us') || u.contains('zoom.com')) return 'Zoom';
  if (u.contains('teams.microsoft') || u.contains('teams.live')) return 'Teams';
  if (u.contains('meet.google')) return 'Google Meet';
  if (u.contains('webex')) return 'Webex';
  return 'リンク';
}

/// オンライン会議のリンクかどうか
bool isMeetingLink(String url) => linkLabel(url) != 'リンク';

/// 入力されたリンクを整える。「zoom.us/j/1」のように https:// が無ければ補う。
/// 開けない形（空白を含む・ドメインが無いなど）なら null
String? normalizeUrl(String input) {
  var u = input.trim();
  if (u.isEmpty || RegExp(r'\s').hasMatch(u)) return null;
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(u)) u = 'https://$u';
  final uri = Uri.tryParse(u);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  final host = uri.host;
  if (host.isEmpty) return null;
  if (host != 'localhost' && !RegExp(r'^[^.]+(\.[^.]+)+$').hasMatch(host)) {
    return null;
  }
  return u;
}
