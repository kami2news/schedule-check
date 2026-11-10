import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/reminders.dart';

void main() {
  test('通知の表示名', () {
    expect(reminderLabel(null, allDay: false), 'なし');
    expect(reminderLabel(0, allDay: false), '開始時刻');
    expect(reminderLabel(15, allDay: false), '15分前');
    expect(reminderLabel(120, allDay: false), '2時間前');
    expect(reminderLabel(1440, allDay: false), '1日前');
    expect(reminderLabel(-540, allDay: true), '当日 09:00');
    expect(reminderLabel(360, allDay: true), '前日 18:00');
    expect(reminderLabel(2340, allDay: true), '2日前 09:00');
  });

  test('予定の通知は開始の◯分前、範囲内のものだけ', () {
    final e = Event(
        id: 'a',
        title: 'ゼミ',
        date: DateTime(2026, 11, 12),
        startMin: 13 * 60,
        endMin: 14 * 60,
        place: '理学部',
        reminder: 15);
    final hit = remindersBetween([e], [], DateTime(2026, 11, 12, 12, 40),
        DateTime(2026, 11, 12, 12, 45));
    expect(hit.single.at, DateTime(2026, 11, 12, 12, 45));
    expect(hit.single.body, '今日 13:00–14:00・理学部');
    expect(hit.single.date, DateTime(2026, 11, 12));
    // 境界: from ちょうどは含まない（前回出したもの）
    expect(
        remindersBetween([e], [], DateTime(2026, 11, 12, 12, 45),
            DateTime(2026, 11, 12, 12, 50)),
        isEmpty);
  });

  test('繰り返しの予定は回ごと。休みの回は鳴らない。日をまたぐ通知も拾う', () {
    final e = Event(
      id: 'w',
      title: '1限',
      date: DateTime(2026, 11, 2), // 月曜
      startMin: 9 * 60,
      endMin: 10 * 60 + 30,
      repeat: const Recurrence(),
      reminder: 1440, // 前日 9:00
      exdates: {DateTime(2026, 11, 16)},
    );
    final hits = remindersBetween(
        [e], [], DateTime(2026, 11, 1), DateTime(2026, 11, 30));
    expect(hits.map((h) => h.at).toList(), [
      DateTime(2026, 11, 1, 9),
      DateTime(2026, 11, 8, 9),
      DateTime(2026, 11, 22, 9),
      DateTime(2026, 11, 29, 9),
    ]);
    expect(hits.first.key, isNot(hits[1].key));
  });

  test('終日の予定は 0:00 から数える（前日 18:00）', () {
    final e = Event(
        id: 'd', title: '学園祭', date: DateTime(2026, 11, 20), reminder: 360);
    final h = remindersBetween(
            [e], [], DateTime(2026, 11, 19, 17), DateTime(2026, 11, 19, 19))
        .single;
    expect(h.at, DateTime(2026, 11, 19, 18));
    expect(h.body, '明日 終日');
  });

  test('タスクは期限の◯分前。完了済みは鳴らない', () {
    final t = TaskItem(
        id: 't',
        title: 'レポート提出',
        due: DateTime(2026, 11, 13),
        dueMin: 17 * 60,
        reminder: 60);
    final done = TaskItem(
        id: 'u',
        title: '済み',
        due: DateTime(2026, 11, 13),
        dueMin: 17 * 60,
        reminder: 60,
        done: true);
    final h = remindersBetween(
        [], [t, done], DateTime(2026, 11, 13, 15), DateTime(2026, 11, 13, 16));
    expect(h.single.title, 'レポート提出');
    expect(h.single.body, '期限 今日 17:00');
  });

  test('通知の設定は保存して読み戻せる', () {
    final e = Event(id: 'a', title: 'x', date: DateTime(2026, 11, 12), reminder: 30);
    expect(Event.fromJson(e.toJson()).reminder, 30);
    expect(e.copyWith(id: 'b').reminder, 30);
    final t = TaskItem(id: 't', title: 'y', due: DateTime(2026, 11, 12), reminder: -540);
    expect(TaskItem.fromJson(t.toJson()).reminder, -540);
  });
}
