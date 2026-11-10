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
}
