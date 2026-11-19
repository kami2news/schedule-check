import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/main.dart';
import 'package:schedule_check/store.dart';
import 'package:schedule_check/ui/swipe_guard.dart';
import 'package:schedule_check/ui/time_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('横スライドの直後に来たブラウザの戻るは受け流す。時間が空けば今までどおり', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.setUiValue('view', 'week');
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var t = DateTime(2026, 11, 19, 12);
    SwipeGuard.now = () => t;
    SwipeGuard.reset();
    addTearDown(() => SwipeGuard.now = DateTime.now);
    var exits = 0;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();

    // 横に払った直後の「戻る」→ アプリを出ない
    await tester.fling(find.byType(TimeGrid), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(SwipeGuard.recent, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exits, 0);

    // しばらく経ってからの「戻る」は今までどおり
    t = t.add(const Duration(seconds: 2));
    expect(SwipeGuard.recent, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(exits, 1);

    // 縦のスクロールでは見張らない
    await tester.drag(find.byType(TimeGrid), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(SwipeGuard.recent, isFalse);

    // 画面の端で触れ始めた（iPhone の端からのスワイプ）→ 見張る
    final g = await tester.startGesture(const Offset(5, 400));
    await g.up();
    expect(SwipeGuard.recent, isTrue);
  });
}
