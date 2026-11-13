import 'package:material_ui/material_ui.dart';

const weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// 週の開始曜日。Outlook（日本語版）に合わせて日曜始まり。月曜始まりにするなら false
/// 週の始まりを日曜にするか（設定で変わる。false なら月曜始まり）
bool weekStartsOnSunday = true;

/// 土日を色分けするか（土曜は青、日曜は赤。設定で変わる）
bool weekendColorsOn = true;

DateTime startOfWeek(DateTime d) {
  final offset = weekStartsOnSunday ? d.weekday % 7 : d.weekday - 1;
  return DateTime(d.year, d.month, d.day - offset);
}

String fmtLongDate(DateTime d) =>
    '${d.year}年${d.month}月${d.day}日（${weekdayNames[d.weekday - 1]}）';

/// KM1 の日付の書き方「11/12（木）」
String fmtDate(DateTime d) =>
    '${d.month}/${d.day}（${weekdayNames[d.weekday - 1]}）';

/// 締め切りの日時のそろえ方:
/// - 0:00（24:00）締め切りは「前日いっぱい」なので、前日の終日にする
/// - 23:59 締め切りは、その日の終日にする
/// - それ以外の時刻はそのまま（カレンダーにその時刻の印を出す）
(DateTime, int?) normalizeDeadline(DateTime date, int? min) {
  final d = dateOnly(date);
  if (min == null) return (d, null);
  if (min <= 0) return (addDays(d, -1), null);
  if (min >= 24 * 60) return (d, null); // 24:00 = その日の終わり
  if (min >= 23 * 60 + 59) return (d, null);
  return (d, min);
}

/// KM1 の時刻の書き方「9:00」（24時間制、時の先頭に 0 を付けない）
String fmtMin(int m) => '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';

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

/// 繰り返しの単位
enum RepeatFreq { daily, weekly, monthly }

/// 毎月の繰り返し方（日付で／第n○曜日で）
enum MonthlyBy { date, weekday }

/// 繰り返しのルール（Outlook の「定期的なアイテム」に相当）
class Recurrence {
  const Recurrence({
    this.freq = RepeatFreq.weekly,
    this.interval = 1,
    this.weekdays = const {},
    this.monthlyBy = MonthlyBy.date,
  });

  final RepeatFreq freq;

  /// 何日／週／か月ごとか（隔週なら 2）
  final int interval;

  /// 曜日（1=月〜7=日）。毎週なら空のとき初回と同じ曜日、毎日なら空のとき全曜日
  final Set<int> weekdays;
  final MonthlyBy monthlyBy;

  static int _nth(DateTime d) => (d.day - 1) ~/ 7 + 1;
  static bool _isLastWeekdayOfMonth(DateTime d) =>
      DateTime(d.year, d.month, d.day + 7).month != d.month;

  /// [first]（初回）から見て、[d] が繰り返しに当たるか
  bool matches(DateTime first, DateTime d) {
    final f = dateOnly(first), x = dateOnly(d);
    if (x.isBefore(f)) return false;
    final n = interval < 1 ? 1 : interval;
    switch (freq) {
      case RepeatFreq.daily:
        if (weekdays.isNotEmpty && !weekdays.contains(x.weekday)) return false;
        return x.difference(f).inDays % n == 0;
      case RepeatFreq.weekly:
        final days = weekdays.isEmpty ? {f.weekday} : weekdays;
        if (!days.contains(x.weekday)) return false;
        final weeks = startOfWeek(x).difference(startOfWeek(f)).inDays ~/ 7;
        return weeks % n == 0;
      case RepeatFreq.monthly:
        final months = (x.year - f.year) * 12 + x.month - f.month;
        if (months % n != 0) return false;
        if (monthlyBy == MonthlyBy.date) return x.day == f.day;
        if (x.weekday != f.weekday) return false;
        final nth = _nth(f);
        // 第5週は「最終○曜日」として扱う
        if (nth >= 5) return _isLastWeekdayOfMonth(x);
        return _nth(x) == nth;
    }
  }

  /// 「毎週 月・水」「隔週 火曜」「毎月 第2水曜」などの表示
  String label(DateTime first) {
    String wd(Iterable<int> ds) {
      final order = weekStartsOnSunday ? [7, 1, 2, 3, 4, 5, 6] : [1, 2, 3, 4, 5, 6, 7];
      return order.where(ds.contains).map((d) => weekdayNames[d - 1]).join('・');
    }

    switch (freq) {
      case RepeatFreq.daily:
        if (weekdays.length == 5 && !weekdays.contains(6) && !weekdays.contains(7)) {
          return '平日（月〜金）';
        }
        if (weekdays.isNotEmpty) return '毎日（${wd(weekdays)}）';
        return interval == 1 ? '毎日' : '$interval日ごと';
      case RepeatFreq.weekly:
        final days = weekdays.isEmpty ? {first.weekday} : weekdays;
        final head = switch (interval) { 1 => '毎週', 2 => '隔週', _ => '$interval週ごと' };
        return '$head${wd(days)}曜';
      case RepeatFreq.monthly:
        final head = interval == 1 ? '毎月' : '$intervalか月ごと';
        if (monthlyBy == MonthlyBy.date) return '$head${first.day}日';
        final nth = _nth(first);
        final w = weekdayNames[first.weekday - 1];
        return nth >= 5 ? '$head最終$w曜' : '$head第$nth$w曜';
    }
  }

