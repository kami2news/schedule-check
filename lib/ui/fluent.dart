import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../km1/km1_theme.dart';

export '../km1/km1_icons_b.dart';
export '../km1/km1_theme.dart';

/// 色のトークン一式（ライト／ダーク）。KM1 の Km1Colors から作る（[FlPalette.fromKm1]）。
class FlPalette {
  const FlPalette({
    required this.brightness,
    required this.km1,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.fgDisabled,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.bg4,
    required this.bg5,
    required this.bg6,
    required this.stroke1,
    required this.stroke1Hover,
    required this.stroke2,
    required this.stroke3,
    required this.strokeAccessible,
    required this.brand,
    required this.brandHover,
    required this.brandPressed,
    required this.brandFg,
    required this.brandTint,
    required this.danger,
    required this.dangerLine,
    required this.warning,
    required this.success,
    required this.topBar,
    required this.subtleHover,
    required this.subtlePressed,
  });

  final Brightness brightness;
  final Color fg1, fg2, fg3, fgDisabled;
  final Color bg1, bg2, bg3, bg4, bg5, bg6;
  final Color stroke1, stroke1Hover, stroke2, stroke3, strokeAccessible;

  /// 塗り（ボタン・今日の丸など）に使うブランド色
  final Color brand, brandHover, brandPressed;

  /// 文字・アイコン・線に使うブランド色（ダークでは明るめ）
  final Color brandFg;

  /// 淡いブランド背景（選択中など）
  final Color brandTint;
  final Color danger, dangerLine, warning, success;
  final Color topBar;
  final Color subtleHover, subtlePressed;

  /// KM1 の意味づけトークン（Km1Colors）からパレットを作る。値の正は lib/km1/km1_theme.dart。
  /// アプリ独自の面（bg5・bg6・上部バーなど）だけここで足す。
  factory FlPalette.fromKm1(Km1Colors k, Brightness b) {
    final dark = b == Brightness.dark;
    return FlPalette(
      brightness: b,
      km1: k,
      fg1: k.ink,
      fg2: k.inkSecondary,
      fg3: k.inkTertiary,
      fgDisabled: k.inkDisabled,
      bg1: k.surface,
      bg2: k.surfaceSubtle,
      bg3: k.surfaceMuted,
      bg4: k.surfaceSunken,
      bg5: dark ? Color(0xFF000000) : Color(0xFFEBEBEB),
      bg6: dark ? Color(0xFF333333) : Color(0xFFE6E6E6),
      stroke1: k.stroke,
      stroke1Hover: dark ? Color(0xFF757575) : Color(0xFFC7C7C7),
      stroke2: k.strokeSubtle,
      stroke3: dark ? Color(0xFF3D3D3D) : Color(0xFFF0F0F0),
      strokeAccessible: k.strokeStrong,
      brand: k.brand,
      brandHover: k.brandHover,
      brandPressed: k.brandPressed,
      brandFg: k.brandInk,
      brandTint: k.brandTint,
      danger: k.dangerInk,
      dangerLine: k.dangerInk,
      warning: k.warningInk,
      success: k.successInk,
      // 上部バー: ライトはブランドの紺、ダークは一番沈んだ面
      topBar: dark ? k.surfaceSunken : k.brand,
      subtleHover: k.surfaceHover,
      subtlePressed: k.surfacePressed,
    );
  }

  /// KM1 の色一式（アイコンの線・面、情報色、フォーカスの枠など）
  final Km1Colors km1;

  static final light = FlPalette.fromKm1(Km1Colors.light, Brightness.light);
  static final dark = FlPalette.fromKm1(Km1Colors.dark, Brightness.dark);
}

/// アプリ全体のテーマ設定（システムに合わせる／ライト／ダーク）
enum FlThemeMode { system, light, dark }

extension FlThemeModeX on FlThemeMode {
  String get label => switch (this) {
        FlThemeMode.system => 'システムに合わせる',
        FlThemeMode.light => 'ライト',
        FlThemeMode.dark => 'ダーク',
      };
}

/// Fluent 2 のデザイントークン。色は現在のパレット（ライト／ダーク）から返す。
class Fl {
  Fl._();

  static FlPalette _p = FlPalette.light;
  static FlPalette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;

