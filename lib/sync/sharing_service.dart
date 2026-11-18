import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import '../sharing.dart';
import '../store.dart';

/// 招待した相手（メールアドレスと、編集できるか）
class ShareMember {
  ShareMember(this.email, {required this.canEdit});
  final String email;
  final bool canEdit;
}

/// 予定の共有（ログイン中のみ）。
///
/// - メールで招待: shareAcl/{自分の uid} に招待した相手のメールアドレスを書く。
///   相手がそのアドレスでログインすると、Firestore のルールで自分の予定を読める（「編集可」なら書ける）
/// - リンクで共有（表示のみ）: shares/{推測できない文字列} に、AI がそのまま読める文章と
///   閲覧ページ用の一覧を書く。リンクを知っている人は誰でも読める（ログイン不要）
/// - 招待されている側: shareAcl を「自分のメールアドレスが入っているもの」で探し、
///   相手の予定・カレンダーを読んでストアに並べる
class SharingService extends ChangeNotifier implements SharedSink {
  SharingService(this.store);

  final AppStore store;

  String? _uid;
  String _email = '';
  String _name = '';

  /// 招待した相手
  List<ShareMember> members = [];

  /// リンクで共有しているときの文字列（していなければ null）
  String? linkToken;

  /// 共有の操作でエラーが出たとき（ルールが未更新など）
  String? error;

  final _subs = <StreamSubscription<dynamic>>[];
  final _incoming = <String, List<StreamSubscription<dynamic>>>{};
  Timer? _debounce;
  String _lastPublished = '';

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _acl =>
      _db.collection('shareAcl').doc(_uid);

  bool get signedIn => _uid != null;

  /// ログインしたときに呼ぶ
  void start(String uid, {required String? email, required String? name}) {
    _uid = uid;
    _email = (email ?? '').trim().toLowerCase();
    _name = (name ?? '').trim().isNotEmpty ? name!.trim() : _email;
    store.sharedSink = this;
    // 自分の共有の設定
    _subs.add(_acl.snapshots().listen((snap) {
      final d = snap.data() ?? {};
      final all = [for (final x in (d['members'] as List?) ?? []) '$x'];
      final editors = {for (final x in (d['editors'] as List?) ?? []) '$x'};
      members = [for (final m in all) ShareMember(m, canEdit: editors.contains(m))];
      linkToken = d['linkToken'] as String?;
      error = null;
      notifyListeners();
      _schedulePublish();
    }, onError: (Object e) {
      error = '共有の設定を読めませんでした（Firestore のルールが古い可能性があります）';
      notifyListeners();
    }));
    // 招待されている共有
    if (_email.isNotEmpty) {
      _subs.add(_db
          .collection('shareAcl')
          .where('members', arrayContains: _email)
          .snapshots()
          .listen(_onIncoming, onError: (Object e) {
        debugPrint('共有された予定を読めませんでした: $e');
      }));
    }
    store.addListener(_schedulePublish);
  }

  /// ログアウトしたときに呼ぶ
  Future<void> stop() async {
    store.removeListener(_schedulePublish);
    _debounce?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    for (final list in _incoming.values) {
      for (final s in list) {
        await s.cancel();
      }
    }
    _incoming.clear();
    store.clearShared();
    store.sharedSink = null;
    _uid = null;
    members = [];
    linkToken = null;
    _lastPublished = '';
  }

  // ---- 招待されている側 ----

  void _onIncoming(QuerySnapshot<Map<String, dynamic>> snap) {
    final owners = <String>{};
    for (final doc in snap.docs) {
      final owner = doc.id;
      if (owner == _uid) continue;
      owners.add(owner);
      final d = doc.data();
      final canEdit = ((d['editors'] as List?) ?? []).contains(_email);
      final name = (d['ownerName'] as String?)?.trim();
      final ownerName = name == null || name.isEmpty ? '共有' : name;
      _incoming[owner]?.forEach((s) => s.cancel());
      var events = <Event>[];
      var cals = <CalendarDef>[];
      void apply() => store.applyShared(SharedSource(
          owner: owner,
          ownerName: ownerName,
          canEdit: canEdit,
          events: events,
          calendars: cals));
      final user = _db.collection('users').doc(owner);
      _incoming[owner] = [
        user.collection('events').snapshots().listen((s) {
          events = [
            for (final x in s.docs)
              if (_tryEvent(x.data()) case final e?) e
          ];
          apply();
        }, onError: (_) {}),
        user.collection('calendars').snapshots().listen((s) {
          final docs = [...s.docs]..sort((a, b) => ((a.data()['order'] as num?) ?? 0)
              .compareTo((b.data()['order'] as num?) ?? 0));
          cals = [
            for (final x in docs)
              if (_tryCal(x.data()) case final c?) c
          ];
          apply();
        }, onError: (_) {}),
      ];
    }
    // 招待を外された相手
    for (final o in _incoming.keys.where((o) => !owners.contains(o)).toList()) {
      for (final s in _incoming.remove(o)!) {
        s.cancel();
      }
      store.removeShared(o);
    }
  }

