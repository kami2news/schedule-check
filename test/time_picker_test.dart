import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/ui/fluent_extras.dart';

void main() {
  Future<int?> open(WidgetTester tester, int initial,
      {List<int> extra = const [], Future<void> Function()? act}) async {
    int? result = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result =
                await showFlTimeList(context, initial, extra: extra, title: '終了時刻'),
            child: const Text('開く'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    if (act != null) await act();
    return result;
  }

  testWidgets('時刻は5分刻みで選べる', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final r = await open(tester, 9 * 60, act: () async {
      expect(find.text('終了時刻'), findsOneWidget);
      // 分の列は 00・05・10…
      expect(find.text('05'), findsOneWidget);
      expect(find.text('55', skipOffstage: false), findsOneWidget); // 分は 55 まで
      await tester.tap(find.text('05'));
      await tester.pumpAndSettle();
      expect(find.text('9:05'), findsOneWidget);
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
    });
    expect(r, 9 * 60 + 5);
  });

  testWidgets('23:59 はボタンで選べ、開いて決定しただけでは変わらない', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final kept = await open(tester, 23 * 60 + 59, extra: [23 * 60 + 59], act: () async {
      expect(find.text('23:59'), findsWidgets); // 大きな表示と、すぐ選べるボタン
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
    });
    expect(kept, 23 * 60 + 59);
    final picked = await open(tester, 9 * 60, extra: [23 * 60 + 59], act: () async {
      await tester.tap(find.widgetWithText(OutlinedButton, '23:59'));
      await tester.pumpAndSettle();
    });
    expect(picked, 23 * 60 + 59);
  });
}
