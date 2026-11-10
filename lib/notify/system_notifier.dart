// 端末（ブラウザ）の通知。Web では Notification API、それ以外は今のところ何もしない
export 'system_notifier_stub.dart'
    if (dart.library.js_interop) 'system_notifier_web.dart';
