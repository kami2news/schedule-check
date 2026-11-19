import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/store.dart';
import 'package:schedule_check/ui/fluent.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('ライトの「やわらかめ」は白を抑えつつ、薄い文字でも 4.5:1 以上', () {
    final p = FlPalette.soft;
    expect(p.bg1, isNot(const Color(0xFFFFFFFF)));
    for (final bg in [p.bg1, p.bg2, p.bg3, p.bg4]) {
      expect(_contrast(p.fg3, bg), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.fg1, bg), greaterThanOrEqualTo(4.5));
    }
    // 30分の補助線が面に溶けない
    expect(p.stroke3, isNot(p.bg1));
  });

  test('「やわらかめ」が既定で、設定で標準（白）に戻せる', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    expect(store.softLight, isTrue);
    store.setSoftLight(false);
    expect(store.softLight, isFalse);
    expect(store.syncedSettings['softLight'], isFalse);
    Fl.use(Brightness.light, soft: true);
    expect(Fl.bg1, FlPalette.soft.bg1);
    Fl.use(Brightness.light);
    expect(Fl.bg1, const Color(0xFFFFFFFF));
  });

  test('グレーはライトとダークの間。薄い文字・ブランド色も 4.5:1 以上', () {
    final g = FlPalette.gray;
    expect(g.isGray, isTrue);
    expect(g.bg1.computeLuminance(), lessThan(FlPalette.soft.bg1.computeLuminance()));
    expect(g.bg1.computeLuminance(), greaterThan(FlPalette.dark.bg1.computeLuminance()));
    for (final bg in [g.bg1, g.bg2, g.bg3, g.bg4]) {
      expect(_contrast(g.fg3, bg), greaterThanOrEqualTo(4.5));
      expect(_contrast(g.brand, bg), greaterThanOrEqualTo(4.5));
    }
    Fl.use(Brightness.light, gray: true);
    expect(Fl.isGray, isTrue);
    expect(Fl.isDark, isFalse);
    Fl.use(Brightness.light);
  });

  test('システムに合わせるとき、明るい側をグレーにできる（アカウントに保存）', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    expect(store.systemLightGray, isFalse);
    store.setSystemLightGray(true);
    expect(store.syncedSettings['systemLightGray'], isTrue);
    store.setThemeMode('gray');
    expect(store.themeMode, 'gray');
  });
}
