import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

double? _cached;

/// ホーム画面から開いた（standalone）とき、画面の下のホームバー（横棒）の分の余白。
/// Flutter の Web は iPhone の安全な余白（safe-area-inset-bottom）を受け取れないことがあるので、
/// CSS の env() で測り、測れなければ iPhone（ホームバーのある機種）は 20px にする
double standaloneBottomInset() => _cached ??= _measure();

double _measure() {
  try {
    final standalone = web.window.matchMedia('(display-mode: standalone)').matches ||
        (globalContext['navigator'] as JSObject?)?['standalone']?.dartify() == true;
    if (!standalone) return 0;
    final probe = web.document.createElement('div') as web.HTMLElement;
    probe.style.cssText = 'position:fixed;left:0;bottom:0;width:0;height:0;'
        'padding-bottom:env(safe-area-inset-bottom);visibility:hidden;pointer-events:none';
    web.document.body?.append(probe);
    final h = probe.getBoundingClientRect().height;
    probe.remove();
    if (h > 0) return h;
    final ua = web.window.navigator.userAgent;
    final s = web.window.screen;
    if (ua.contains('iPhone') && math.max(s.width, s.height) >= 812) return 20;
  } catch (_) {}
  return 0;
}