  /// パレットを切り替える（呼び出し側で画面全体を再構築すること）
  static void use(Brightness b) =>
      _p = b == Brightness.dark ? FlPalette.dark : FlPalette.light;

  static Color get fg1 => _p.fg1;
  static Color get fg2 => _p.fg2;
  static Color get fg3 => _p.fg3;
  static Color get fgDisabled => _p.fgDisabled;
  static Color get bg1 => _p.bg1;
  static Color get bg2 => _p.bg2;
  static Color get bg3 => _p.bg3;
  static Color get bg4 => _p.bg4;
  static Color get bg5 => _p.bg5;
  static Color get bg6 => _p.bg6;
  static Color get stroke1 => _p.stroke1;
  static Color get stroke1Hover => _p.stroke1Hover;
  static Color get stroke2 => _p.stroke2;
  static Color get stroke3 => _p.stroke3;
  static Color get strokeAccessible => _p.strokeAccessible;
  static Color get brand => _p.brand;
  static Color get brandHover => _p.brandHover;
  static Color get brandPressed => _p.brandPressed;
  static Color get brandFg => _p.brandFg;
  static Color get brandTint => _p.brandTint;
  static Color get danger => _p.danger;
  static Color get dangerLine => _p.dangerLine;
  static Color get warning => _p.warning;
  static Color get success => _p.success;
  static Color get topBar => _p.topBar;
  static Color get subtleHover => _p.subtleHover;
  static Color get subtlePressed => _p.subtlePressed;

  /// KM1 の色一式
  static Km1Colors get km1 => _p.km1;

  // ---- 操作領域（KM1-TOK-001-D）: 部品の高さは端末で切り替える ----
  /// タッチが主な端末か（iPhone・Android。Web でも端末の OS で決まる）
  static bool touchOverride = false;
  static bool get touch => touchOverride || Km1Theme.isTouch;

  /// 部品の高さ。Web は KM1 の決まりどおりタッチ 44px・マウス 32px、
  /// アプリでは Android 48dp・iOS 44pt・PC 32px
  static double get target => kIsWeb
      ? (touch ? Km1PlatformTarget.webTouch : Km1PlatformTarget.webMouse)
      : (touch && Km1Theme.targetFor(defaultTargetPlatform) < kKm1Target
          ? kKm1Target
          : Km1Theme.targetFor(defaultTargetPlatform));

  /// 小さいボタン（PC 24px。タッチでは押せる範囲を target まで広げる）
  static double get targetSmall => touch ? target : Km1Size.controlSm;

  // ---- Corner radius ----
  static const double r2 = 2;
  static const double r4 = 4;
  static const double r6 = 6;
  static const double r8 = 8;
  static const double r12 = 12;

  // ---- Elevation (key + ambient)。ダークでは影を濃くする ----
  static List<BoxShadow> _shadow(double blur, double y) {
    final amb = isDark ? Color(0x3D000000) : Color(0x1F000000);
    final key = isDark ? Color(0x47000000) : Color(0x24000000);
    return [
      BoxShadow(color: amb, blurRadius: 2),
      BoxShadow(color: key, blurRadius: blur, offset: Offset(0, y)),
    ];
  }

  static List<BoxShadow> get shadow2 => _shadow(2, 1);
  static List<BoxShadow> get shadow4 => _shadow(4, 2);
  static List<BoxShadow> get shadow8 => _shadow(8, 4);
  static List<BoxShadow> get shadow16 => _shadow(16, 8);
  static List<BoxShadow> get shadow64 => [
        BoxShadow(
            color: isDark ? Color(0x47000000) : Color(0x33000000),
            blurRadius: 8),
        BoxShadow(
            color: isDark ? Color(0x57000000) : Color(0x3D000000),
            blurRadius: 64,
            offset: Offset(0, 32)),
      ];

  /// 色の薄い塗り（イベントの背景など）。ダークでは少し濃くする
  static Color tint(Color c, [double? alpha]) => Color.alphaBlend(
      c.withValues(alpha: alpha ?? (isDark ? 0.32 : 0.14)), bg1);
}

