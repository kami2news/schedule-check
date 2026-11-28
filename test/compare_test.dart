import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/compare.dart';
import 'package:schedule_check/main.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/sharing.dart';
import 'package:schedule_check/store.dart';
import 'package:schedule_check/ui/import_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('仮に置いた予定と自分の予定の重なり', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final d = DateTime(2026, 12, 2);
    store.upsertEvent(Event(id: 'a', title: 'バイト', calendarId: 'shift', date: d, startMin: 17 * 60, endMin: 22 * 60));
    store.upsertEvent(Event(id: 'b', title: '空き', calendarId: 'other', date: d, startMin: 9 * 60, endMin: 10 * 60, showAs: ShowAs.free));
    store.upsertEvent(Event(id: 'c', title: '帰省', calendarId: 'other', date: DateTime(2026, 12, 3)));
    store.setCompare('佐藤さんの予定', shareItemsToEvents([
      ShareItem(date: d, title: 'ゼミ', calendar: '授業', color: 0, start: 9 * 60, end: 10 * 60),
      ShareItem(date: d, title: '飲み会', calendar: '予定', color: 0, start: 21 * 60, end: 23 * 60),
      ShareItem(date: DateTime(2026, 12, 3), title: '映画', calendar: '予定', color: 0, start: 13 * 60, end: 15 * 60),
    ]));
    // 仮に置いた予定もカレンダーに出る（保存はされない）
    expect(store.eventsOn(d).map((e) => e.title), containsAll(['ゼミ', '飲み会', 'バイト']));
    expect(store.events.length, 3);
    expect(store.calendarOf(kCompareCalendarId).name, '佐藤さんの予定');
    expect(store.canEditEvent(store.compareEvents.first), isFalse);
    final rows = compareWith(store.compareEvents, store.eventsOn);
    // 自分の「空き時間」は重なりに数えない
    expect(rows.map((r) => '${r.item.title}:${r.mine.map((m) => m.title).join(',')}').toList(),
        ['ゼミ:', '飲み会:バイト', '映画:']);
    expect(rows[2].mineAllDay.single.title, '帰省');
    // 仮に置いた予定は変えられない・消せない
    store.deleteEvent(store.compareEvents.first.id);
    expect(store.compareEvents.length, 3);
    // 仮の予定を本予定に入れると、仮の分は外れ、比べた結果は「登録済み」になる
    final film = store.compareEvents.firstWhere((e) => e.title == '映画');
    final real = store.promote(film);
    expect(store.events.any((e) => e.id == real.id && e.title == '映画' && e.startMin == 13 * 60), isTrue);
    expect(store.compareEvents.length, 2);
    final again = compareWith([film], store.eventsOn);
    expect(again.single.registered?.id, real.id);
    expect(again.single.conflicts, isFalse);
    store.deleteEvent(real.id);
    store.clearCompare();
    expect(store.eventsOn(d).map((e) => e.title).toSet(), {'バイト', '空き'});
  });

  testWidgets('貼り付けた予定を登録せずに仮に置いて比べる・共有リンクを貼っても比べられる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final today = dateOnly(DateTime.now());
    store.upsertEvent(Event(id: 'a', title: '自分のバイト', calendarId: 'shift', date: today, startMin: 10 * 60, endMin: 12 * 60));
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('メールなどから取り込む'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        '今日 11:00-13:00 打ち合わせ');
    await tester.tap(find.text('解析する'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('登録せずに仮に置いて比べる'), 200,
        scrollable: find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('登録せずに仮に置いて比べる'));
    await tester.pumpAndSettle();
    expect(store.events.length, 1); // 登録はしない
    expect(find.textContaining('「貼り付けた予定」を仮に置いて比べています（1件・重なり1件）'), findsOneWidget);
    await tester.tap(find.text('一覧'));
    await tester.pumpAndSettle();
    expect(find.textContaining('重なる: 自分のバイト'), findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('比べるのを終える'));
    await tester.pumpAndSettle();
    expect(find.textContaining('比べています'), findsNothing);

    // 共有リンクを貼る
    ImportPage.shareLoader = (t) async => (ownerName: '佐藤', items: [
          ShareItem(date: today, title: 'ゼミ', calendar: '授業', color: 0, start: 15 * 60, end: 16 * 60),
        ]);
    await tester.tap(find.text('メールなどから取り込む'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        'https://example.github.io/schedule-check/?share=abcdefgh12345678');
    await tester.tap(find.text('解析する'));
    await tester.pumpAndSettle();
    expect(find.textContaining('「佐藤さんの予定」を仮に置いて比べています（1件・重なりなし）'), findsOneWidget);
  });
}
