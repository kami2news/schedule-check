import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 予定とタスクを端末内（shared_preferences）に保存するストア
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this.events, this.tasks);

  final SharedPreferences _prefs;
  final List<Event> events;
  final List<TaskItem> tasks;
  int _seq = 0;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore._(
      prefs,
      _decode<Event>(prefs.getString('events'), Event.fromJson),
      _decode<TaskItem>(prefs.getString('tasks'), TaskItem.fromJson),
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
