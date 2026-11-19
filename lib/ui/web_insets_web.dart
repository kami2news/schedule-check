import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// ホーム画面から開いた（standalone）か
bool get _standalone {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches ||
        (globalContext['navigator'] as JSObject?)?['standalone']?.dartify() == true;
  } catch (_) {
    return false;
  }
}

/// ホーム画面アプリでは、ページを画面いっぱい（時計の帯・ホームバーの下まで）に広げ、
/// 安全な余白はアプリ側で取る。
/// （iPhone のホーム画面アプリは、時計の帯の分ずれて下が画面の外に隠れることがあるため。
///   Flutter は起動時に viewport の設定を自分のもので置き換えるので、起動後に viewport-fit=cover を足し直す）
void prepareStandalone() {
  if (!_standalone) return;
  try {
    final meta = web.document.querySelector('meta[name="viewport"]');
    if (meta == null) return;
    final c = meta.getAttribute('content') ?? '';
    if (!c.contains('viewport-fit')) {
      meta.setAttribute('content', c.isEmpty ? 'viewport-fit=cover' : '$c, viewport-fit=cover');
    }
  } catch (_) {}
}

double _env(String side) {
  final probe = web.document.createElement('div') as web.HTMLElement;
  probe.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;'
      'padding-top:env(safe-area-inset-$side);visibility:hidden;pointer-events:none';
  web.document.body?.append(probe);
  final h = probe.getBoundingClientRect().height;
  probe.remove();
  return h.toDouble();
}

String? _key;
({double top, double bottom}) _cached = (top: 0, bottom: 0);

/// ホーム画面アプリで足す安全な余白（上: 時計の帯、下: ホームバー）。
/// CSS の env(safe-area-inset-*) で測る。下が測れないときは、ホームバーのある iPhone は 20px
({double top, double bottom}) standaloneInsets() {
  if (!_standalone) return (top: 0, bottom: 0);
  try {
    final key = '${web.window.innerWidth}x${web.window.innerHeight}';
    if (key == _key) return _cached;
    _key = key;
    final top = _env('top');
    var bottom = _env('bottom');
    if (bottom <= 0) {
      final s = web.window.screen;
      if (web.window.navigator.userAgent.contains('iPhone') &&
          math.max(s.width, s.height) >= 812) {
        bottom = 20;
      }
    }
    return _cached = (top: top, bottom: bottom);
  } catch (_) {
    return (top: 0, bottom: 0);
  }
}