/// KM1 の文字の型（Km1Text と同じ大きさ・行の高さ）。
/// 書体は KM1 の決まりどおり Noto Sans JP（アプリは日本語 lang="ja"）。英数字は同梱の切り出し版、
/// 日本語の字形は Web では Flutter が自動で読み込む Noto Sans JP、アプリでは KM1 の順の OS の書体。
class FlText {
  FlText._();

  static const family = Km1Text.fontFamily;
  static const fallback = Km1Text.fontFamilyFallback;

  static TextStyle _s(double size, double lineHeight, FontWeight w) =>
      TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: w,
        color: Fl.fg1,
      );

  static TextStyle get caption2 => _s(10, 14, FontWeight.w400);
  static TextStyle get caption1 => _s(12, 16, FontWeight.w400);
  static TextStyle get caption1Strong => _s(12, 16, FontWeight.w600);
  static TextStyle get body1 => _s(14, 20, FontWeight.w400);
  static TextStyle get body1Strong => _s(14, 20, FontWeight.w600);
  static TextStyle get body2 => _s(16, 22, FontWeight.w400);

  /// 入力欄の文字（KM1: タッチ 16px、PC 14px）
  static TextStyle get field => Fl.touch ? body2 : body1;
  static TextStyle get subtitle2 => _s(16, 22, FontWeight.w600);
  static TextStyle get subtitle1 => _s(20, 28, FontWeight.w600);
  static TextStyle get title3 => _s(24, 32, FontWeight.w600);
}

