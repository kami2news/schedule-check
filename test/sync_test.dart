import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 送られた変更を記録するだけの保存先
class FakeSink implements RemoteSink {
  final log = <String>[];

  @override
  void putEvent(Event e) => log.add('putEvent ${e.id}');
  @override
  void removeEvent(String id) => log.add('removeEvent $id');
  @override
  void putTask(TaskItem t) => log.add('putTask ${t.id}');
  @override
  void removeTask(String id) => log.add('removeTask $id');
  @override
  void putCalendar(CalendarDef c, int order) =>
      log.add('putCalendar ${c.id} $order');
  @override
  void removeCalendar(String id) => log.add('removeCalendar $id');
  @override
  void putSettings(Map<String, dynamic> settings) =>
      log.add('putSettings ${settings['themeMode']}');
}

Event _ev(String id) => Event(id: id, title: id, date: DateTime(2026, 11, 10));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ログイン中の変更はクラウドへ送り、端末内のゲスト用データは変えない', () async {
    final store = await AppStore.load();
    store.upsertEvent(_ev('guest'));
    final sink = FakeSink();
    store.attachRemote(sink);
    expect(store.events, isEmpty);
    expect(store.calendars, isNotEmpty);

    store.applyRemote(events: [_ev('cloud')]);
    expect(store.events.map((e) => e.id), ['cloud']);

    store.upsertEvent(_ev('new'));
    store.deleteEvent('cloud');
    store.upsertTask(TaskItem(id: 't1', title: 'x'));
    store.toggleTask('t1');
    expect(sink.log, [
      'putEvent new',
      'removeEvent cloud',
      'putTask t1',
      'putTask t1',
    ]);
    expect(store.guestDataCount.events, 1);

    // ログアウトすると端末内のデータに戻る
    store.detachRemote();
    expect(store.events.map((e) => e.id), ['guest']);
  });

  test('ゲスト用データをアカウントへ移すと端末内から消える', () async {
    final store = await AppStore.load();
    store.upsertEvent(_ev('g1'));
    store.upsertTask(TaskItem(id: 'gt', title: 'y'));
    store.addCalendar('部活', 0xFF13A10E);
    expect(store.hasGuestData, isTrue);

    final sink = FakeSink();
    store.attachRemote(sink);
    store.applyRemote(calendars: defaultCalendars(), events: [], tasks: []);
    store.moveGuestDataToRemote();

    expect(store.events.map((e) => e.id), ['g1']);
    expect(store.calendars.map((c) => c.name), contains('部活'));
    expect(sink.log, contains('putEvent g1'));
    expect(sink.log, contains('putTask gt'));
    expect(sink.log.where((l) => l.startsWith('putCalendar')).length, 1);
    expect(store.hasGuestData, isFalse);

    store.detachRemote();
    expect(store.events, isEmpty);
  });

  test('クラウドのカレンダーが空でも既定のカレンダーで動く', () async {
    final store = await AppStore.load();
    store.attachRemote(FakeSink());
    store.applyRemote(calendars: []);
    expect(store.calendars.map((c) => c.id), ['other', 'shift', 'lecture']);
  });

  test('設定はアカウントに送り、届いた設定は端末に反映する（送り返さない）', () async {
    final store = await AppStore.load();
    // ログインしていない間は送らない
    store.setThemeMode('dark');
    final sink = FakeSink();
    store.attachRemote(sink);
    store.setThemeMode('light');
    store.setWeekendColors(false);
    expect(sink.log.where((l) => l.startsWith('putSettings')).length, 2);
    expect(store.syncedSettings['weekendColors'], isFalse);

    sink.log.clear();
    store.applyRemoteSettings({
      'themeMode': 'dark',
      'weekStartsSunday': false,
      'weekendColors': true,
      'periods': [
        [540, 590],
        [600, 650]
      ],
      'remind': {'timed': 15, 'allDay': null},
    });
    expect(sink.log, isEmpty);
    expect(store.themeMode, 'dark');
    expect(store.weekStartsSunday, isFalse);
    expect(weekStartsOnSunday, isFalse);
    expect(startOfWeek(DateTime(2026, 11, 12)), DateTime(2026, 11, 9)); // 月曜始まり
    expect(store.periods, [(540, 590), (600, 650)]);
    expect(store.defaultReminder('timed'), 15);
    expect(store.defaultReminder('allDay'), isNull);
    store.setWeekStartsSunday(true);
    expect(startOfWeek(DateTime(2026, 11, 12)), DateTime(2026, 11, 8));
  });
}
