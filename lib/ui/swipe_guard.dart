import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// 横スライドがブラウザの「戻る・進む」と取り違えられるのを防ぐ。
///
/// - Mac のトラックパッドの 2 本指の横スワイプ: CSS の `overscroll-behavior-x: none`（web/index.html）で、
///   ブラウザの戻る・進むに渡さない（Chrome・Edge・Firefox）。
/// - それでもブラウザの戻る（iPhone の画面の端からのスワイプ・Safari のトラックパッドなど）が届いたとき:
///   直前（[window] 以内）に横の動きがあったら誤操作とみなし、戻る操作を受け流して画面に留まる。
///   ダイアログや編集画面を閉じるための「戻る」は、横の動きのすぐ後でなければ今までどおり効く。
class SwipeGuard {
  SwipeGuard._();

  static const window = Duration(milliseconds: 1500);

  /// 画面の端からこの幅の中で触れ始めたら、端からのスワイプ（ブラウザの戻る・進む）の可能性がある
  static const edge = 28.0;

  static DateTime? _last;

  /// テスト用に時刻を差し替えられる
  static DateTime Function() now = DateTime.now;

  static void mark() => _last = now();

  static bool get recent => _last != null && now().difference(_last!) < window;

  static void reset() => _last = null;
}

/// アプリ全体の横の動きを見張る（動きは邪魔しない）
class SwipeGuardListener extends StatefulWidget {
  const SwipeGuardListener({super.key, required this.child});
  final Widget child;

  @override
  State<SwipeGuardListener> createState() => _SwipeGuardListenerState();
}

class _SwipeGuardListenerState extends State<SwipeGuardListener> {
  final _down = <int, Offset>{};

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _down[e.pointer] = e.position;
        // 画面の左右の端で触れ始めた（iPhone の端からのスワイプ）
        if (e.kind == PointerDeviceKind.touch &&
            (e.position.dx < SwipeGuard.edge ||
                e.position.dx > width - SwipeGuard.edge)) {
          SwipeGuard.mark();
        }
      },
      onPointerMove: (e) {
        final s = _down[e.pointer];
        if (s == null) return;
        final d = e.position - s;
        if (d.dx.abs() > 12 && d.dx.abs() > d.dy.abs()) SwipeGuard.mark();
      },
      onPointerUp: (e) => _down.remove(e.pointer),
      onPointerCancel: (e) => _down.remove(e.pointer),
      onPointerSignal: (e) {
        if (e is PointerScrollEvent &&
            e.scrollDelta.dx.abs() > e.scrollDelta.dy.abs()) {
          SwipeGuard.mark();
        }
      },
      onPointerPanZoomUpdate: (e) {
        if (e.pan.dx.abs() > 12 && e.pan.dx.abs() > e.pan.dy.abs()) SwipeGuard.mark();
      },
      child: widget.child,
    );
  }
}
