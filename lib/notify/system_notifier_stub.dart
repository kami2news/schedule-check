/// 通知が使えるか（'granted' / 'denied' / 'default' / 'unsupported'）
String notificationPermission() => 'unsupported';

/// 通知の許可を求める。結果（notificationPermission と同じ値）を返す
Future<String> requestNotificationPermission() async => 'unsupported';

/// 通知を出す。出せたら true
bool showSystemNotification(String title, String body, {String? tag}) => false;