/// 現在のパレット（[Fl.use] で選んだもの）から ThemeData を作る
ThemeData buildFluentTheme() {
  final scheme = ColorScheme.fromSeed(
          seedColor: Fl.brand, brightness: Fl.palette.brightness)
      .copyWith(
    primary: Fl.brand,
    onPrimary: Colors.white,
    primaryContainer: Fl.brandTint,
    onPrimaryContainer: Fl.brandFg,
    surface: Fl.bg1,
    onSurface: Fl.fg1,
    onSurfaceVariant: Fl.fg2,
    outline: Fl.stroke1,
    outlineVariant: Fl.stroke2,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: Fl.bg1,
    surfaceContainerLow: Fl.bg2,
    surfaceContainer: Fl.bg3,
    surfaceContainerHigh: Fl.bg4,
    surfaceContainerHighest: Fl.bg5,
    error: Fl.danger,
  );

  final textTheme = TextTheme(
    displaySmall: FlText.title3,
    headlineSmall: FlText.title3,
    titleLarge: FlText.subtitle1,
    titleMedium: FlText.subtitle2,
    titleSmall: FlText.body1Strong,
    bodyLarge: FlText.body1,
    bodyMedium: FlText.body1,
    bodySmall: FlText.caption1,
    labelLarge: FlText.body1Strong,
    labelMedium: FlText.caption1Strong,
    labelSmall: FlText.caption2,
  );

  final r4 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Fl.r4));

  // KM1: キーボードのフォーカスは focus-ring 色の 2px の枠
  BorderSide? focusSide(Set<WidgetState> s) => s.contains(WidgetState.focused)
      ? BorderSide(color: Fl.km1.focusRing, width: 2)
      : null;

  Color? subtleBg(Set<WidgetState> s) {
    if (s.contains(WidgetState.pressed)) return Fl.subtlePressed;
    if (s.contains(WidgetState.hovered)) return Fl.subtleHover;
    return Colors.transparent;
  }

  return ThemeData(
    useMaterial3: true,
    brightness: Fl.palette.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: Fl.bg1,
    canvasColor: Fl.bg1,
    fontFamily: FlText.family,
    fontFamilyFallback: FlText.fallback,
    textTheme: textTheme,
    // KM1 の色（Km1BIcon などの KM1 の部品が使う）
    extensions: [Fl.km1],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize:
        Fl.touch ? MaterialTapTargetSize.padded : MaterialTapTargetSize.shrinkWrap,
    // Fluent の入場モーション（短いフェード + わずかな上方向スライド）
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      TargetPlatform.android: _Km1PageTransitions(),
      TargetPlatform.iOS: _Km1PageTransitions(),
      TargetPlatform.macOS: _Km1PageTransitions(),
      TargetPlatform.windows: _Km1PageTransitions(),
      TargetPlatform.linux: _Km1PageTransitions(),
      TargetPlatform.fuchsia: _Km1PageTransitions(),
    }),
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    hoverColor: Fl.isDark ? Color(0x14FFFFFF) : Color(0x0A000000),
    highlightColor:
        Fl.isDark ? Color(0x1FFFFFFF) : Color(0x14000000),
    dividerTheme: DividerThemeData(
        color: Fl.stroke2, thickness: 1, space: 1),
    // プライマリ
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        elevation: WidgetStatePropertyAll(0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(64, Fl.target)),
        padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12)),
        shape: WidgetStatePropertyAll(r4),
        textStyle: WidgetStatePropertyAll(FlText.body1Strong),
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? Fl.fgDisabled : Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return Fl.bg4;
          if (s.contains(WidgetState.pressed)) return Fl.brandPressed;
          if (s.contains(WidgetState.hovered)) return Fl.brandHover;
          return Fl.brand;
        }),
        side: WidgetStateProperty.resolveWith((s) =>
            focusSide(s) ??
            (s.contains(WidgetState.disabled)
                ? BorderSide(color: Fl.stroke2)
                : BorderSide(color: Fl.km1.brandStroke))),
      ),
    ),
    // セカンダリ（既定のボタン）
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        elevation: WidgetStatePropertyAll(0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(64, Fl.target)),
        padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12)),
        shape: WidgetStatePropertyAll(r4),
        textStyle: WidgetStatePropertyAll(FlText.body1Strong),
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? Fl.fgDisabled : Fl.fg1),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return Fl.subtlePressed;
          if (s.contains(WidgetState.hovered)) return Fl.subtleHover;
          return Fl.bg1;
        }),
        side: WidgetStateProperty.resolveWith((s) => focusSide(s) ?? BorderSide(
              color: s.contains(WidgetState.disabled)
                  ? Fl.stroke2
                  : (s.contains(WidgetState.hovered)
                      ? Fl.stroke1Hover
                      : Fl.stroke1),
            )),
      ),
    ),
    // サブトル（背景なし）
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(Fl.target, Fl.target)),
        padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10)),
        shape: WidgetStatePropertyAll(r4),
        textStyle: WidgetStatePropertyAll(FlText.body1Strong),
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        // KM1: 文字だけのボタン（transparent）はブランド色の文字
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? Fl.fgDisabled : Fl.brandFg),
        backgroundColor: WidgetStateProperty.resolveWith(subtleBg),
        side: WidgetStateProperty.resolveWith(focusSide),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(Fl.target, Fl.target)),
        maximumSize: WidgetStatePropertyAll(
            Size(math.max(40, Fl.target), math.max(40, Fl.target))),
        padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
        shape: WidgetStatePropertyAll(r4),
        iconSize: WidgetStatePropertyAll(20),
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? Fl.fgDisabled : Fl.fg2),
        backgroundColor: WidgetStateProperty.resolveWith(subtleBg),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Fl.r2)),
      side: WidgetStateBorderSide.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? BorderSide.none
              : BorderSide(color: Fl.fg3, width: 1)),
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Fl.brand : Colors.transparent),
      checkColor: WidgetStatePropertyAll(Colors.white),
      overlayColor: WidgetStatePropertyAll(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: Duration(milliseconds: 500),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      textStyle: FlText.caption1,
      decoration: BoxDecoration(
        color: Fl.bg1,
        borderRadius: BorderRadius.circular(Fl.r4),
        border: Border.all(color: Fl.stroke2),
        boxShadow: Fl.shadow8,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Fl.bg1,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x66000000),
      elevation: 8,
      textStyle: FlText.body1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Fl.r4),
        side: BorderSide(color: Fl.stroke2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Fl.bg1,
      contentTextStyle: FlText.body1,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Fl.r4),
        side: BorderSide(color: Fl.stroke2),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Fl.bg1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Fl.r8),
        side: BorderSide(color: Fl.stroke2),
      ),
      headerBackgroundColor: Fl.bg1,
      headerForegroundColor: Fl.fg1,
      headerHeadlineStyle: FlText.subtitle1,
      headerHelpStyle: FlText.caption1,
      dividerColor: Fl.stroke2,
      weekdayStyle: FlText.caption1.copyWith(color: Fl.fg3),
      dayStyle: FlText.body1,
      yearStyle: FlText.body1,
      dayShape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Fl.r4)),
      ),
      dayOverlayColor: WidgetStatePropertyAll(
          Fl.isDark ? Color(0x14FFFFFF) : Color(0x0A000000)),
      dayForegroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return Colors.white;
        if (s.contains(WidgetState.disabled)) return Fl.fgDisabled;
        return Fl.fg1;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Fl.brand : Colors.transparent),
      todayForegroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : Fl.brandFg),
      todayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Fl.brand : Colors.transparent),
      todayBorder: BorderSide(color: Fl.brandFg),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Fl.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Fl.r8)),
    ),
  );
}

