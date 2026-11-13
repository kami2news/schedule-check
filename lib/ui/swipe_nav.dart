import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// スライド（スワイプ）やトラックパッド・ホイールで前後へ移る。
///
/// - 横のスライド: 左へ払うと次、右へ払うと前
/// - [vertical] が true なら縦のスライドとホイールも（上へ払う／下へ回すと次）
///
/// 中のスクロール（日・週表示の縦スクロールなど）とは向きで分かれるので、じゃまをしない。
class SwipeNavigator extends StatefulWidget {
  const SwipeNavigator({
    super.key,
    required this.child,
    required this.onStep,
    this.vertical = false,
  });

  final Widget child;

  /// 1 = 次、-1 = 前
  final void Function(int dir) onStep;
  final bool vertical;

  @override
  State<SwipeNavigator> createState() => _SwipeNavigatorState();
}

class _SwipeNavigatorState extends State<SwipeNavigator> {
  double _dx = 0, _dy = 0;

  // トラックパッド・ホイールは細かく続けて届くので、ためてから1回だけ動かす
  double _wheelX = 0, _wheelY = 0;
  Timer? _cool;

  static const _dragMin = 60.0;
  static const _flingMin = 400.0;
  static const _wheelMin = 90.0;

  void _endDrag(double d, double? v) {
    final vel = v ?? 0;
    if (d.abs() > _dragMin || vel.abs() > _flingMin) {
      final dir = (vel.abs() > _flingMin ? vel : d) < 0 ? 1 : -1;
      widget.onStep(dir);
    }
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    if (_cool?.isActive ?? false) return;
    final d = e.scrollDelta;
    // 横の動き（トラックパッドの横スワイプ、Shift + ホイール）
    if (d.dx.abs() > d.dy.abs()) {
      _wheelX += d.dx;
      _wheelY = 0;
    } else if (widget.vertical) {
      _wheelY += d.dy;
      _wheelX = 0;
    } else {
      return;
    }
    final v = _wheelX.abs() > _wheelMin ? _wheelX : (_wheelY.abs() > _wheelMin ? _wheelY : 0);
    if (v != 0) {
      widget.onStep(v > 0 ? 1 : -1);
      _wheelX = _wheelY = 0;
      _cool = Timer(const Duration(milliseconds: 450), () {});
    }
  }

  @override
  void dispose() {
    _cool?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _dx = 0,
        onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
        onHorizontalDragEnd: (d) => _endDrag(_dx, d.primaryVelocity),
        onVerticalDragStart: widget.vertical ? (_) => _dy = 0 : null,
        onVerticalDragUpdate: widget.vertical ? (d) => _dy += d.delta.dy : null,
        onVerticalDragEnd:
            widget.vertical ? (d) => _endDrag(_dy, d.primaryVelocity) : null,
        child: widget.child,
      ),
    );
  }
}
