import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool get _supported => globalContext.has('Notification');

String notificationPermission() {
  if (!_supported) return 'unsupported';
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

Future<String> requestNotificationPermission() async {
  if (!_supported) return 'unsupported';
  try {
    final r = await web.Notification.requestPermission().toDart;
    return r.toDart;
  } catch (_) {
    return notificationPermission();
  }
}

bool showSystemNotification(String title, String body, {String? tag}) {
  if (notificationPermission() != 'granted') return false;
  try {
    final n = web.Notification(
      title,
      web.NotificationOptions(body: body, tag: tag ?? '', icon: 'icons/Icon-192.png'),
    );
    n.onclick = ((web.Event _) {
      web.window.focus();
      n.close();
    }).toJS;
    return true;
  } catch (_) {
    // iPhone の Safari などはホーム画面に追加したときだけ通知できる
    return false;
  }
}
