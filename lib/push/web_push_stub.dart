bool pushSupported() => false;
bool pushIsIOS() => false;
bool pushStandalone() => false;

/// 許可を求めて購読し、購読情報（JSON 文字列）を返す
Future<String> pushSubscribe(String vapidKey) async =>
    throw UnsupportedError('unsupported');

/// この端末の購読（なければ空文字）
Future<String> pushCurrent() async => '';

Future<void> pushUnsubscribe() async {}
