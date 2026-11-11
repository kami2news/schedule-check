import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../push/push_queue.dart';
import '../push/web_push.dart';
import '../store.dart';

/// この端末のプッシュ通知の状態
enum PushStatus {
  /// 確認中
  checking,

  /// この端末・ブラウザでは使えない
  unsupported,

  /// iPhone で、ホーム画面に追加したアプリから開いていない
  needsHomeScreen,

  /// サーバーの準備がまだ（Railway が動いていない・ルール未更新など）
  serverNotReady,

  /// 受け取っていない
  off,

  /// 受け取る
  on,
}

/// アプリを閉じていても届く通知（Web プッシュ）の窓口。
///
/// - ログイン中は「これから鳴らす通知」の一覧を users/{uid}/pushQueue/main に書く
/// - 端末の購読情報を users/{uid}/pushSubs/{id} に置く
/// - Railway のサーバーが両方を見て、時刻になったら送る（server/ フォルダ）
class PushService extends ChangeNotifier {
  PushService(this.store);

  final AppStore store;

  String? _uid;
  PushStatus status = PushStatus.checking;
  String? _vapidKey;
  Timer? _debounce;
  Timer? _refresh;
  String _lastQueue = '';

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _queueDoc =>
      _db.collection('users').doc(_uid).collection('pushQueue').doc('main');

  /// ログインしたときに呼ぶ
  void start(String uid) {
    _uid = uid;
    _lastQueue = '';
    store.addListener(_scheduleWrite);
    _scheduleWrite();
    // 時間がたつと「30日先まで」の範囲がずれるので、開いている間はときどき書き直す
    _refresh = Timer.periodic(const Duration(hours: 3), (_) => _scheduleWrite());
    unawaited(refreshStatus());
  }

  /// ログアウトしたときに呼ぶ
  void stop() {
    store.removeListener(_scheduleWrite);
    _debounce?.cancel();
    _refresh?.cancel();
    _uid = null;
  }

  void _scheduleWrite() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _writeQueue);
  }

  Future<void> _writeQueue() async {
    if (_uid == null) return;
    final items = buildPushQueue(store.events, store.tasks, DateTime.now());
    final json = jsonEncode(items);
    if (json == _lastQueue) return;
    _lastQueue = json;
    try {
      await _queueDoc.set({
        'items': items,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('通知の一覧を保存できませんでした: $e');
      _lastQueue = '';
    }
  }

  /// サーバーが公開している鍵（VAPID 公開鍵）。読めなければ null
  Future<String?> _loadKey() async {
    if (_vapidKey != null) return _vapidKey;
    try {
      final d = await _db.collection('public').doc('push').get();
      final k = d.data()?['vapidPublicKey'];
      if (k is String && k.isNotEmpty) _vapidKey = k;
    } catch (_) {}
    return _vapidKey;
  }

  String get _subId => store.uiValue('pushSubId') ?? '';

  /// この端末の状態を調べ直す。購読ボタンを押す前に鍵も読んでおく
  /// （iPhone では、押した直後に許可を求めないと断られるため）
  Future<void> refreshStatus() async {
    if (!kIsWeb || !pushSupported()) {
      // iPhone の Safari はホーム画面に追加したアプリでだけ使える
      status = kIsWeb && pushIsIOS() && !pushStandalone()
          ? PushStatus.needsHomeScreen
          : PushStatus.unsupported;
      notifyListeners();
      return;
    }
    final key = await _loadKey();
    if (key == null) {
      status = PushStatus.serverNotReady;
    } else {
      final cur = await pushCurrent();
      if (cur.isEmpty) {
        // 端末側の登録が消えている（許可の取り消し・アプリの入れ直しなど）
        if (_subId.isNotEmpty) {
          store.setUiValue('pushSubId', '');
          store.setUiValue('pushOn', '');
        }
        status = PushStatus.off;
      } else if (_subId.isEmpty) {
        status = PushStatus.off;
      } else {
        status = PushStatus.on;
        unawaited(_repairSubscription(cur));
      }
    }
    notifyListeners();
  }

  Map<String, dynamic> _subDoc(Map<String, dynamic> sub) => {
        'endpoint': sub['endpoint'],
        'keys': sub['keys'],
        'device': pushIsIOS() ? 'iPhone / iPad' : 'ブラウザ',
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// サーバー側の宛先が消えていたら書き直す（送信失敗でサーバーが消した場合や、
  /// ブラウザが宛先を作り直した場合）
  Future<void> _repairSubscription(String raw) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final sub = jsonDecode(raw) as Map<String, dynamic>;
      final id = subscriptionId(sub['endpoint'] as String);
      final col = _db.collection('users').doc(uid).collection('pushSubs');
      if (id != _subId) {
        // 宛先が変わった: 古いものを消して新しいものを登録
        await col.doc(_subId).delete();
        await col.doc(id).set(_subDoc(sub));
        store.setUiValue('pushSubId', id);
      } else if (!(await col.doc(id).get()).exists) {
        await col.doc(id).set(_subDoc(sub));
      }
    } catch (e) {
      debugPrint('通知の宛先を確認できませんでした: $e');
    }
  }

  /// この端末で受け取る。ボタンを押した処理の中で、待たずに呼ぶこと
  Future<void> enableHere() async {
    final key = _vapidKey;
    if (key == null || _uid == null) {
      await refreshStatus();
      throw StateError('通知サーバーの準備ができていません');
    }
    final String raw;
    try {
      raw = await pushSubscribe(key);
    } catch (e) {
      final s = '$e';
      if (s.contains('permission:denied')) {
        throw StateError('通知がブロックされています。端末の設定でこのアプリの通知を許可してください');
      }
      if (s.contains('permission:')) throw StateError('通知が許可されませんでした');
      throw StateError('この端末では通知を登録できませんでした（$s）');
    }
    final sub = jsonDecode(raw) as Map<String, dynamic>;
    final id = subscriptionId(sub['endpoint'] as String);
    await _db.collection('users').doc(_uid).collection('pushSubs').doc(id).set(_subDoc(sub));
    store.setUiValue('pushSubId', id);
    store.setUiValue('pushOn', '1');
    // 一覧がまだサーバーに無ければすぐ書く
    _lastQueue = '';
    await _writeQueue();
    status = PushStatus.on;
    notifyListeners();
  }

  /// この端末では受け取らない（ログアウト時にも呼ぶ）
  Future<void> disableHere() async {
    final id = _subId;
    await pushUnsubscribe();
    if (id.isNotEmpty && _uid != null) {
      try {
        await _db.collection('users').doc(_uid).collection('pushSubs').doc(id).delete();
      } catch (_) {}
    }
    store.setUiValue('pushSubId', '');
    store.setUiValue('pushOn', '');
    if (status == PushStatus.on) status = PushStatus.off;
    notifyListeners();
  }

  /// サーバーにテスト通知を頼む（届けば設定は完了）
  Future<void> sendTest() async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('pushTest').doc('req').set({
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// 購読ごとの文書 ID（送り先 URL を base64url にしたもの。どの環境でも同じ値になる）
String subscriptionId(String endpoint) =>
    base64Url.encode(utf8.encode(endpoint)).replaceAll('=', '');
