import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 予定とタスクを端末内（shared_preferences）に保存するストア
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this.events, this.tasks, this.calendars);

  final SharedPreferences _prefs;
  final List<Event> events;
  final List<TaskItem> tasks;

  /// マイカレンダー（並び順どおり）
  final List<CalendarDef> calendars;
  int _seq = 0;

  /// 表示テーマ（'system' / 'light' / 'dark'）
  String get themeMode => _prefs.getString('themeMode') ?? 'system';

  void setThemeMode(String mode) {
    _prefs.setString('themeMode', mode);
    notifyListeners();
  }

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore._(
      prefs,
      _decode<Event>(prefs.getString('events'), Event.fromJson),
      _decode<TaskItem>(prefs.getString('tasks'), TaskItem.fromJson),
      () {
        final c = _decode<CalendarDef>(
            prefs.getString('calendars'), CalendarDef.fromJson);
        return c.isEmpty ? defaultCalendars() : c;
      }(),
    );
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

  void _save() {
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
    _save();
    notifyListeners();
    return c;
  }

  void updateCalendar(String id, {String? name, int? color}) {
    final c = calendars.where((x) => x.id == id).firstOrNull;
    if (c == null) return;
    if (name != null) c.name = name;
    if (color != null) c.colorValue = color;
    _save();
    notifyListeners();
  }

  /// カレンダーを削除し、その予定は [moveTo] に移す（最後の1つは消せない）
  bool deleteCalendar(String id, {required String moveTo}) {
    if (calendars.length <= 1 || id == moveTo) return false;
    calendars.removeWhere((c) => c.id == id);
    for (final e in events) {
      if (e.calendarId == id) e.calendarId = moveTo;
    }
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
    _save();
    notifyListeners();
  }

  void deleteEvent(String id) {
    events.removeWhere((e) => e.id == id);
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
    _save();
    notifyListeners();
  }

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }

  void toggleTask(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    tasks[i].done = !tasks[i].done;
    _save();
    notifyListeners();
  }

  void toggleImportant(String id) {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    tasks[i].important = !tasks[i].important;
    _save();
    notifyListeners();
  }

  void addMany({List<Event> newEvents = const [], List<TaskItem> newTasks = const []}) {
    events.addAll(newEvents);
    tasks.addAll(newTasks);
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
