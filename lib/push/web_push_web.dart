import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('schedulePush')
external _Push? get _push;

extension type _Push(JSObject _) implements JSObject {
  external bool supported();
  external bool isIOS();
  external bool standalone();
  external JSPromise<JSString> subscribe(JSString key);
  external JSPromise<JSString> current();
  external JSPromise<JSAny?> unsubscribe();
}

bool get _loaded => globalContext.has('schedulePush');

bool pushSupported() {
  try {
    return _loaded && _push!.supported();
  } catch (_) {
    return false;
  }
}

bool pushIsIOS() {
  try {
    return _loaded && _push!.isIOS();
  } catch (_) {
    return false;
  }
}

bool pushStandalone() {
  try {
    return _loaded && _push!.standalone();
  } catch (_) {
    return false;
  }
}

Future<String> pushSubscribe(String vapidKey) async {
  if (!_loaded) throw UnsupportedError('unsupported');
  try {
    return (await _push!.subscribe(vapidKey.toJS).toDart).toDart;
  } catch (e) {
    // JS の Error の文言（'permission:denied' など）を含めて投げ直す
    throw StateError('$e');
  }
}

Future<String> pushCurrent() async {
  if (!_loaded) return '';
  try {
    return (await _push!.current().toDart).toDart;
  } catch (_) {
    return '';
  }
}

Future<void> pushUnsubscribe() async {
  if (!_loaded) return;
  try {
    await _push!.unsubscribe().toDart;
  } catch (_) {}
}
