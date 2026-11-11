import '../models.dart';
import '../reminders.dart';

/// サーバー（Railway）に渡す「これから鳴らす通知」の一覧を作る。
/// 繰り返しの計算はアプリ側だけで行い、サーバーは時刻が来たら送るだけにする。
///
/// 各要素: k=識別子, at=鳴らす時刻（UTC のミリ秒）, t=タイトル, b=本文
List<Map<String, Object>> buildPushQueue(
  List<Event> events,
  List<TaskItem> tasks,
  DateTime now, {
  int days = 30,
  int max = 300,
}) {
  final items = remindersBetween(events, tasks, now, now.add(Duration(days: days)));
  return [
    for (final r in items.take(max))
      {
        'k': r.key,
        'at': r.at.toUtc().millisecondsSinceEpoch,
        't': r.title,
        'b': r.body,
      },
  ];
}
