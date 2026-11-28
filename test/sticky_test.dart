import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/main.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('予定のメモを付箋として貼ると、カレンダーの上に出て自分の予定との重なりがわかる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final today = dateOnly(DateTime.now());
    store.upsertEvent(Event(
        id: 'a', title: '自分のバイト', calendarId: 'shift', date: today, startMin: 17 * 60, endMin: 22 * 60));
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('付箋を貼る（予定のメモ）'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byKey(ValueKey('sticky-text')), matching: find.byType(TextField)),
        '佐藤さんの予定\n今日 18:00〜20:00 飲み会\n明日 10:00 ゼミ');
    await tester.tap(find.text('貼る'));
    await tester.pumpAndSettle();

    expect(store.stickies.single.heading, '佐藤さんの予定');
    expect(find.text('佐藤さんの予定'), findsOneWidget); // 見出し
    expect(find.textContaining('重なる: 自分のバイト'), findsOneWidget);
    expect(find.textContaining('空いている'), findsOneWidget);
    // 登録はされない
    expect(store.events.length, 1);

    // 空いている予定を押すと本予定に入る（付箋の中は「登録済み」に）。元に戻せる
    await tester.tap(find.text('本予定に入れる').last);
    await tester.pumpAndSettle();
    expect(store.events.map((e) => e.title), contains('ゼミ'));
    expect(find.textContaining('登録済み'), findsWidgets);
    expect(find.text('本予定に入れる'), findsOneWidget); // 残りは重なる飲み会だけ
    await tester.tap(find.text('元に戻す'));
    await tester.pumpAndSettle();
    expect(store.events.length, 1);

    // 見出しをドラッグして動かすと位置が残る
    final before = (store.stickies.single.x, store.stickies.single.y);
    await tester.drag(find.text('佐藤さんの予定'), const Offset(-300, 120));
    await tester.pumpAndSettle();
    expect((store.stickies.single.x, store.stickies.single.y), isNot(before));

    // たたむと見出しと重なりの数だけ
    await tester.tap(find.byTooltip('たたむ'));
    await tester.pumpAndSettle();
    expect(find.text('重なり1'), findsOneWidget);
    expect(find.textContaining('飲み会'), findsNothing);

    // 再読み込みしても残る（この端末に保存）
    final again = await AppStore.load();
    expect(again.stickies.single.collapsed, isTrue);

    // はがす
    await tester.tap(find.byTooltip('付箋をはがす'));
    await tester.pumpAndSettle();
    expect(store.stickies, isEmpty);
  });
}
