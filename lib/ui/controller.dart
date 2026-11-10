import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../store.dart';

enum CalView { day, week, month }

extension CalViewX on CalView {
  String get label {
    switch (this) {
      case CalView.day:
        return '日';
      case CalView.week:
        return '週';
      case CalView.month:
        return '月';
    }
  }
}

/// カレンダーの表示状態（選択日・表示形式・表示するカレンダーの絞り込み）
class CalendarController extends ChangeNotifier {
  CalendarController({required this.view})
      : selected = dateOnly(DateTime.now());

  DateTime selected;
  CalView view;

  /// 非表示にする予定の種類（Outlook の「マイカレンダー」のチェックに相当）
  final Set<EventKind> hidden = {};

  /// タスクの期限をカレンダー上にも表示するか
  bool showTasks = true;

  void select(DateTime d) {
    selected = dateOnly(d);
    notifyListeners();
  }

  void setView(CalView v) {
    view = v;
    notifyListeners();
  }

  void goToday() => select(DateTime.now());

  void toggleKind(EventKind k) {
    if (!hidden.remove(k)) hidden.add(k);
    notifyListeners();
  }

  void setShowTasks(bool v) {
    showTasks = v;
    notifyListeners();
  }

  /// 同じ日付のまま ±1か月（月末は丸める）
  void shiftMonth(int dir) {
    final first = DateTime(selected.year, selected.month + dir, 1);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    selected = DateTime(
        first.year, first.month, math.min(selected.day, daysInMonth));
    notifyListeners();
  }

  /// 現在の表示形式に合わせて前後へ移動
  void step(int dir) {
    switch (view) {
      case CalView.day:
        selected = addDays(selected, dir);
        notifyListeners();
        break;
      case CalView.week:
        selected = addDays(selected, 7 * dir);
        notifyListeners();
        break;
      case CalView.month:
        shiftMonth(dir);
        break;
    }
  }

  String get title {
    final s = selected;
    switch (view) {
      case CalView.day:
        return '${s.year}年${s.month}月${s.day}日（${weekdayNames[s.weekday - 1]}）';
      case CalView.week:
        final a = startOfWeek(s);
        final b = addDays(a, 6);
        final head = '${a.year}年${a.month}月${a.day}日';
        final tail = a.month == b.month ? '${b.day}日' : '${b.month}月${b.day}日';
        return '$head – $tail';
      case CalView.month:
        return '${s.year}年${s.month}月';
    }
  }

  // ---- 絞り込み済みのデータ取得 ----

  List<Event> eventsOn(AppStore store, DateTime day) =>
      store.eventsOn(day).where((e) => !hidden.contains(e.kind)).toList();

  List<TaskItem> tasksOn(AppStore store, DateTime day) =>
      showTasks ? store.tasksDueOn(day) : const [];
}
