import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// ログイン中の保存先（Firestore など）。ストアの変更を1件ずつ送る
abstract class RemoteSink {
  void putEvent(Event e);
  void removeEvent(String id);
  void putTask(TaskItem t);
  void removeTask(String id);
  void putCalendar(CalendarDef c, int order);
  void removeCalendar(String id);
}

/// 予定・タスク・マイカレンダーを持つストア。
/// ログインしていないときは端末内（shared_preferences）に保存し、
/// ログイン中は [RemoteSink] に送る（端末内のゲスト用データには触れない）。
/// 仮の時程（90分授業・休み10分・昼休み50分）。実際の時刻は設定で変更する
const kDefaultPeriods = <(int, int)>[
  (9 * 60, 10 * 60 + 30),
  (10 * 60 + 40, 12 * 60 + 10),
  (13 * 60, 14 * 60 + 30),
  (14 * 60 + 40, 16 * 60 + 10),
  (16 * 60 + 20, 17 * 60 + 50),
  (18 * 60, 19 * 60 + 30),
];

class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this.events, this.tasks, this.calendars);

  final SharedPreferences _prefs;
  final List<Event> events;
  final List<TaskItem> tasks;

  /// マイカレンダー（並び順どおり）
  final List<CalendarDef> calendars;
  int _seq = 0;

  RemoteSink? _remote;

  /// ログイン中（クラウドに保存中）か
  bool get isRemote => _remote != null;

  // ---- ログイン／ログアウトに伴う切り替え ----

  /// ログインしたらクラウド側に切り替える。データは [applyRemote] で届く
  void attachRemote(RemoteSink sink) {
    _remote = sink;
    events.clear();
    tasks.clear();
    calendars
      ..clear()
      ..addAll(defaultCalendars());
    notifyListeners();
  }

  /// ログアウトしたら端末内のゲスト用データに戻す
  void detachRemote() {
    _remote = null;
    _loadLocal();
    notifyListeners();
  }

  /// クラウドから届いた内容で置き換える（null の項目はそのまま）
  void applyRemote(
      {List<Event>? events, List<TaskItem>? tasks, List<CalendarDef>? calendars}) {
    if (!isRemote) return;
    if (events != null) {
      this.events
        ..clear()
        ..addAll(events);
    }
    if (tasks != null) {
      this.tasks
        ..clear()
        ..addAll(tasks);
    }
    if (calendars != null) {
      this.calendars
        ..clear()
        ..addAll(calendars.isEmpty ? defaultCalendars() : calendars);
    }
    notifyListeners();
  }

  /// 端末内に残っているゲスト用データの件数
  ({int events, int tasks, int calendars}) get guestDataCount {
    final e = _decode<Event>(_prefs.getString('events'), Event.fromJson);
    final t = _decode<TaskItem>(_prefs.getString('tasks'), TaskItem.fromJson);
    final c = _decode<CalendarDef>(
        _prefs.getString('calendars'), CalendarDef.fromJson);
    return (events: e.length, tasks: t.length, calendars: c.length);
  }

  bool get hasGuestData {
    final n = guestDataCount;
    return n.events > 0 || n.tasks > 0;
  }

  /// ゲスト用データをログイン中のアカウントへ移し、端末内からは消す
  void moveGuestDataToRemote() {
    final sink = _remote;
    if (sink == null) return;
    final e = _decode<Event>(_prefs.getString('events'), Event.fromJson);
    final t = _decode<TaskItem>(_prefs.getString('tasks'), TaskItem.fromJson);
    final c = _decode<CalendarDef>(
        _prefs.getString('calendars'), CalendarDef.fromJson);
    // 同じ id のカレンダー（既定の「予定」など）はアカウント側を残す
    var order = calendars.length;
    for (final cal in c) {
      if (calendars.any((x) => x.id == cal.id)) continue;
      calendars.add(cal);
      sink.putCalendar(cal, order++);
    }
    for (final x in e) {
      events.removeWhere((y) => y.id == x.id);
      events.add(x);
      sink.putEvent(x);
    }
    for (final x in t) {
      tasks.removeWhere((y) => y.id == x.id);
      tasks.add(x);
      sink.putTask(x);
    }
    _prefs.remove('events');
    _prefs.remove('tasks');
    _prefs.remove('calendars');
    notifyListeners();
  }

  /// 新しいアカウントに既定のカレンダーを書き込む
  void seedRemoteCalendars() {
    final sink = _remote;
    if (sink == null) return;
    for (var i = 0; i < calendars.length; i++) {
      sink.putCalendar(calendars[i], i);
    }
  }

  /// 表示テーマ（'system' / 'light' / 'dark'）
  String get themeMode => _prefs.getString('themeMode') ?? 'system';

  // ---- 時限（授業の時間帯） ----

  /// 時限の時刻（開始・終了の分）。設定が無ければ仮の時程
  List<(int, int)> get periods {
    final raw = _prefs.getString('periods');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((x) => ((x as List)[0] as int, x[1] as int))
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return kDefaultPeriods;
  }

  void setPeriods(List<(int, int)> list) {
    _prefs.setString(
        'periods', jsonEncode([for (final (a, b) in list) [a, b]]));
    notifyListeners();
  }

  /// 画面の表示状態（最後のタブ・表示形式など）。変更通知はしない
  String? uiValue(String key) => _prefs.getString('ui.$key');

  void setUiValue(String key, String value) =>
      _prefs.setString('ui.$key', value);

  void setThemeMode(String mode) {
    _prefs.setString('themeMode', mode);
    notifyListeners();
  }

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore._(prefs, [], [], []);
    store._loadLocal();
    return store;
  }

  void _loadLocal() {
    events
      ..clear()
      ..addAll(_decode<Event>(_prefs.getString('events'), Event.fromJson));
    tasks
      ..clear()
      ..addAll(_decode<TaskItem>(_prefs.getString('tasks'), TaskItem.fromJson));
    final c = _decode<CalendarDef>(
        _prefs.getString('calendars'), CalendarDef.fromJson);
    calendars
      ..clear()
      ..addAll(c.isEmpty ? defaultCalendars() : c);
  }

  static List<T> _decode<T>(
      String? raw, T Function(Map<String, dynamic>) fromJson) {
    final out = <T>[];
    if (raw == null) return out;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        try {
          out.add(fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // 壊れた1件だけ読み飛ばす
        }
      }
    } catch (_) {}
    return out;
  }

  /// 端末内に保存する（ログイン中は何もしない。クラウドへは個別に送る）
  void _save() {
    if (isRemote) return;
    _prefs.setString(
        'events', jsonEncode(events.map((e) => e.toJson()).toList()));
    _prefs.setString(
        'tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
    _prefs.setString(
        'calendars', jsonEncode(calendars.map((c) => c.toJson()).toList()));
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  // ---- 参照 ----

  List<Event> eventsOn(DateTime day) {
    final list = events.where((e) => e.occursOn(day)).toList();
    list.sort((a, b) => (a.startMin ?? -1).compareTo(b.startMin ?? -1));
    return list;
  }

  List<TaskItem> tasksDueOn(DateTime day) {
    final d = dateOnly(day);
    final list = tasks
        .where((t) => t.due != null && dateOnly(t.due!) == d)
        .toList();
    list.sort(compareTasks);
    return list;
  }

  /// id に対応するカレンダー（見つからなければ先頭）
  CalendarDef calendarOf(String id) =>
      calendars.firstWhere((c) => c.id == id, orElse: () => calendars.first);

  Color colorOf(Event e) => calendarOf(e.calendarId).color;

  // ---- カレンダー ----

  CalendarDef addCalendar(String name, int color) {
    final c = CalendarDef(id: newId(), name: name, colorValue: color);
    calendars.add(c);
    _remote?.putCalendar(c, calendars.length - 1);
    _save();
    notifyListeners();
    return c;
  }

  void updateCalendar(String id, {String? name, int? color}) {
    final c = calendars.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    if (name != null) c.name = name;
    if (color != null) c.colorValue = color;
    _remote?.putCalendar(c, calendars.indexOf(c));
    _save();
    notifyListeners();
  }

  /// カレンダーを削除し、その予定は [moveTo] に移す（最後の1つは消せない）
  bool deleteCalendar(String id, {required String moveTo}) {
    if (calendars.length <= 1 || id == moveTo) return false;
    calendars.removeWhere((c) => c.id == id);
    for (final e in events) {
      if (e.calendarId == id) {
        e.calendarId = moveTo;
        _remote?.putEvent(e);
      }
    }
    _remote?.removeCalendar(id);
    _save();
    notifyListeners();
    return true;
  }

  // ---- 繰り返しの予定（この回のみ・この回以降・すべて） ----

  /// 毎週の予定 [series] の [day] の回だけを [changed] の内容に変える。
  /// 元の予定からその日を除き、その回は単発の予定として切り出す。
  Event changeOccurrence(Event series, DateTime day, Event changed) {
    final d = dateOnly(day);
    series.exdates.add(d);
    upsertEvent(series);
    final single = changed.copyWith(
      id: newId(),
      weekly: false,
      clearRepeatUntil: true,
      exdates: {},
      seriesId: series.id,
      originalDate: d,
    );
    _relinkOccurrence(series, d, single);
    upsertEvent(single);
    return single;
  }

  /// 毎週の予定 [series] の [day] 以降を [changed] の内容に変える。
  /// 元の予定は前日で終わらせ、[day] からは新しい繰り返しとして続ける。
  Event changeFollowing(Event series, DateTime day, Event changed) {
    final d = dateOnly(day);
    if (!d.isAfter(series.firstDate)) {
      // 最初の回からなら「すべての回」と同じ
      final all = changed.copyWith(id: series.id, exdates: {...series.exdates});
      upsertEvent(all);
      return all;
    }
    final oldUntil = series.repeatUntil;
    final later = series.exdates.where((x) => !x.isBefore(d)).toSet();
    series.repeatUntil = d.subtract(const Duration(days: 1));
    series.exdates.removeAll(later);
    upsertEvent(series);
    // 曜日を変えた場合は、新しい曜日に合わせてずらした除外日だけ引き継ぐ
    final shift = dateOnly(changed.date).difference(d).inDays;
    final next = changed.copyWith(
      id: newId(),
      weekly: true,
      repeatUntil: changed.weekly ? changed.repeatUntil : oldUntil,
      exdates: {for (final x in later) x.add(Duration(days: shift))},
      seriesId: series.seriesId ?? series.id,
    );
    upsertEvent(next);
    return next;
  }

  /// 毎週の予定の [day] の回だけ削除する（休講など）
  void deleteOccurrence(Event series, DateTime day) {
    final d = dateOnly(day);
    series.exdates.add(d);
    _dropOccurrenceTasks(series, (x) => x == d);
    upsertEvent(series);
  }

  /// 毎週の予定の [day] 以降を削除する（最初の回からならすべて削除）
  void deleteFollowing(Event series, DateTime day) {
    final d = dateOnly(day);
    if (!d.isAfter(series.firstDate)) {
      deleteSeries(series);
      return;
    }
    series.repeatUntil = d.subtract(const Duration(days: 1));
    series.exdates.removeWhere((x) => !x.isBefore(d));
    _dropOccurrenceTasks(series, (x) => !x.isBefore(d));
    upsertEvent(series);
    // 切り出していた回のうち、それ以降のものも消す
    for (final e in events
        .where((e) =>
            e.seriesId == series.id &&
            e.originalDate != null &&
            !e.originalDate!.isBefore(d))
        .toList()) {
      deleteEvent(e.id);
    }
  }

  /// 毎週の予定をすべて削除する（切り出した回もいっしょに消す）
  void deleteSeries(Event series) {
    for (final e in events
        .where((e) => e.seriesId == series.id && e.originalDate != null)
        .toList()) {
      deleteEvent(e.id);
    }
    deleteEvent(series.id);
  }

  // ---- 更新 ----

  void upsertEvent(Event e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    _remote?.putEvent(e);
    _followEventTime(e);
    _save();
    notifyListeners();
  }

  /// 予定を削除する。まだ終わっていない関連タスク（終了報告など）もいっしょに消す
  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _remote?.removeEvent(id);
    for (final t in tasks.where((t) => t.eventId == id && !t.done).toList()) {
      tasks.remove(t);
      _remote?.removeTask(t.id);
    }
    _save();
    notifyListeners();
  }

  // ---- 予定とタスクのつながり ----

  /// 予定（繰り返しなら [day] の回）に関連するタスク
  List<TaskItem> tasksFor(Event e, [DateTime? day]) {
    final d = day == null ? null : dateOnly(day);
    return tasks
        .where((t) =>
            t.eventId == e.id &&
            (!e.weekly || t.eventDate == null || d == null || t.eventDate == d))
        .toList()
      ..sort(compareTasks);
  }

  Event? eventOf(TaskItem t) =>
      t.eventId == null ? null : events.where((e) => e.id == t.eventId).firstOrNull;

  /// 予定の終了時刻に合わせているタスクの期限を、予定に追従させる（単発の予定のみ）
  void _followEventTime(Event e) {
    if (e.weekly || e.startMin == null) return;
    final endDate = dateOnly(e.date);
    final endMin = e.endMin ?? e.startMin!;
    for (final t in tasks.where((t) => t.eventId == e.id && t.followEnd)) {
      // 夜勤の続き（0時開始）などは同じ日の終了時刻
      if (t.due != null && dateOnly(t.due!) == endDate && t.dueMin == endMin) continue;
      t.due = endDate;
      t.dueMin = endMin;
      _remote?.putTask(t);
    }
  }

  /// 繰り返しの回を切り出したとき、その回に結びついたタスクを新しい予定へ付け替える
  void _relinkOccurrence(Event series, DateTime day, Event single) {
    for (final t in tasks.where((t) => t.eventId == series.id && t.eventDate == day)) {
      t.eventId = single.id;
      t.eventDate = null;
      _remote?.putTask(t);
    }
  }

  /// 繰り返しの回を消したとき、その回のまだ終わっていないタスクも消す
  void _dropOccurrenceTasks(Event series, bool Function(DateTime d) match) {
    for (final t in tasks
        .where((t) =>
            t.eventId == series.id &&
            !t.done &&
            t.eventDate != null &&
            match(t.eventDate!))
        .toList()) {
      tasks.remove(t);
      _remote?.removeTask(t.id);
    }
  }

  void upsertTask(TaskItem t) {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
    _remote?.putTask(t);
    _save();
    notifyListeners();
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _remote?.removeTask(id);
    _save();
    notifyListeners();
  }

  void toggleTask(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    tasks[i].done = !tasks[i].done;
    _remote?.putTask(tasks[i]);
    _save();
    notifyListeners();
  }

  void toggleImportant(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    tasks[i].important = !tasks[i].important;
    _remote?.putTask(tasks[i]);
    _save();
    notifyListeners();
  }

  void addMany({List<Event> newEvents = const [], List<TaskItem> newTasks = const []}) {
    events.addAll(newEvents);
    tasks.addAll(newTasks);
    for (final e in newEvents) {
      _remote?.putEvent(e);
    }
    for (final t in newTasks) {
      _remote?.putTask(t);
    }
    _save();
    notifyListeners();
  }
}

/// ウィジェットツリーからストアを参照するための InheritedNotifier
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  /// build 中に使う（ストア更新で再ビルドされる）
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// ボタンのコールバックなど build 外で使う
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