  Map<String, dynamic> toJson() => {
        'freq': freq.name,
        'interval': interval,
        if (weekdays.isNotEmpty) 'weekdays': ([...weekdays]..sort()),
        if (freq == RepeatFreq.monthly) 'monthlyBy': monthlyBy.name,
      };

  factory Recurrence.fromJson(Map<String, dynamic> j) => Recurrence(
        freq: RepeatFreq.values.firstWhere((v) => v.name == j['freq'],
            orElse: () => RepeatFreq.weekly),
        interval: (j['interval'] as num?)?.toInt() ?? 1,
        weekdays: {for (final x in (j['weekdays'] as List?) ?? const []) (x as num).toInt()},
        monthlyBy: MonthlyBy.values.firstWhere((v) => v.name == j['monthlyBy'],
            orElse: () => MonthlyBy.date),
      );

  @override
  bool operator ==(Object other) =>
      other is Recurrence &&
      other.freq == freq &&
      other.interval == interval &&
      other.monthlyBy == monthlyBy &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(freq, interval, monthlyBy, weekdays.length);
}

/// 予定のうち、ある1日にかかっている部分
class EventSlice {
  const EventSlice(this.startDay, this.start, this.end,
      {required this.allDay, required this.isStart, required this.isEnd});

  /// この回の開始日（続きの日でも、回を指すときはこの日付を使う）
  final DateTime startDay;

  /// その日の中での開始・終了（分）。続きの日は 0 から、まだ続く日は 24:00 まで
  final int start, end;
  final bool allDay;

  /// この日が開始日か／終了日か
  final bool isStart, isEnd;
}

class Event {
  Event({
    required this.id,
    required this.title,
    this.calendarId = 'other',
    required this.date,
    this.startMin,
    this.endMin,
    bool weekly = false,
    Recurrence? repeat,
    this.repeatUntil,
    this.place = '',
    this.note = '',
    this.url = '',
    this.showAs = ShowAs.busy,
    Set<DateTime>? exdates,
    this.seriesId,
    this.originalDate,
    this.reminder,
    this.endOffset = 0,
  })  : exdates = exdates ?? {},
        repeat = repeat ?? (weekly ? const Recurrence() : null);

  final String id;
  String title;

  /// 毎週の予定で、その回だけ無い日（休講・「この回のみ」変更した日）
  final Set<DateTime> exdates;

  /// 毎週の予定から切り出した回・分割した続きのとき、元の予定の id
  String? seriesId;

  /// 「この回のみ」変更した回の、本来の日付
  DateTime? originalDate;

  /// 所属するカレンダー（[CalendarDef.id]）
  String calendarId;

  /// 表示方法（予定あり・仮の予定など）
  ShowAs showAs;

  /// 初回（単発の場合はその日）の日付
  DateTime date;

  /// 0:00 からの経過分。null なら終日
  int? startMin;
  int? endMin;

  /// 繰り返しのルール（null なら単発）
  Recurrence? repeat;

  /// 繰り返す予定か（名前は以前の「毎週」設定の名残）
  bool get weekly => repeat != null;
  DateTime? repeatUntil;
  String place;
  String note;

  /// Zoom / Teams などのリンク
  String url;

  /// 通知（開始の何分前か）。終日の予定は当日 0:00 から数える
  /// （例: 360 = 前日 18:00、-540 = 当日 9:00）。null なら通知しない
  int? reminder;

  /// 終わるのが開始日の何日後か（0 = 同じ日）。夜勤などの日をまたぐ予定は 1 以上。
  /// 終日の予定では「何日間か - 1」
  int endOffset;

  bool get allDay => startMin == null;

  String get timeLabel {
    if (startMin == null) {
      return endOffset > 0 ? '終日（${endOffset + 1}日間）' : '終日';
    }
    if (endMin == null) return fmtMin(startMin!);
    final next = switch (endOffset) { 0 => '', 1 => '翌', _ => '$endOffset日後 ' };
    return '${fmtMin(startMin!)}〜$next${fmtMin(endMin!)}';
  }

  /// [day] にかかっている部分（日をまたぐ予定は、続きの日にも出る）。かかっていなければ null
  EventSlice? sliceOn(DateTime day) {
    final d = dateOnly(day);
    for (var k = 0; k <= endOffset; k++) {
      final first = addDays(d, -k);
      if (!occursOn(first)) continue;
      if (allDay) {
        return EventSlice(first, 0, 24 * 60, allDay: true, isStart: k == 0, isEnd: k == endOffset);
      }
      final s = k == 0 ? startMin! : 0;
      final e = k == endOffset ? (endMin ?? (k == 0 ? s + 30 : 0)) : 24 * 60;
      if (k > 0 && e <= 0) continue; // ちょうど 0:00 に終わる予定は、その日には出さない
      return EventSlice(first, s, e, allDay: false, isStart: k == 0, isEnd: k == endOffset);
    }
    return null;
  }

