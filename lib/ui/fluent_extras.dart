import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'fluent.dart';

/// 左端に太いアクセントバーがある塗り（Outlook の予定ブロック）。
/// [showAs] によってバーの描き方を変える:
/// 予定あり=塗り / 仮の予定=斜線 / 空き時間=白抜き / 他の場所で仕事中=点線 / 外出中=紫
class FlAccentBox extends StatelessWidget {
  const FlAccentBox({
    super.key,
    required this.accent,
    required this.child,
    this.bar = 4,
    this.padding = const EdgeInsets.fromLTRB(5, 2, 4, 2),
    this.showAs = ShowAs.busy,
    this.radius,
  });

  /// 角の丸み（日をまたぐ予定の続きでは、つながる側を角ばらせる）。省略時は4px
  final BorderRadius? radius;

  final Color accent;
  final Widget child;
  final double bar;
  final EdgeInsets padding;
  final ShowAs showAs;

  /// 外出中のバーの色（Outlook と同じく紫）
  static const awayColor = Color(0xFF8764B8);

  @override
  Widget build(BuildContext context) {
    final free = showAs == ShowAs.free;
    final fill = free ? Fl.bg1 : Fl.tint(accent);
    final r = radius ?? BorderRadius.circular(Fl.r4);
    return ClipRRect(
      borderRadius: r,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          border: free
              ? Border.all(color: accent.withValues(alpha: 0.6))
              : (showAs == ShowAs.tentative
                  ? Border.all(color: accent.withValues(alpha: 0.35))
                  : null),
          borderRadius: r,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: bar,
              child: CustomPaint(
                painter: _BarPainter(
                  color: showAs == ShowAs.away ? awayColor : accent,
                  showAs: showAs,
                  background: fill,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  padding.left + bar, padding.top, padding.right, padding.bottom),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(
      {required this.color, required this.showAs, required this.background});

  final Color color;
  final ShowAs showAs;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()..color = color;
    switch (showAs) {
      case ShowAs.busy:
      case ShowAs.away:
        canvas.drawRect(rect, p);
      case ShowAs.free:
        // 白抜き（枠だけ）
        canvas.drawRect(rect, Paint()..color = background);
        canvas.drawRect(
            rect.deflate(0.5),
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      case ShowAs.tentative:
        // 斜線
        canvas.drawRect(rect, Paint()..color = background);
        canvas.save();
        canvas.clipRect(rect);
        final line = Paint()
          ..color = color
          ..strokeWidth = 2;
        for (var y = -size.width; y < size.height + size.width; y += 5) {
          canvas.drawLine(Offset(0, y + size.width), Offset(size.width, y), line);
        }
        canvas.restore();
      case ShowAs.workingElsewhere:
        // 点線
        canvas.drawRect(rect, Paint()..color = background);
        for (var y = 0.0; y < size.height; y += 6) {
          canvas.drawRect(
              Rect.fromLTWH(0, y, size.width, math.min(3, size.height - y)), p);
        }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.color != color || old.showAs != showAs || old.background != background;
}

/// 小さな丸（カレンダーの色）。[filled] が false なら輪だけ
class FlColorDot extends StatelessWidget {
  const FlColorDot({super.key, required this.color, this.size = 12, this.filled = true});

  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

/// 表示方法の小さな見本（メニュー用）
class FlShowAsSwatch extends StatelessWidget {
  const FlShowAsSwatch({super.key, required this.showAs, required this.color});

  final ShowAs showAs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: FlAccentBox(
        accent: color,
        showAs: showAs,
        bar: 5,
        padding: EdgeInsets.zero,
        child: SizedBox.expand(),
      ),
    );
  }
}

/// 入力欄と同じ見た目のドロップダウン（Fluent の Dropdown）
class FlDropdown<T> extends StatelessWidget {
  const FlDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.leadingOf,
  });

  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final Widget Function(T)? leadingOf;

  Widget _row(T v, {bool strong = false}) => Row(
        children: [
          if (leadingOf != null) ...[leadingOf!(v), SizedBox(width: 10)],
          Expanded(
            child: Text(labelOf(v),
                overflow: TextOverflow.ellipsis,
                style: strong ? FlText.body1Strong : FlText.body1),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cs) => PopupMenuButton<T>(
        tooltip: '',
        position: PopupMenuPosition.under,
        constraints: BoxConstraints(
            minWidth: cs.maxWidth.isFinite ? cs.maxWidth : 200, maxWidth: 360),
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final v in items)
            PopupMenuItem<T>(
              value: v,
              height: 36,
              child: Row(
                children: [
                  Expanded(child: _row(v, strong: v == value)),
                  if (v == value)
                    Icon(FluentIcons.checkmark_24_regular,
                        size: 16, color: Fl.brandFg),
                ],
              ),
            ),
        ],
        child: Container(
          height: 32,
          padding: EdgeInsets.only(left: 10, right: 8),
          decoration: BoxDecoration(
            color: Fl.bg1,
            borderRadius: BorderRadius.circular(Fl.r4),
            border: Border.all(color: Fl.stroke1),
          ),
          child: Row(
            children: [
              Expanded(child: _row(value)),
              Icon(FluentIcons.chevron_down_24_regular, size: 14, color: Fl.fg2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fluent のダイアログ（角丸8・大きな影・40%の暗幕）
Future<T?> showFlDialog<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 520,
  double? maxHeight,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Color(0x66000000),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Fl.bg1,
            borderRadius: BorderRadius.circular(Fl.r8),
            boxShadow: Fl.shadow64,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Fl.r8),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// 確認ダイアログ。主ボタン（実行）が左、キャンセルが右。
Future<bool> showFlConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showFlDialog<bool>(
    context,
    maxWidth: 400,
    child: Builder(
      builder: (ctx) => Material(
        color: Fl.bg1,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FlText.subtitle1),
              SizedBox(height: 8),
              Text(message, style: FlText.body1.copyWith(color: Fl.fg2)),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(confirmLabel),
                  ),
                  SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('キャンセル'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Outlook 風の時刻リスト（15分刻み）。[extra] は刻みに無い値（23:59 など）を追加する。
Future<int?> showFlTimeList(BuildContext context, int initialMin,
    {List<int> extra = const []}) {
  final values = <int>{
    for (var m = 0; m < 24 * 60; m += 15) m,
    initialMin,
    ...extra,
  }.toList()
    ..sort();
  const rowH = 36.0;
  final index = values.indexOf(initialMin);
  final scroll = ScrollController(
      initialScrollOffset: (index * rowH - 3 * rowH).clamp(0.0, 1e9).toDouble());
  String fmt(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  return showFlDialog<int>(
    context,
    maxWidth: 200,
    maxHeight: 368,
    child: Builder(
      builder: (ctx) => Material(
        color: Fl.bg1,
        child: ListView.builder(
          controller: scroll,
          padding: EdgeInsets.symmetric(vertical: 4),
          itemExtent: rowH,
          itemCount: values.length,
          itemBuilder: (_, i) {
            final sel = values[i] == initialMin;
            return InkWell(
              onTap: () => Navigator.of(ctx).pop(values[i]),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                padding: EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: sel ? Fl.brandTint : null,
                  borderRadius: BorderRadius.circular(Fl.r4),
                ),
                child: Text(
                  fmt(values[i]),
                  style: sel
                      ? FlText.body1Strong.copyWith(color: Fl.brandFg)
                      : FlText.body1,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// 土日の文字色（設定で色分けがオフ、または平日なら null）。
/// 日本のカレンダーの慣習どおり、土曜は青・日曜は赤
Color? weekendFg(DateTime d) {
  if (!weekendColorsOn) return null;
  if (d.weekday == DateTime.sunday) return Fl.isDark ? Color(0xFFE37D80) : Color(0xFFB10E1C);
  if (d.weekday == DateTime.saturday) return Fl.isDark ? Color(0xFF479EF5) : Color(0xFF0F6CBD);
  return null;
}

/// ビルド番号（CI で --dart-define=BUILD_ID=<コミット> を渡す。ローカルでは dev）
const kBuildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');

/// 表示テーマ（システム／ライト／ダーク）の切り替えメニュー
class FlThemeButton extends StatelessWidget {
  const FlThemeButton({super.key, this.onDark = false});

  /// 濃い背景（上部バー）の上に置くとき true
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final current = store.themeMode;
    return PopupMenuButton<FlThemeMode>(
      tooltip: '表示テーマ',
      position: PopupMenuPosition.under,
      onSelected: (m) => StoreScope.read(context).setThemeMode(m.name),
      itemBuilder: (_) => [
        for (final m in FlThemeMode.values)
          PopupMenuItem<FlThemeMode>(
            value: m,
            height: 36,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: m.name == current
                      ? Icon(FluentIcons.checkmark_24_regular, size: 16)
                      : null,
                ),
                SizedBox(width: 8),
                Text(m.label),
              ],
            ),
          ),
        PopupMenuDivider(),
        // どの版を見ているか確認できるようにビルド番号を出す
        PopupMenuItem<FlThemeMode>(
          enabled: false,
          height: 28,
          child: Text('バージョン $kBuildId',
              style: FlText.caption1.copyWith(color: Fl.fg3)),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          Fl.isDark
              ? FluentIcons.weather_moon_24_regular
              : FluentIcons.weather_sunny_24_regular,
          size: 20,
          color: onDark ? Colors.white : Fl.fg2,
        ),
      ),
    );
  }
}

/// 選択肢から1つ選ぶダイアログ（Fluent の RadioGroup ＋ Dialog）。キャンセルなら null
Future<T?> showFlChoice<T>(
  BuildContext context, {
  required String title,
  required List<(T value, String label)> options,
  required T initial,
  required String confirmLabel,
  bool danger = false,
}) {
  var selected = initial;
  return showFlDialog<T>(
    context,
    maxWidth: 400,
    child: StatefulBuilder(
      builder: (ctx, setState) => Material(
        color: Fl.bg1,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FlText.subtitle1),
              SizedBox(height: 12),
              for (final (v, label) in options)
                InkWell(
                  borderRadius: BorderRadius.circular(Fl.r4),
                  onTap: () => setState(() => selected = v),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        // Fluent のラジオ（外枠＋選択中は中の点）
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: v == selected
                                    ? Fl.brandFg
                                    : Fl.strokeAccessible),
                          ),
                          child: v == selected
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Fl.brandFg),
                                )
                              : null,
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text(label, style: FlText.body1)),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    style: danger
                        ? FilledButton.styleFrom(backgroundColor: Fl.danger)
                        : null,
                    onPressed: () => Navigator.of(ctx).pop(selected),
                    child: Text(confirmLabel),
                  ),
                  SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('キャンセル'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