// ---------------------------------------------------------------------------
// 共通コンポーネント
// ---------------------------------------------------------------------------

/// 角丸 + 細い罫線の面（Outlook / Teams のパネル）
class FlPane extends StatelessWidget {
  const FlPane({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Fl.bg1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Fl.r8),
        side: BorderSide(color: Fl.stroke2),
      ),
      child: child,
    );
  }
}

/// Outlook のようなブランドカラーの上部バー（広い画面）
class FlTopBar extends StatelessWidget {
  const FlTopBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: Fl.topBar,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FlIcon(FluentIcons.calendar_ltr_24_filled,
              size: 22, color: Colors.white),
          SizedBox(width: 12),
          Text(title,
              style: FlText.subtitle2.copyWith(color: Colors.white)),
          Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class FlNavItem {
  const FlNavItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// モバイル向けのタブバー（選択中は塗りのアイコン + ブランドカラー）
class FlBottomNav extends StatelessWidget {
  const FlBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<FlNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Fl.bg1,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Fl.stroke2)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onChanged(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FlIcon(
                            i == index ? items[i].selectedIcon : items[i].icon,
                            size: 24,
                            color: i == index ? Fl.brandFg : Fl.fg3,
                          ),
                          SizedBox(height: 2),
                          Text(
                            items[i].label,
                            style: (i == index
                                    ? FlText.caption1Strong
                                    : FlText.caption1)
                                .copyWith(
                                    color: i == index ? Fl.brandFg : Fl.fg3),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fluent の TabList（下線インジケーター）
class FlTabList extends StatelessWidget {
  const FlTabList({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final List<int>? counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Fl.stroke2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(Fl.r4),
                onTap: () => onSelected(i),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: IntrinsicWidth(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(0, 10, 0, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              labels[i],
                              style: i == selected
                                  ? FlText.body1Strong
                                  : FlText.body1.copyWith(color: Fl.fg2),
                            ),
                            if (counts != null && counts![i] > 0) ...[
                              SizedBox(width: 4),
                              Text('${counts![i]}',
                                  style: FlText.caption1
                                      .copyWith(color: Fl.fg3)),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: i == selected ? Fl.brandFg : Colors.transparent,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// To Do 風の丸いチェック
class FlCheckCircle extends StatelessWidget {
  const FlCheckCircle({
    super.key,
    required this.checked,
    required this.onTap,
    this.size = 20,
  });

  final bool checked;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: checked ? Fl.brand : Colors.transparent,
              border: Border.all(
                  color: checked ? Fl.brand : Fl.fg3, width: 1.5),
            ),
            child: checked
                ? FlIcon(FluentIcons.checkmark_12_filled,
                    size: size * 0.6, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 色つきの四角いチェックボックス（Outlook の「マイカレンダー」）
class FlCheckRow extends StatelessWidget {
  const FlCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value ? (color ?? Fl.brand) : Colors.transparent,
                borderRadius: BorderRadius.circular(Fl.r2),
                border: Border.all(color: value ? (color ?? Fl.brand) : Fl.fg3),
              ),
              child: value
                  ? FlIcon(FluentIcons.checkmark_12_filled,
                      size: 11, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(child: Text(label, style: FlText.body1)),
          ],
        ),
      ),
    );
  }
}

class FlSwitch extends StatelessWidget {
  const FlSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 150),
          width: 40,
          height: 20,
          padding: EdgeInsets.symmetric(horizontal: 3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? Fl.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: value ? Fl.brand : Fl.strokeAccessible),
          ),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? Colors.white : Fl.strokeAccessible,
            ),
          ),
        ),
      ),
    );
  }
}

