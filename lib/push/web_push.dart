// プッシュ通知の登録（Web のみ。web/push.js を呼ぶ）
export 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart';
