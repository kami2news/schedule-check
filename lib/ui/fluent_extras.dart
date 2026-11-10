import 'package:flutter/material.dart';

import 'fluent.dart';

/// 左端に太いアクセントバーがある塗り（Outlook の予定ブロック）。
/// 非一様な Border + borderRadius を避けるため、クリップ + Stack で描く。
class FlAccentBox extends StatelessWidget {
  const FlAccentBox({
    super.key,
    required this.accent,
    required this.child,
    this.bar = 4,
    this.padding = const EdgeInsets.fromLTRB(5, 2, 4, 2),
  });

  final Color accent;
  final Widget child;
  final double bar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Fl.r4),
      child: ColoredBox(
        color: Fl.tint(accent),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: bar,
              child: ColoredBox(color: accent),
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

/// Fluent のダイアログ（角丸8・大きな影・40%の暗幕）
Future<T?> showFlDialog<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 520,
  double? maxHeight,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FlText.subtitle1),
              const SizedBox(height: 8),
              Text(message, style: FlText.body1.copyWith(color: Fl.fg2)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(confirmLabel),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('キャンセル'),
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
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemExtent: rowH,
          itemCount: values.length,
          itemBuilder: (_, i) {
            final sel = values[i] == initialMin;
            return InkWell(
              onTap: () => Navigator.of(ctx).pop(values[i]),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: sel ? Fl.brandTint : null,
                  borderRadius: BorderRadius.circular(Fl.r4),
                ),
                child: Text(
                  fmt(values[i]),
                  style: sel
                      ? FlText.body1Strong.copyWith(color: Fl.brand)
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