  static Event? _tryEvent(Map<String, dynamic> j) {
    try {
      return Event.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  static CalendarDef? _tryCal(Map<String, dynamic> j) {
    try {
      return CalendarDef.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  @override
  void putSharedEvent(String owner, Event e) {
    _db.collection('users').doc(owner).collection('events').doc(e.id).set(
        {...e.toJson(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  void removeSharedEvent(String owner, String id) {
    _db.collection('users').doc(owner).collection('events').doc(id).delete();
  }

  // ---- 招待する側（メール） ----

  Future<void> _saveAcl(List<ShareMember> list, {String? token, bool clearToken = false}) {
    return _acl.set({
      'ownerName': _name,
      'ownerEmail': _email,
      'members': [for (final m in list) m.email],
      'editors': [for (final m in list) if (m.canEdit) m.email],
      if (token != null) 'linkToken': token,
      if (clearToken) 'linkToken': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// メールアドレスで招待する（すでにいれば権限を変える）
  Future<void> invite(String email, {required bool canEdit}) {
    final e = email.trim().toLowerCase();
    final list = [
      for (final m in members)
        if (m.email != e) m,
      ShareMember(e, canEdit: canEdit),
    ];
    return _saveAcl(list);
  }

  Future<void> setCanEdit(String email, bool canEdit) => _saveAcl([
        for (final m in members)
          m.email == email ? ShareMember(email, canEdit: canEdit) : m,
      ]);

  Future<void> removeMember(String email) =>
      _saveAcl([for (final m in members) if (m.email != email) m]);

  // ---- リンクで共有（表示のみ） ----

  static String _newToken() {
    final r = Random.secure();
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(24, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// 共有リンクを作る（すでにあれば作り直す。古いリンクは見られなくなる）
  Future<void> createLink() async {
    final old = linkToken;
    final t = _newToken();
    _lastPublished = '';
    await _publish(t);
    await _saveAcl(members, token: t);
    if (old != null) await _db.collection('shares').doc(old).delete();
  }

  /// リンクでの共有をやめる（リンクは見られなくなる）
  Future<void> deleteLink() async {
    final old = linkToken;
    await _saveAcl(members, clearToken: true);
    if (old != null) await _db.collection('shares').doc(old).delete();
  }

  void _schedulePublish() {
    if (linkToken == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => _publish(linkToken!));
  }

  /// 共有リンクの中身を書き直す（自分の予定とタスクだけ。招待されている相手の予定は含めない）
  Future<void> _publish(String token) async {
    if (_uid == null) return;
    final now = DateTime.now();
    final r = shareRange(now);
    final mine = {for (final c in store.calendars) c.id};
    final items = buildShareItems(
      from: r.from,
      to: r.to,
      eventsOn: (d) => store.eventsOn(d).where((e) => mine.contains(e.calendarId)).toList(),
      calendarOf: store.calendarOf,
    );
    final text = buildShareText(
        ownerName: _name.isEmpty ? '共有' : _name,
        now: now,
        from: r.from,
        to: r.to,
        items: items,
        tasks: store.tasks);
    final payload = jsonEncode([for (final i in items) i.toJson()]);
    // 時刻の行（「〜時点」）以外が変わっていなければ書かない
    final key = '$payload|${store.tasks.where((t) => !t.done).map((t) => t.toJson()).toList()}';
    if (key == _lastPublished) return;
    _lastPublished = key;
    try {
      await _db.collection('shares').doc(token).set({
        'owner': _uid,
        'ownerName': _name,
        'text': text,
        'items': payload,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _lastPublished = '';
      error = '共有リンクの内容を保存できませんでした（Firestore のルールが古い可能性があります）';
      notifyListeners();
    }
  }

  /// アカウントを削除するとき: 共有リンクを消し、招待もすべて外す
  Future<void> stopSharingAll() async {
    final old = linkToken;
    if (old != null) await _db.collection('shares').doc(old).delete();
    if (_uid != null) await _acl.delete();
  }

  // ---- リンク ----

  /// 人が見る用のリンク（このアプリの閲覧ページ）
  static String viewUrl(String token) {
    final base = Uri.base.removeFragment().replace(query: '');
    final s = base.toString().replaceAll(RegExp(r'\?$'), '');
    return '$s?share=$token';
  }

  /// AI に渡す用のリンク（予定の文章だけを返す。ログイン不要）
  static String aiUrl(String token) {
    final project = Firebase.app().options.projectId;
    return 'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/shares/$token?mask.fieldPaths=text';
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// 共有リンクの閲覧ページ用: shares/{token} を読む（ログイン不要）
Future<({String ownerName, String text, List<ShareItem> items, DateTime? updatedAt})?>
    loadSharedLink(String token) async {
  final d = await FirebaseFirestore.instance.collection('shares').doc(token).get();
  final j = d.data();
  if (j == null) return null;
  final items = [
    for (final x in (jsonDecode(j['items'] as String? ?? '[]') as List))
      ShareItem.fromJson(Map<String, dynamic>.from(x as Map)),
  ];
  return (
    ownerName: j['ownerName'] as String? ?? '',
    text: j['text'] as String? ?? '',
    items: items,
    updatedAt: (j['updatedAt'] as Timestamp?)?.toDate(),
  );
}
