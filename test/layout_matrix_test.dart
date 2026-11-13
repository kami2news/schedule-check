// 画面サイズごとの表示エラーの検査（折りたたみスマホ・小さいスマホ・横向き・タブレット・PC）。
// 各サイズで、タッチの端末（部品 44px 以上）とマウスの端末（32px）の両方を開き、
// 主な画面を順に巡って、はみ出し（RenderFlex overflowed）などの例外が出ないことを確かめる。
// 折りたたみ端末は、使っている途中で開く・閉じる（画面の大きさが変わる）ときも確かめる。
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/main.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/store.dart';
import 'package:schedule_check/ui/time_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 表示がきつくなりやすいデータ（長い題名・日をまたぐ予定・重なり・終日がたくさん）
Future<AppStore> _stressStore() async {
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
      place: '理学部III号館 201教室'));
  store.upsertEvent(Event(
      id: 'e2',
      title: 'とても長い題名の予定（第7回 環境統計基礎 期末レポートの相談と発表資料の確認）',
      calendarId: 'other',
      date: today,
      startMin: 10 * 60 + 30,
      endMin: 12 * 60,
      url: 'https://zoom.us/j/1'));
  store.upsertEvent(Event(
      id: 'e3',
      title: '重なる予定',
      date: today,
      startMin: 10 * 60 + 40,
      endMin: 10 * 60 + 55));
  store.upsertEvent(Event(
      id: 'e4',
      title: 'ビッグサイト 夜勤',
      calendarId: 'shift',
      date: today,
      startMin: 23 * 60,
      endMin: 5 * 60,
      endOffset: 1));
  store.upsertEvent(Event(
      id: 'e5', title: '学園祭', date: addDays(today, 1), endOffset: 2));
  for (var i = 0; i < 6; i++) {
    store.upsertTask(TaskItem(
        id: 't$i',
        title: i == 0 ? 'とても長いタスクの題名（奨学金の継続手続きの書類を学生課に提出する）' : 'タスク $i',
        due: today,
        important: i.isEven,
        dueMin: i == 1 ? 23 * 60 + 59 : null));
  }
  return store;
}

const _sizes = <String, Size>{
  'iPhone SE（320×568）': Size(320, 568),
  'iPhone（393×852）': Size(393, 852),
  'Galaxy Z Fold 閉じた状態（344×882）': Size(344, 882),
  'Galaxy Z Fold 開いた状態（673×841）': Size(673, 841),
  'Galaxy Z Fold 開いた状態・横（841×673）': Size(841, 673),
  'Galaxy Z Flip カバー画面（360×374）': Size(360, 374),
  'Pixel Fold 開いた状態（841×701）': Size(841, 701),
  'スマホ横向き（844×390）': Size(844, 390),
  'iPad mini 縦（744×1133）': Size(744, 1133),
  'iPad 横（1180×820）': Size(1180, 820),
  'タブレット 横（1024×768）': Size(1024, 768),
  'PC 境目（1100×700）': Size(1100, 700),
  'PC（1366×768）': Size(1366, 768),
  'PC（1920×1080）': Size(1920, 1080),
};

/// 開いているダイアログ・画面を閉じる
Future<void> _closeTop(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  await nav.maybePop();
  await tester.pumpAndSettle();
}

Future<void> _pickView(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('表示形式'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
      of: find.byType(PopupMenuItem<String>), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// 主な画面を順に巡る
Future<void> _tour(WidgetTester tester, Size size) async {
  final wide = size.width >= 1100;
  final grid =
      find.descendant(of: find.byType(TimeGrid), matching: find.byType(ListView));

  // カレンダー: 日・3日・週・月
  for (final v in ['日', '3日', '週', '月']) {
    await _pickView(tester, v);
    if (v != '月' && grid.evaluate().isNotEmpty) {
      // 夜の予定（日をまたぐ部分）まで縦にスクロール
      await tester.drag(grid.first, const Offset(0, -900), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
  }
  await _pickView(tester, '日');

  // 予定のプレビュー
  final ev = find.textContaining('テスト授業');
  if (ev.evaluate().isNotEmpty) {
    await tester.tap(ev.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    await _closeTop(tester);
  }

  // 予定の追加（編集画面）
  await tester.tap(
      wide ? find.text('新しい予定') : find.byTooltip('予定を追加'));
  await tester.pumpAndSettle();
  await _closeTop(tester);

  if (wide) {
    await tester.tap(find.text('メールなどから取り込む'));
    await tester.pumpAndSettle();
    await _closeTop(tester);
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    await _closeTop(tester);
  } else {
    // 下のナビ: To Do・取り込み・カレンダー
    await tester.tap(find.text('To Do').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('詳しく入力'));
    await tester.pumpAndSettle();
    await _closeTop(tester);
    await tester.tap(find.text('取り込み').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('カレンダー').last);
    await tester.pumpAndSettle();
    // その他 → 設定
    await tester.tap(find.byTooltip('その他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定').last);
    await tester.pumpAndSettle();
    await _closeTop(tester);
  }
}

void main() {
  for (final touch in [true, false]) {
    final kind = touch ? 'タッチ' : 'マウス';
    for (final MapEntry(key: name, value: size) in _sizes.entries) {
      testWidgets('表示エラーなし: $name・$kind', (tester) async {
        debugDefaultTargetPlatformOverride =
            touch ? TargetPlatform.android : TargetPlatform.windows;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final store = await _stressStore();
        await tester.pumpWidget(ScheduleApp(store: store));
        await tester.pumpAndSettle();
        await _tour(tester, size);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  // 折りたたみ端末: 使っている途中で開く・閉じる
  final folds = <String, (Size, Size)>{
    'Galaxy Z Fold': (Size(344, 882), Size(673, 841)),
    'Pixel Fold': (Size(412, 900), Size(841, 701)),
    'Galaxy Z Flip（カバー画面 ↔ 開いた状態）': (Size(360, 374), Size(412, 915)),
  };
  for (final MapEntry(key: name, value: (closed, open)) in folds.entries) {
    testWidgets('表示エラーなし: $name を開く・閉じる', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = closed;
      addTearDown(tester.view.reset);
      final store = await _stressStore();
      await tester.pumpWidget(ScheduleApp(store: store));
      await tester.pumpAndSettle();
      for (final v in ['日', '週', '月', '3日']) {
        await _pickView(tester, v);
        tester.view.physicalSize = open;
        await tester.pumpAndSettle();
        tester.view.physicalSize = closed;
        await tester.pumpAndSettle();
      }
      // 編集画面を開いたまま開く・閉じる
      await tester.tap(find.byTooltip('予定を追加'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = open;
      await tester.pumpAndSettle();
      tester.view.physicalSize = closed;
      await tester.pumpAndSettle();
      await _closeTop(tester);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
