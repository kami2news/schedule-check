import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

/// Fluent 2 (Web) のカラートークン一式（ライト／ダーク）。
/// 値は https://fluent2.microsoft.design と Fluent UI の webLightTheme / webDarkTheme に基づく。
class FlPalette {
  const FlPalette({
    required this.brightness,
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

  static const light = FlPalette(
    brightness: Brightness.light,
    fg1: Color(0xFF242424),
    fg2: Color(0xFF424242),
    fg3: Color(0xFF616161),
    fgDisabled: Color(0xFFBDBDBD),
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFFAFAFA),
    bg3: Color(0xFFF5F5F5),
    bg4: Color(0xFFF0F0F0),
    bg5: Color(0xFFEBEBEB),
    bg6: Color(0xFFE6E6E6),
    stroke1: Color(0xFFD1D1D1),
    stroke1Hover: Color(0xFFC7C7C7),
    stroke2: Color(0xFFE0E0E0),
    stroke3: Color(0xFFF0F0F0),
    strokeAccessible: Color(0xFF616161),
    // KM1 のブランド色（EPSON ブルー #10218B = brand-700）
    brand: Color(0xFF10218B),
    brandHover: Color(0xFF0C1A6E),
    brandPressed: Color(0xFF081257),
    brandFg: Color(0xFF10218B),
    brandTint: Color(0xFFECEFFC),
    danger: Color(0xFFB10E1C),
    dangerLine: Color(0xFFC50F1F),
    warning: Color(0xFFBC4B09),
    success: Color(0xFF107C10),
    topBar: Color(0xFF10218B),
    subtleHover: Color(0xFFF5F5F5),
    subtlePressed: Color(0xFFE0E0E0),
  );

  static const dark = FlPalette(
    brightness: Brightness.dark,
    fg1: Color(0xFFFFFFFF),
    fg2: Color(0xFFD6D6D6),
    fg3: Color(0xFFADADAD),
    fgDisabled: Color(0xFF5C5C5C),
    bg1: Color(0xFF292929),
    bg2: Color(0xFF1F1F1F),
    bg3: Color(0xFF141414),
    bg4: Color(0xFF0A0A0A),
    bg5: Color(0xFF000000),
    bg6: Color(0xFF333333),
    stroke1: Color(0xFF666666),
    stroke1Hover: Color(0xFF757575),
    stroke2: Color(0xFF525252),
    stroke3: Color(0xFF3D3D3D),
    strokeAccessible: Color(0xFFADADAD),
    // KM1 ダーク: 塗りは brand-500、文字・線は brand-200
    brand: Color(0xFF3A4FD1),
    brandHover: Color(0xFF4A5FE0),
    brandPressed: Color(0xFF2C3FB8),
    brandFg: Color(0xFF99A6FF),
    brandTint: Color(0xFF0D1238),
    danger: Color(0xFFE37D80),
    dangerLine: Color(0xFFE37D80),
    warning: Color(0xFFFAA06B),
    success: Color(0xFF54B054),
    topBar: Color(0xFF0A0A0A),
    subtleHover: Color(0xFF383838),
    subtlePressed: Color(0xFF2E2E2E),
  );
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

/// Fluent 2 のタイプランプ。Segoe UI の代わりに互換フォント Selawik を使い、
/// 日本語などは各OSのフォントにフォールバックする。
class FlText {
  FlText._();

  static const family = 'Selawik';
  static const fallback = [
    'Segoe UI',
    'Yu Gothic UI',
    'Meiryo UI',
    'Hiragino Kaku Gothic ProN',
    'Noto Sans JP',
    'sans-serif',
  ];

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
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    // Fluent の入場モーション（短いフェード + わずかな上方向スライド）
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
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
        minimumSize: WidgetStatePropertyAll(Size(64, 32)),
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
      ),
    ),
    // セカンダリ（既定のボタン）
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        elevation: WidgetStatePropertyAll(0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(64, 32)),
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
        side: WidgetStateProperty.resolveWith((s) => BorderSide(
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
        minimumSize: WidgetStatePropertyAll(Size(32, 32)),
        padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10)),
        shape: WidgetStatePropertyAll(r4),
        textStyle: WidgetStatePropertyAll(FlText.body1Strong),
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.disabled) ? Fl.fgDisabled : Fl.fg1),
        backgroundColor: WidgetStateProperty.resolveWith(subtleBg),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(32, 32)),
        maximumSize: WidgetStatePropertyAll(Size(40, 40)),
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
          Icon(FluentIcons.calendar_ltr_24_filled,
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
                          Icon(
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
                ? Icon(FluentIcons.checkmark_12_filled,
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
                  ? Icon(FluentIcons.checkmark_12_filled,
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
              Icon(icon, size: 20, color: Fl.fg2),
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
                      style: FlText.body1,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: none,
                        enabledBorder: none,
                        focusedBorder: none,
                        hintText: widget.hint,
                        hintStyle: FlText.body1.copyWith(color: Fl.fg3),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
          height: 32,
          child: Row(
            children: [
              SizedBox(width: 10),
              Icon(icon, size: 16, color: Fl.fg2),
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
                    child: Icon(FluentIcons.dismiss_12_regular,
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
                    height: 30,
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
class FlEditorFrame extends StatelessWidget {
  const FlEditorFrame({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
  });

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
                    icon: Icon(FluentIcons.dismiss_24_regular),
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
              child: Row(
                children: [
                  FilledButton(onPressed: onSave, child: Text('保存')),
                  SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('キャンセル'),
                  ),
                  Spacer(),
                  if (onDelete != null)
                    TextButton.icon(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(foregroundColor: Fl.danger),
                      icon: Icon(FluentIcons.delete_24_regular, size: 18),
                      label: Text('削除'),
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
