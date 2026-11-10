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

  // ---- 更新 ----

  void upsertEvent(Event e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    _remote?.putEvent(e);
    _save();
    notifyListeners();
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
    _remote?.removeEvent(id);
    _save();
    notifyListeners();
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
