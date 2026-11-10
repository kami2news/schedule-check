import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/main.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/store.dart';
import 'package:schedule_check/ui/controller.dart';
import 'package:schedule_check/ui/fluent.dart';
import 'package:schedule_check/ui/fluent_extras.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _storeWithSamples() async {
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.load();
  final today = dateOnly(DateTime.now());
  store.upsertEvent(Event(
    id: 'e1',
    title: 'テスト授業',
    calendarId: 'lecture',
    date: today,
    startMin: 10 * 60,
    endMin: 11 * 60,
  ));
  store.upsertEvent(Event(
    id: 'e2',
    title: '重なる予定',
    calendarId: 'other',
    date: today,
    startMin: 10 * 60 + 30,
    endMin: 12 * 60,
  ));
  store.upsertTask(TaskItem(id: 't1', title: 'レポート提出', due: today));
  return store;
}

void main() {
  test('週の開始は日曜で、週表示のタイトルと移動が正しい', () {
    expect(startOfWeek(DateTime(2026, 11, 10)), DateTime(2026, 11, 8));
    final c = CalendarController(view: CalView.week);
    c.select(DateTime(2026, 11, 10));
    expect(c.title, '2026年11月8日 – 14日');
    c.step(1);
    expect(c.selected, DateTime(2026, 11, 17));
  });

  test('月移動は月末を丸める', () {
    final c = CalendarController(view: CalView.month);
    c.select(DateTime(2026, 1, 31));
    c.step(1);
    expect(c.selected, DateTime(2026, 2, 28));
  });

  testWidgets('広い画面: サイドバー・週ビュー・To Do が表示される', (tester) async {
    final store = await _storeWithSamples();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('新しい予定'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.textContaining('テスト授業'), findsOneWidget);
    expect(find.textContaining('重なる予定'), findsOneWidget);
    expect(find.text('レポート提出'), findsWidgets);

    // 月表示に切り替えても例外が出ない
    await tester.tap(find.byType(PopupMenuButton<CalView>));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(PopupMenuItem<CalView>),
      matching: find.text('月'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('テスト授業'), findsOneWidget);
  });

  testWidgets('狭い画面: 日ビューとタブ切り替え', (tester) async {
    final store = await _storeWithSamples();
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();

    expect(find.textContaining('テスト授業'), findsOneWidget);

    await tester.tap(find.text('To Do'));
    await tester.pumpAndSettle();
    expect(find.text('レポート提出'), findsWidgets);

    await tester.tap(find.text('取り込み').last);
    await tester.pumpAndSettle();
    expect(find.text('解析する'), findsOneWidget);
  });

  testWidgets('To Do のクイック追加でタスクが増える', (tester) async {
    final store = await _storeWithSamples();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '買い物');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.tasks.any((t) => t.title == '買い物'), isTrue);
  });

  testWidgets('ダークモードに切り替えて保存される', (tester) async {
    final store = await _storeWithSamples();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => Fl.use(Brightness.light));

    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();
    expect(Fl.isDark, isFalse);

    await tester.tap(find.byType(FlThemeButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ダーク'));
    await tester.pumpAndSettle();

    expect(Fl.isDark, isTrue);
    expect(store.themeMode, 'dark');
    expect(find.textContaining('テスト授業'), findsOneWidget);
  });

  testWidgets('カレンダーを追加して非表示にできる', (tester) async {
    final store = await _storeWithSamples();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('カレンダーを追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '部活');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.calendars.any((c) => c.name == '部活'), isTrue);
    expect(find.text('部活'), findsOneWidget);

    // 「授業」を非表示にするとテスト授業が消える
    await tester.tap(find.text('授業'));
    await tester.pumpAndSettle();
    expect(find.textContaining('テスト授業'), findsNothing);
  });

  testWidgets('エラーは入力を直した時点で消え、無効なリンクは保存できない', (tester) async {
    final store = await _storeWithSamples();
    // 編集画面の項目がすべて画面内に収まる高さにする（リスト外は作られないため）
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新しい予定'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('タイトルを入力してください'), findsOneWidget);

    final fields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(fields.first, '面談');
    await tester.pumpAndSettle();
    expect(find.text('タイトルを入力してください'), findsNothing);

    // リンク欄（場所の次）に無効な値
    await tester.enterText(fields.at(2), 'not-a-url');
    await tester.pumpAndSettle();
    expect(find.textContaining('有効なURLを入力してください'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('リンクの形式が正しくありません'), findsOneWidget);
    expect(store.events.any((e) => e.title == '面談'), isFalse);

    await tester.enterText(fields.at(2), 'zoom.us/j/1');
    await tester.pumpAndSettle();
    expect(find.text('リンクの形式が正しくありません'), findsNothing);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.events.singleWhere((e) => e.title == '面談').url,
        'https://zoom.us/j/1');
  });

  testWidgets('狭い画面の週表示は横スクロールになり、表示形式は再読込後も残る',
      (tester) async {
    final store = await _storeWithSamples();
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<CalView>));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(PopupMenuItem<CalView>),
      matching: find.text('週'),
    ));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(store.uiValue('view'), 'week');

    // 作り直しても週表示のまま
    await tester.pumpWidget(SizedBox());
    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('週'), findsOneWidget);
  });
}