class FlSwitchTile extends StatelessWidget {
  const FlSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Fl.r4),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              FlIcon(icon, size: 20, color: Fl.fg2),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FlText.body1),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: FlText.caption1.copyWith(color: Fl.fg3)),
                ],
              ),
            ),
            SizedBox(width: 12),
            FlSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// 外枠 1px + 下辺が強調される入力欄（フォーカスで下辺がブランド色の2pxに）
class FlTextField extends StatefulWidget {
  const FlTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.leading,
    this.trailing,
    this.textInputAction,
    this.obscure = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? leading;
  final Widget? trailing;
  final TextInputAction? textInputAction;

  /// パスワード入力など、文字を隠す
  final bool obscure;

  @override
  State<FlTextField> createState() => _FlTextFieldState();
}

class _FlTextFieldState extends State<FlTextField> {
  FocusNode? _own;
  bool _focused = false;
  bool _hover = false;

  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const none = InputBorder.none;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Fl.r4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Fl.bg1,
            borderRadius: BorderRadius.circular(Fl.r4),
            border: Border.all(
                color: (_hover && !_focused) ? Fl.stroke1Hover : Fl.stroke1),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  if (widget.leading != null)
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: widget.leading,
                    ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _node,
                      autofocus: widget.autofocus,
                      minLines: widget.minLines,
                      maxLines: widget.maxLines,
                      onSubmitted: widget.onSubmitted,
                      onChanged: widget.onChanged,
                      textInputAction: widget.textInputAction,
                      obscureText: widget.obscure,
                      cursorColor: Fl.brandFg,
                      // KM1: 入力中の文字はタッチ 16px（iPhone の自動拡大を防ぐ）、PC 14px
                      style: FlText.field,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: none,
                        enabledBorder: none,
                        focusedBorder: none,
                        hintText: widget.hint,
                        hintStyle: FlText.field.copyWith(color: Fl.fg3),
                        // 1行の欄の高さを部品の高さ（PC 32px・タッチ 44px）にそろえる
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: (Fl.target - (Fl.touch ? 22 : 20)) / 2),
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    height: _focused ? 2 : 1,
                    color: _focused ? Fl.brandFg : Fl.strokeAccessible,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 入力欄の上に置くラベル
class FlField extends StatelessWidget {
  const FlField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(label, style: FlText.body1Strong),
          ),
          child,
        ],
      ),
    );
  }
}

