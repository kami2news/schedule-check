import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/store.dart';
import 'package:schedule_check/ui/fluent.dart';
import 'package:schedule_check/ui/fluent_extras.dart';
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

  test('グレーは場所で濃さを分ける: カレンダーの地は白より暗く、左の列・To Do はさらに濃く、カードは明るく浮く', () {
    final g = FlPalette.gray;
    expect(g.isGray, isTrue);
    double l(Color c) => c.computeLuminance();
    // カレンダーの地はハイライトを抑える（白・やわらかめより暗い）
    expect(l(g.wall), lessThan(l(FlPalette.soft.bg1)));
    // 横の列・To Do の枠はカレンダーの地より濃い（差をつける）
    expect(_contrast(g.wall, g.side), greaterThanOrEqualTo(1.5));
    expect(l(g.sidePane), lessThan(l(g.wall)));
    // カードはどの地の上でも明るく浮く
    for (final bg in [g.wall, g.side, g.sidePane]) {
      expect(l(g.bg1), greaterThan(l(bg)));
    }
    // 文字のコントラストは下げない（いちばん薄い文字・ブランド色も 4.5:1 以上）
    for (final bg in [g.bg1, g.bg2, g.bg3, g.bg4, g.wall, g.side, g.sidePane]) {
      expect(_contrast(g.fg3, bg), greaterThanOrEqualTo(4.5));
      expect(_contrast(g.brand, bg), greaterThanOrEqualTo(4.5));
    }
    // KM1 との突き合わせ: 操作要素の枠（stroke-strong）は 3:1、アイコンの線は 4.5:1、
    // 選択中の淡い紺はどの地とも見分けられる
    for (final bg in [g.bg1, g.wall, g.side, g.sidePane]) {
      expect(_contrast(g.strokeAccessible, bg), greaterThanOrEqualTo(3));
      expect(_contrast(g.km1.iconInk, bg), greaterThanOrEqualTo(4.5));
    }
    for (final bg in [g.bg1, g.wall, g.side]) {
      expect(_contrast(g.brandTint, bg), greaterThanOrEqualTo(1.2));
    }
    // 予定の塗りはカレンダーの地から浮き、文字は読める
    Fl.use(Brightness.light, gray: true);
    for (final c in const [Color(0xFF4F6BED), Color(0xFFCA5010), Color(0xFF038387), Color(0xFF13A10E)]) {
      final t = Fl.tint(c);
      expect(_contrast(t, g.wall), greaterThanOrEqualTo(1.05));
      expect(_contrast(g.fg1, t), greaterThanOrEqualTo(4.5));
      expect(_contrast(g.fg2, t), greaterThanOrEqualTo(4.5));
    }
    // 土日の色（左の列の小さなカレンダーにも出る）
    Fl.use(Brightness.light, gray: true);
    for (final d in [DateTime(2026, 11, 21), DateTime(2026, 11, 22)]) {
      for (final bg in [g.wall, g.side, g.sidePane]) {
        expect(_contrast(weekendFg(d)!, bg), greaterThanOrEqualTo(4.5));
      }
    }
    // 罫線がカレンダーの地に溶けない
    expect(_contrast(g.stroke2, g.wall), greaterThanOrEqualTo(1.2));
    // ライト・ダークは今までどおり
    expect(FlPalette.light.wall, FlPalette.light.bg1);
    expect(FlPalette.dark.side, FlPalette.dark.bg3);
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