  /// [day] にかかっているか（開始日でなくても、続きの日なら true）
  bool coversDay(DateTime day) => sliceOn(day) != null;

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final first = dateOnly(date);
    final r = repeat;
    if (r == null) return d == first;
    if (!r.matches(first, d)) return false;
    if (repeatUntil != null && d.isAfter(dateOnly(repeatUntil!))) return false;
    if (exdates.contains(d)) return false;
    return true;
  }

  /// 毎週の予定の、最初の回の日付
  DateTime get firstDate => dateOnly(date);

  /// 繰り返しから切り出した回（「この回のみ」変更したもの）か
  bool get isException => originalDate != null;

  /// 中身を写した新しい予定（id などを差し替えるとき用）
  Event copyWith({
    String? id,
    DateTime? date,
    bool? weekly,
    Recurrence? repeat,
    DateTime? repeatUntil,
    bool clearRepeatUntil = false,
    Set<DateTime>? exdates,
    String? seriesId,
    DateTime? originalDate,
  }) =>
      Event(
        id: id ?? this.id,
        title: title,
        calendarId: calendarId,
        showAs: showAs,
        date: date ?? this.date,
        startMin: startMin,
        endMin: endMin,
        repeat: weekly == false
            ? null
            : (repeat ?? this.repeat ?? (weekly == true ? const Recurrence() : null)),
        repeatUntil: clearRepeatUntil ? null : (repeatUntil ?? this.repeatUntil),
        place: place,
        note: note,
        url: url,
        exdates: exdates ?? {...this.exdates},
        seriesId: seriesId ?? this.seriesId,
        originalDate: originalDate ?? this.originalDate,
        reminder: reminder,
        endOffset: endOffset,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'calendar': calendarId,
        'showAs': showAs.name,
        'date': date.toIso8601String(),
        'startMin': startMin,
        'endMin': endMin,
        'weekly': weekly,
        if (repeat != null) 'repeat': repeat!.toJson(),
        'repeatUntil': repeatUntil?.toIso8601String(),
        'place': place,
        'note': note,
        'url': url,
        if (exdates.isNotEmpty)
          'exdates': ([...exdates]..sort()).map((d) => d.toIso8601String()).toList(),
        if (seriesId != null) 'seriesId': seriesId,
        if (originalDate != null) 'originalDate': originalDate!.toIso8601String(),
        if (reminder != null) 'reminder': reminder,
        if (endOffset > 0) 'endOffset': endOffset,
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
        repeat: j['repeat'] is Map
            ? Recurrence.fromJson(Map<String, dynamic>.from(j['repeat'] as Map))
            : null,
        repeatUntil: j['repeatUntil'] == null
            ? null
            : DateTime.parse(j['repeatUntil'] as String),
        place: (j['place'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
        exdates: {
          for (final x in (j['exdates'] as List?) ?? const [])
            dateOnly(DateTime.parse(x as String)),
        },
        seriesId: j['seriesId'] as String?,
        originalDate: j['originalDate'] == null
            ? null
            : DateTime.parse(j['originalDate'] as String),
        reminder: (j['reminder'] as num?)?.toInt(),
        endOffset: (j['endOffset'] as num?)?.toInt() ?? 0,
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
    this.eventId,
    this.eventDate,
    this.followEnd = false,
    this.reminder,
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

  /// 関連する予定（終了報告・持ち物など）
  String? eventId;

  /// 関連する予定が繰り返しのとき、どの回か
  DateTime? eventDate;

  /// 期限を予定の終了時刻に合わせる（予定の時間が変わったら期限も動く）
  bool followEnd;

  /// 通知（期限の何分前か）。時刻なしの期限は当日 0:00 から数える。null なら通知しない
  int? reminder;

  /// カレンダーの時間の欄に、締め切り時刻の印（1分の枠）を出すか。
  /// 0:00 や 23:59 は終日扱いなので出さない
  bool get hasTimeMark =>
      due != null && dueMin != null && dueMin! > 0 && dueMin! < 23 * 60 + 59;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'due': due?.toIso8601String(),
        if (eventId != null) 'eventId': eventId,
        if (eventDate != null) 'eventDate': eventDate!.toIso8601String(),
        if (followEnd) 'followEnd': true,
        if (reminder != null) 'reminder': reminder,
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
        eventId: j['eventId'] as String?,
        eventDate: j['eventDate'] == null
            ? null
            : DateTime.parse(j['eventDate'] as String),
        followEnd: (j['followEnd'] as bool?) ?? false,
        reminder: (j['reminder'] as num?)?.toInt(),
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
