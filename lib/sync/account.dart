import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../store.dart';
import '../firebase_options.dart';
import 'firebase_sync.dart';
import 'push_service.dart';

/// ログイン方法
enum SignInMethod { google, email }

/// アカウント（Firebase Authentication）とクラウド同期の窓口。
/// Firebase が未設定のときは [available] が false になり、何もしない。
class AccountService extends ChangeNotifier {
  AccountService(this.store);

  final AppStore store;

  bool available = false;

  /// Firebase は設定済みだが接続の準備に失敗した（オフライン・ブロックなど）
  bool connectFailed = false;
  User? user;
  SyncState syncState = SyncState.connecting;
  FirebaseSync? _sync;
  StreamSubscription<User?>? _authSub;

  /// アプリを閉じていても届く通知（ログイン中のみ）
  late final PushService push = PushService(store);

  bool get signedIn => user != null;

  /// 起動時に呼ぶ。設定が無ければ端末内だけで動かす
  Future<void> init() async {
    final FirebaseOptions options;
    try {
      // flutterfire configure で作られる設定（未設定なら例外になる）
      options = DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      return;
    }
    try {
      // 読み込めない環境（オフライン・拡張機能によるブロック等）で待ち続けないよう時間を区切る
      await Firebase.initializeApp(options: options)
          .timeout(const Duration(seconds: 15));
      // オフラインでも使えるよう、端末にキャッシュする
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true);
      available = true;
    } catch (e) {
      debugPrint('Firebase の初期化に失敗: $e');
      connectFailed = true;
      notifyListeners();
      return;
    }
    notifyListeners();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  Future<void> _onUser(User? u) async {
    if (u?.uid == user?.uid) {
      user = u;
      notifyListeners();
      return;
    }
    await _sync?.stop();
    _sync = null;
    push.stop();
    user = u;
    if (u == null) {
      store.detachRemote();
    } else {
      final sync = FirebaseSync(store, u.uid, onState: (s) {
        if (s == syncState) return;
        syncState = s;
        notifyListeners();
      });
      _sync = sync;
      store.attachRemote(sync);
      sync.start();
      push.start(u.uid);
    }
    notifyListeners();
  }

  // ---- ログイン ----

  Future<void> signIn(SignInMethod m, {String? email, String? password}) async {
    final auth = FirebaseAuth.instance;
    switch (m) {
      case SignInMethod.google:
        await _signInWithProvider(GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'}));
      case SignInMethod.email:
        await auth.signInWithEmailAndPassword(
            email: email!.trim(), password: password!);
    }
  }

  /// Web はポップアップ、スマホアプリはブラウザ画面（SFSafariViewController / Custom Tabs）でログイン
  Future<void> _signInWithProvider(AuthProvider p) async {
    final auth = FirebaseAuth.instance;
    if (kIsWeb) {
      await auth.signInWithPopup(p);
    } else {
      await auth.signInWithProvider(p);
    }
  }

  Future<void> register(
      {required String email, required String password, String? name}) async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    if (name != null && name.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.reload();
      user = FirebaseAuth.instance.currentUser;
      notifyListeners();
    }
  }

  Future<void> sendPasswordReset(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

  Future<void> updateDisplayName(String name) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await u.updateDisplayName(name.trim());
    await u.reload();
    user = FirebaseAuth.instance.currentUser;
    notifyListeners();
  }

  /// ログアウト。この端末への通知も止める（別の人が使っても届かないように）
  Future<void> signOut() async {
    try {
      await push.disableHere().timeout(const Duration(seconds: 5));
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  /// アカウントとクラウド上のデータを削除する
  Future<void> deleteAccount() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      await push.disableHere().timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _sync?.deleteAll();
    await u.delete();
  }

  /// ログインに使った方法の表示名
  String get providerLabel {
    final ids = user?.providerData.map((p) => p.providerId).toSet() ?? {};
    if (ids.contains('google.com')) return 'Google アカウント';
    if (ids.contains('password')) return 'メールアドレス';
    return '';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sync?.stop();
    push.dispose();
    super.dispose();
  }
}

/// Firebase のエラーを日本語の説明にする
String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'user-disabled':
        return 'このアカウントは無効になっています';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスかパスワードが違います';
      case 'email-already-in-use':
        return 'このメールアドレスはすでに登録されています。ログインしてください';
      case 'weak-password':
        return 'パスワードは6文字以上にしてください';
      case 'too-many-requests':
        return '試行回数が多すぎます。しばらくしてからもう一度お試しください';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'ログインがキャンセルされました';
      case 'popup-blocked':
        return 'ポップアップがブロックされました。ブラウザでこのサイトのポップアップを許可してください';
      case 'account-exists-with-different-credential':
        return 'このメールアドレスは別のログイン方法で登録されています。最初に使った方法でログインしてください';
      case 'requires-recent-login':
        return '安全のため、いったんログアウトしてもう一度ログインしてから操作してください';
      case 'network-request-failed':
        return 'ネットワークにつながっていません';
      case 'operation-not-allowed':
        return 'このログイン方法はまだ有効になっていません（Firebase の設定が必要です）';
      case 'unauthorized-domain':
        return 'このサイトのドメインが Firebase で許可されていません（承認済みドメインに追加が必要です）';
    }
    return 'ログインできませんでした（${e.code}）';
  }
  return 'エラーが発生しました: $e';
}

/// ウィジェットからアカウントを参照する
class AccountScope extends InheritedNotifier<AccountService> {
  const AccountScope(
      {super.key, required AccountService account, required super.child})
      : super(notifier: account);

  static AccountService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()!.notifier!;

  static AccountService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccountScope>()!.notifier!;
}
