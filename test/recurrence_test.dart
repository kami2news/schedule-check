import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026/10/7（水）から毎週水曜 9:00–10:30 の授業
Event lecture() => Event(
      id: 'L',
      title: '環境化学',
      date: DateTime(2026, 10, 7),
      startMin: 9 * 60,
      endMin: 10 * 60 + 30,
      weekly: true,
      calendarId: 'lecture',
    );

final nov11 = DateTime(2026, 11, 11);
final nov18 = DateTime(2026, 11, 18);
final nov25 = DateTime(2026, 11, 25);

void main() {
  late AppStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await AppStore.load();
    store.upsertEvent(lecture());
  });

  Event series() => store.events.firstWhere((e) => e.id == 'L');
  List<Event> on(DateTime d) => store.eventsOn(d);

  test('この回のみ削除（休講）: その日だけ消え、前後の回は残る', () {
    store.deleteOccurrence(series(), nov18);
    expect(on(nov11).single.id, 'L');
    expect(on(nov18), isEmpty);
    expect(on(nov25).single.id, 'L');
  });

  test('この回のみ変更: その日だけ別の時間の予定になる', () {
    final changed = series().copyWith(date: nov18)
      ..startMin = 13 * 60
      ..endMin = 14 * 60 + 30;
    final single = store.changeOccurrence(series(), nov18, changed);
    expect(single.weekly, isFalse);
    expect(single.seriesId, 'L');
    expect(single.originalDate, nov18);
    expect(on(nov18).single.startMin, 13 * 60);
    expect(on(nov11).single.startMin, 9 * 60);
    expect(on(nov25).single.startMin, 9 * 60);
  });

  test('この回以降を変更: 前の回はそのまま、以降は新しい時間で続く', () {
    store.deleteOccurrence(series(), nov25); // 以降側の除外日も引き継がれる
    final changed = series().copyWith(date: nov18)..startMin = 10 * 60;
    final next = store.changeFollowing(series(), nov18, changed);
    expect(series().repeatUntil, DateTime(2026, 11, 17));
    expect(on(nov11).single.startMin, 9 * 60);
    expect(on(nov18).single.id, next.id);
    expect(on(nov18).single.startMin, 10 * 60);
    expect(on(nov25), isEmpty);
    expect(on(DateTime(2026, 12, 2)).single.id, next.id);
  });

  test('この回以降を削除: 前日で終わる。切り出した以降の回も消える', () {
    final changed = series().copyWith(date: nov25)..startMin = 15 * 60;
    store.changeOccurrence(series(), nov25, changed);
    store.deleteFollowing(series(), nov18);
    expect(on(nov11).single.id, 'L');
    expect(on(nov18), isEmpty);
    expect(on(nov25), isEmpty);
  });

  test('最初の回から「以降」はすべてと同じ。すべて削除で切り出した回も消える', () {
    store.changeOccurrence(series(), nov18, series().copyWith(date: nov18));
    store.deleteSeries(series());
    expect(store.events, isEmpty);
  });

  test('除外日などは保存して読み戻せる', () {
    store.deleteOccurrence(series(), nov18);
    final back = Event.fromJson(series().toJson());
    expect(back.exdates, {nov18});
    expect(back.occursOn(nov18), isFalse);
    final single = store.changeOccurrence(series(), nov25, series().copyWith(date: nov25));
    final b2 = Event.fromJson(single.toJson());
    expect(b2.seriesId, 'L');
    expect(b2.originalDate, nov25);
  });

  group('繰り返しのルール', () {
    final mon = DateTime(2026, 11, 2); // 月曜
    bool on(Recurrence r, DateTime first, DateTime d) => Event(
          id: 'x',
          title: 'x',
          date: first,
          repeat: r,
        ).occursOn(d);

    test('毎日・平日', () {
      const daily = Recurrence(freq: RepeatFreq.daily);
      expect(on(daily, mon, DateTime(2026, 11, 8)), isTrue);
      const weekdays = Recurrence(freq: RepeatFreq.daily, weekdays: {1, 2, 3, 4, 5});
      expect(on(weekdays, mon, DateTime(2026, 11, 6)), isTrue); // 金
      expect(on(weekdays, mon, DateTime(2026, 11, 7)), isFalse); // 土
      expect(weekdays.label(mon), '平日（月〜金）');
    });

    test('毎週の複数曜日・隔週', () {
      const mw = Recurrence(weekdays: {1, 3});
      expect(on(mw, mon, DateTime(2026, 11, 4)), isTrue); // 水
      expect(on(mw, mon, DateTime(2026, 11, 5)), isFalse); // 木
      expect(mw.label(mon), '毎週月・水曜');
      const bi = Recurrence(interval: 2);
      expect(on(bi, mon, DateTime(2026, 11, 9)), isFalse);
      expect(on(bi, mon, DateTime(2026, 11, 16)), isTrue);
      expect(bi.label(mon), '隔週月曜');
    });

    test('毎月（日付・第n曜日・最終曜日）', () {
      final d15 = DateTime(2026, 10, 15);
      const byDate = Recurrence(freq: RepeatFreq.monthly);
      expect(on(byDate, d15, DateTime(2026, 11, 15)), isTrue);
      expect(on(byDate, d15, DateTime(2026, 11, 16)), isFalse);
      expect(byDate.label(d15), '毎月15日');
      // 2026/10/14 は第2水曜
      final w2 = DateTime(2026, 10, 14);
      const byWd = Recurrence(freq: RepeatFreq.monthly, monthlyBy: MonthlyBy.weekday);
      expect(on(byWd, w2, DateTime(2026, 11, 11)), isTrue); // 11月の第2水曜
      expect(on(byWd, w2, DateTime(2026, 11, 18)), isFalse);
      expect(byWd.label(w2), '毎月第2水曜');
      // 2026/10/28 は最終水曜（第4）→ 第4で扱う / 10/30(金)は第5金曜→最終金曜
      final last = DateTime(2026, 10, 30);
      expect(byWd.label(last), '毎月最終金曜');
      expect(on(byWd, last, DateTime(2026, 11, 27)), isTrue); // 11月の最終金曜
    });

    test('以前の「毎週」データは毎週として読め、新しい形式も保存して戻せる', () {
      final old = Event.fromJson({
        'id': 'o',
        'title': 'old',
        'date': '2026-11-02T00:00:00.000',
        'weekly': true,
      });
      expect(old.repeat, const Recurrence());
      expect(old.occursOn(DateTime(2026, 11, 9)), isTrue);
      final e = Event(id: 'n', title: 'n', date: mon, repeat: const Recurrence(interval: 2, weekdays: {1, 4}));
      final back = Event.fromJson(e.toJson());
      expect(back.repeat, e.repeat);
    });
  });

  test('時限の時刻は保存でき、未設定なら仮の時程', () {
    expect(store.periods.first, (9 * 60, 10 * 60 + 30));
    store.setPeriods([(9 * 60 + 10, 10 * 60 + 40)]);
    expect(store.periods, [(9 * 60 + 10, 10 * 60 + 40)]);
  });

  group('予定とタスクのつながり', () {
    test('予定の時間を変えると、終了時刻に合わせたタスクの期限も動く。予定を消すとタスクも消える', () {
      final shift = Event(
          id: 'S', title: 'バイト', date: nov18, startMin: 15 * 60, endMin: 21 * 60);
      store.upsertEvent(shift);
      store.upsertTask(TaskItem(
          id: 'R', title: '終了報告', due: nov18, dueMin: 21 * 60, eventId: 'S', followEnd: true));
      store.upsertTask(TaskItem(id: 'M', title: '持ち物', due: nov18, eventId: 'S'));
      expect(store.tasksFor(shift).map((t) => t.id), containsAll(['R', 'M']));

      shift.endMin = 22 * 60;
      store.upsertEvent(shift);
      expect(store.tasks.firstWhere((t) => t.id == 'R').dueMin, 22 * 60);
      expect(store.tasks.firstWhere((t) => t.id == 'M').dueMin, isNull);

      store.deleteEvent('S');
      expect(store.tasks.where((t) => t.id == 'R' || t.id == 'M'), isEmpty);
    });

    test('繰り返しの回に付けたタスクは、その回を切り出すと新しい予定へ付け替わり、回を消すと消える', () {
      store.upsertTask(TaskItem(id: 'P', title: 'レポート', eventId: 'L', eventDate: nov18));
      store.upsertTask(TaskItem(id: 'Q', title: '予習', eventId: 'L', eventDate: nov25));
      final single = store.changeOccurrence(series(), nov18, series().copyWith(date: nov18));
      expect(store.tasks.firstWhere((t) => t.id == 'P').eventId, single.id);
      store.deleteOccurrence(series(), nov25);
      expect(store.tasks.where((t) => t.id == 'Q'), isEmpty);
    });
  });
}
