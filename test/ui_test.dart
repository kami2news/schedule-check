import 'package:material_ui/material_ui.dart';
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

  Future<void> pumpWide(WidgetTester tester, AppStore store) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();
  }

  testWidgets('予定を押すとプレビューが開き、関連タスクが見える', (tester) async {
    final store = await _storeWithSamples();
    store.upsertTask(TaskItem(
        id: 't2', title: '持ち物を準備', due: dateOnly(DateTime.now()), eventId: 'e1'));
    await pumpWide(tester, store);

    // To Do のカードに、ひも付いている予定の名前が出る
    expect(find.text('テスト授業').evaluate().length, greaterThanOrEqualTo(2));

    await tester.tap(find.textContaining('テスト授業').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('編集'), findsOneWidget);
    expect(find.text('持ち物を準備'), findsWidgets);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('編集'), findsNothing);
  });

  testWidgets('検索・空き時間・設定が開ける', (tester) async {
    final store = await _storeWithSamples();
    await pumpWide(tester, store);

    await tester.tap(find.text('検索'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        'テスト');
    await tester.pumpAndSettle();
    expect(find.text('これからの予定'), findsOneWidget);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('空き時間の候補をコピー'));
    await tester.pumpAndSettle();
    expect(find.text('予定として数えるカレンダー'), findsOneWidget);
    expect(find.textContaining('コピー'), findsWidgets);
    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('最初から付ける通知'), findsOneWidget);
    expect(find.text('時刻のある予定'), findsOneWidget);
    expect(find.textContaining('この端末にだけ保存'), findsOneWidget);

    // 土日の色分けを切り替えると、すぐ設定に反映される
    expect(store.weekendColors, isTrue);
    await tester.tap(find.text('土日を色分けする（土曜は青、日曜は赤）'));
    await tester.pumpAndSettle();
    expect(store.weekendColors, isFalse);
  });

  testWidgets('To Do: 入力中の内容を引き継いで詳しい入力画面を開き、予定に関連付けて保存できる',
      (tester) async {
    final store = await _storeWithSamples();
    await pumpWide(tester, store);

    await tester.enterText(
        find.widgetWithText(TextField, 'タスクを追加'), 'プリントを印刷');
    await tester.tap(find.byKey(const ValueKey('task-detail')));
    await tester.pumpAndSettle();
    // タイトルが引き継がれ、マイデイなので期限は今日
    expect(find.text('タスクを追加'), findsWidgets);
    expect(
        find.descendant(
            of: find.byType(Dialog),
            matching: find.byWidgetPredicate(
                (w) => w is TextField && w.controller?.text == 'プリントを印刷')),
        findsOneWidget);
    expect(find.text(fmtLongDate(dateOnly(DateTime.now()))), findsWidgets);

    // 予定に関連付ける
    await tester.tap(find.text('予定に関連付ける（持ち物・準備・報告など）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('テスト授業').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('関連する予定: テスト授業'), findsOneWidget);

    // 重要にして保存
    await tester.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('重要')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final t = store.tasks.singleWhere((t) => t.title == 'プリントを印刷');
    expect(t.important, isTrue);
    expect(t.eventId, 'e1');
    expect(t.due, dateOnly(DateTime.now()));
  });

  testWidgets('取り込み: 貼り付けた文章から候補が出る（時限・締め切り）', (tester) async {
    final store = await _storeWithSamples();
    await pumpWide(tester, store);

    await tester.tap(find.text('メールなどから取り込む'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
        '12/1 3限 環境化学 補講\n提出期限：12月5日 0:00 実験レポート');
    await tester.tap(find.text('解析する'));
    await tester.pumpAndSettle();
    expect(find.textContaining('環境化学'), findsWidgets);
    expect(find.textContaining('実験レポート'), findsWidgets);
    // 3限 → 13:00、0:00 締め切り → 前日（12/4）の終日
    expect(find.textContaining('13:00'), findsWidgets);
    expect(find.textContaining('12/4'), findsWidgets);
  });

  testWidgets('時刻つきの締め切りは、時間の欄に印が出る', (tester) async {
    final store = await _storeWithSamples();
    final today = dateOnly(DateTime.now());
    store.upsertTask(TaskItem(id: 'd1', title: '書類を出す', due: today, dueMin: 15 * 60));
    store.upsertTask(
        TaskItem(id: 'd2', title: '申込みをする', due: today, dueMin: 15 * 60 + 5));
    await pumpWide(tester, store);
    // 終日欄のチップと、時間の欄の札の両方に時刻つきで出る
    expect(find.text('15:00 書類を出す').evaluate().length, 2);
    expect(find.text('15:05 申込みをする').evaluate().length, 2);
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
    tester.view.physicalSize = const Size(1400, 900);
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

    // リンク欄に無効な値（編集画面をスクロールして表示させる）
    final link = find.descendant(
        of: find.byKey(const ValueKey('link-field')),
        matching: find.byType(TextField));
    Future<void> showLink() async {
      await tester.scrollUntilVisible(link, 200,
          scrollable: find
              .descendant(
                  of: find.byType(Dialog), matching: find.byType(Scrollable))
              .first);
      // 欄を画面の上端まで寄せて、下に出るエラー文も作られるようにする
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
    }

    await showLink();
    await tester.enterText(link, 'not-a-url');
    await tester.pumpAndSettle();
    await showLink();
    expect(tester.widget<TextField>(link).controller!.text, 'not-a-url');
    expect(find.textContaining('有効なURLを入力してください'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('リンクの形式が正しくありません'), findsOneWidget);
    expect(store.events.any((e) => e.title == '面談'), isFalse);

    await showLink();
    await tester.enterText(link, 'zoom.us/j/1');
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