/// 日付・時刻などの選択ボタン（入力欄と同じ見た目）
class FlPickerField extends StatelessWidget {
  const FlPickerField({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.onClear,
    this.placeholder = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Fl.bg1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Fl.r4),
        side: BorderSide(color: Fl.stroke1),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: Fl.target,
          child: Row(
            children: [
              SizedBox(width: 10),
              FlIcon(icon, size: 16, color: Fl.fg2),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: FlText.body1
                      .copyWith(color: placeholder ? Fl.fg3 : Fl.fg1),
                ),
              ),
              if (onClear != null)
                InkWell(
                  onTap: onClear,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: FlIcon(FluentIcons.dismiss_12_regular,
                        size: 14, color: Fl.fg2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 横並びのトグルボタン（選択中はブランドの淡い背景）
class FlToggleGroup<T> extends StatelessWidget {
  const FlToggleGroup({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
  });

  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Fl.r4),
        border: Border.all(color: Fl.stroke1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Material(
                color: items[i] == value ? Fl.brandTint : Fl.bg1,
                child: InkWell(
                  onTap: () => onChanged(items[i]),
                  child: Container(
                    height: Fl.target - 2,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(left: BorderSide(color: Fl.stroke1)),
                    ),
                    child: Text(
                      labelOf(items[i]),
                      style: items[i] == value
                          ? FlText.body1Strong.copyWith(color: Fl.brandFg)
                          : FlText.body1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 編集ダイアログ（またはモバイルの全画面）の枠。
/// ヘッダー（タイトル + 閉じる）/ 本文 / フッター（主ボタンが左）の構成。
/// KM1 のボタンの並び（デジタル庁の配置）。
/// - PC: 右端にプライマリ、その左に「キャンセル」（文字だけのボタン）。[leading]（削除など）は左端
/// - スマホ（画面の幅 480px 未満）: 縦に積み、プライマリを一番上に
class FlActions extends StatelessWidget {
  const FlActions({
    super.key,
    required this.primary,
    this.onCancel,
    this.leading,
  });

  final Widget primary;

  /// 「キャンセル」を押したとき。null ならキャンセルを出さない
  final VoidCallback? onCancel;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final cancel = onCancel == null
        ? null
        : TextButton(onPressed: onCancel, child: Text('キャンセル'));
    if (MediaQuery.sizeOf(context).width < 480) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          if (cancel != null) ...[SizedBox(height: 8), cancel],
          if (leading != null) ...[SizedBox(height: 8), leading!],
        ],
      );
    }
    return Row(
      children: [
        if (leading != null) leading!,
        Spacer(),
        if (cancel != null) ...[cancel, SizedBox(width: 8)],
        primary,
      ],
    );
  }
}

class FlEditorFrame extends StatelessWidget {
  const FlEditorFrame({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
    this.error,
  });

  /// 保存できない理由。保存ボタンのすぐ上（スクロールしても常に見える位置）に出す
  final String? error;

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Fl.bg1,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: FlText.subtitle1)),
                  IconButton(
                    tooltip: '閉じる',
                    icon: FlIcon(FluentIcons.dismiss_24_regular),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: children,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Fl.stroke2)),
              ),
              padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          FlIcon(FluentIcons.error_circle_16_filled,
                              size: 16, color: Fl.danger),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(error!,
                                style: FlText.body1.copyWith(color: Fl.danger)),
                          ),
                        ],
                      ),
                    ),
                  FlActions(
                    primary: FilledButton(onPressed: onSave, child: Text('保存')),
                    onCancel: () => Navigator.of(context).pop(),
                    leading: onDelete == null
                        ? null
                        : TextButton.icon(
                            onPressed: onDelete,
                            style: TextButton.styleFrom(foregroundColor: Fl.danger),
                            icon: FlIcon(FluentIcons.delete_24_regular, size: 18),
                            label: Text('削除'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// KM1 の画面の出入り: 短いフェード + 下から 8px（動かしてよいのは 8px まで）。
/// OS の「動きを減らす」設定では動かさない
class _Km1PageTransitions extends PageTransitionsBuilder {
  const _Km1PageTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final a = CurvedAnimation(
        parent: animation, curve: Curves.decelerate, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, 8 * (1 - a.value)), child: child),
        child: child,
      ),
    );
  }
}


/// アイコン。KM1 にある記号は KM1 のアイコン（B 案: 青みグレーの線 + 淡い面）で描き、
/// KM1 にない記号（動画・パソコンなど）だけ Fluent System Icons のまま描く（KM1 のアイコンに足す候補）。
/// 色を渡さないときは、ボタンなど部品の中ならその文字色に、それ以外は KM1 の icon-ink に従う。
class FlIcon extends StatelessWidget {
  const FlIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final k = icon == null ? null : _km1IconMap[icon];
    if (k == null) {
      return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    }
    final theme = IconTheme.of(context);
    final inherited = theme.color;
    // 部品（ボタン・選択中の項目など）が色を決めているときはそれに従う
    final inParent = inherited != null && inherited != Theme.of(context).iconTheme.color;
    return Km1BIcon(k.$1,
        size: size ?? theme.size ?? 20,
        filled: k.$2,
        color: color ?? (inParent ? inherited : null),
        semanticLabel: semanticLabel);
  }
}

