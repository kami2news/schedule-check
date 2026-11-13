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

  /// 日表示で並べる日数（1〜7。2なら「2日」表示）
  int dayCount = 1;

  void setDayCount(int n) {
    dayCount = n.clamp(1, 7);
    view = CalView.day;
    notifyListeners();
  }

  /// 表示形式の名前（日表示は日数つき: 「日」「3日」）
  String get viewLabel =>
      view == CalView.day && dayCount > 1 ? '$dayCount日' : view.label;

  /// 日表示で並べる日
  List<DateTime> get dayViewDays =>
      [for (var i = 0; i < dayCount; i++) addDays(selected, i)];

  /// 非表示にする予定の種類（Outlook の「マイカレンダー」のチェックに相当）
  final Set<String> hidden = {};

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

  void toggleCalendar(String id) {
    if (!hidden.remove(id)) hidden.add(id);
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
        selected = addDays(selected, dir * dayCount);
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
        if (dayCount > 1) {
          final b = addDays(s, dayCount - 1);
          final tail = s.year != b.year
              ? '${b.year}年${b.month}月${b.day}日'
              : (s.month == b.month ? '${b.day}日' : '${b.month}月${b.day}日');
          return '${s.year}年${s.month}月${s.day}日 – $tail';
        }
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
      store.eventsOn(day).where((e) => !hidden.contains(e.calendarId)).toList();

  List<TaskItem> tasksOn(AppStore store, DateTime day) =>
      showTasks ? store.tasksDueOn(day) : [];
}
