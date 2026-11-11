import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/push/push_queue.dart';
import 'package:schedule_check/sync/push_service.dart';

void main() {
  test('サーバーに渡す通知の一覧（30日先まで・UTC のミリ秒）', () {
    final now = DateTime(2026, 11, 11, 8);
    final weekly = Event(
      id: 'w',
      title: '1限',
      date: DateTime(2026, 11, 2),
      startMin: 9 * 60,
      endMin: 10 * 60 + 30,
      repeat: const Recurrence(),
      reminder: 30,
    );
    final task = TaskItem(
        id: 't', title: '提出', due: DateTime(2026, 11, 12), dueMin: 17 * 60, reminder: 60);
    final q = buildPushQueue([weekly], [task], now);
    // 11/16, 23, 30, 12/7（12/11 まで）と、タスク1件
    expect(q.length, 5);
    expect(q.first['t'], '提出');
    expect(q.first['at'], DateTime(2026, 11, 12, 16).toUtc().millisecondsSinceEpoch);
    expect(q[1]['at'], DateTime(2026, 11, 16, 8, 30).toUtc().millisecondsSinceEpoch);
    expect(q[1]['b'], '今日 09:00–10:30');
    expect(buildPushQueue([weekly], [], now, max: 2).length, 2);
  });

  test('購読の ID は送り先から決まり、文書 ID に使える文字だけ', () {
    const ep = 'https://web.push.apple.com/QGx8z/abc+def';
    final id = subscriptionId(ep);
    expect(id, subscriptionId(ep));
    expect(id, isNot(subscriptionId('$ep/2')));
    expect(id.contains('/'), isFalse);
  });
}