/// Fluent のアイコン → KM1 のアイコン（名前, 塗り）
final Map<IconData, (Km1BIconName, bool)> _km1IconMap = {
  FluentIcons.add_16_regular: (Km1BIconName.add, false),
  FluentIcons.add_24_regular: (Km1BIconName.add, false),
  FluentIcons.alert_16_regular: (Km1BIconName.notification, false),
  FluentIcons.alert_24_regular: (Km1BIconName.notification, false),
  FluentIcons.alert_on_24_regular: (Km1BIconName.reminder, false),
  FluentIcons.arrow_repeat_all_24_regular: (Km1BIconName.repeatWeekly, false),
  FluentIcons.arrow_sync_24_regular: (Km1BIconName.sync, false),
  FluentIcons.calendar_add_24_regular: (Km1BIconName.calendarAdd, false),
  FluentIcons.calendar_cancel_24_regular: (Km1BIconName.canceled, false),
  FluentIcons.calendar_ltr_16_regular: (Km1BIconName.calendar, false),
  FluentIcons.calendar_ltr_24_filled: (Km1BIconName.calendar, true),
  FluentIcons.calendar_ltr_24_regular: (Km1BIconName.calendar, false),
  FluentIcons.calendar_search_20_regular: (Km1BIconName.clock, false),
  FluentIcons.checkmark_12_filled: (Km1BIconName.check, true),
  FluentIcons.checkmark_24_regular: (Km1BIconName.check, false),
  FluentIcons.chevron_down_24_regular: (Km1BIconName.chevronDown, false),
  FluentIcons.chevron_left_24_regular: (Km1BIconName.chevronLeft, false),
  FluentIcons.chevron_right_24_regular: (Km1BIconName.chevronRight, false),
  FluentIcons.chevron_up_24_regular: (Km1BIconName.chevronUp, false),
  FluentIcons.clipboard_paste_24_filled: (Km1BIconName.paste, true),
  FluentIcons.clipboard_paste_24_regular: (Km1BIconName.paste, false),
  FluentIcons.clock_24_regular: (Km1BIconName.clock, false),
  FluentIcons.cloud_checkmark_24_regular: (Km1BIconName.cloud, false),
  FluentIcons.cloud_off_24_regular: (Km1BIconName.offline, false),
  FluentIcons.copy_24_regular: (Km1BIconName.copy, false),
  FluentIcons.delete_24_regular: (Km1BIconName.delete, false),
  FluentIcons.dismiss_12_regular: (Km1BIconName.dismiss, false),
  FluentIcons.dismiss_24_regular: (Km1BIconName.dismiss, false),
  FluentIcons.edit_16_regular: (Km1BIconName.edit, false),
  FluentIcons.edit_24_regular: (Km1BIconName.edit, false),
  FluentIcons.flag_16_regular: (Km1BIconName.flag, false),
  FluentIcons.globe_24_regular: (Km1BIconName.globe, false),
  FluentIcons.link_16_regular: (Km1BIconName.link, false),
  FluentIcons.link_24_regular: (Km1BIconName.link, false),
  FluentIcons.location_24_regular: (Km1BIconName.location, false),
  FluentIcons.lock_closed_24_regular: (Km1BIconName.lock, false),
  FluentIcons.mail_24_regular: (Km1BIconName.mail, false),
  FluentIcons.more_horizontal_24_regular: (Km1BIconName.more, false),
  FluentIcons.more_vertical_24_regular: (Km1BIconName.moreVertical, false),
  FluentIcons.note_16_regular: (Km1BIconName.note, false),
  FluentIcons.note_24_regular: (Km1BIconName.note, false),
  FluentIcons.person_24_regular: (Km1BIconName.person, false),
  FluentIcons.person_circle_24_regular: (Km1BIconName.person, false),
  FluentIcons.search_24_regular: (Km1BIconName.search, false),
  FluentIcons.send_24_regular: (Km1BIconName.send, false),
  FluentIcons.settings_24_regular: (Km1BIconName.settings, false),
  FluentIcons.sign_out_24_regular: (Km1BIconName.signOut, false),
  FluentIcons.star_24_filled: (Km1BIconName.star, true),
  FluentIcons.star_24_regular: (Km1BIconName.star, false),
  FluentIcons.task_list_ltr_24_filled: (Km1BIconName.list, true),
  FluentIcons.task_list_ltr_24_regular: (Km1BIconName.list, false),
  FluentIcons.warning_16_regular: (Km1BIconName.warning, false),
  FluentIcons.weather_moon_24_regular: (Km1BIconName.darkMode, false),
  FluentIcons.weather_sunny_24_regular: (Km1BIconName.lightMode, false),
  FluentIcons.window_new_24_regular: (Km1BIconName.openExternal, false),
};
