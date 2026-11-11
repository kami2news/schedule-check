import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import '../store.dart';

/// 同期の状態
enum SyncState { connecting, synced, pending, offline }

extension SyncStateX on SyncState {
  String get label => switch (this) {
        SyncState.connecting => '接続中…',
        SyncState.synced => '同期済み',
        SyncState.pending => '送信待ちの変更があります',
        SyncState.offline => 'オフライン（つながったら同期します）',
      };
}

/// ログイン中のユーザーのデータを Firestore と同期する。
/// 保存場所: users/{uid}/events, users/{uid}/tasks, users/{uid}/calendars
class FirebaseSync implements RemoteSink {
  FirebaseSync(this.store, this.uid, {required this.onState});

  final AppStore store;
  final String uid;
  final void Function(SyncState) onState;

  final _subs = <StreamSubscription<dynamic>>[];
  final _pending = <String, bool>{};
  final _fromCache = <String, bool>{};
  bool _calendarsSeeded = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  void start() {
    onState(SyncState.connecting);
    _listen<Event>('events', Event.fromJson,
        (list) => store.applyRemote(events: list));
    _listen<TaskItem>('tasks', TaskItem.fromJson,
        (list) => store.applyRemote(tasks: list));
    _subs.add(_col('calendars')
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      _track('calendars', snap.metadata);
      final docs = [...snap.docs]..sort((a, b) =>
          ((a.data()['order'] as num?) ?? 0)
              .compareTo((b.data()['order'] as num?) ?? 0));
      final list = <CalendarDef>[];
      for (final d in docs) {
        try {
          list.add(CalendarDef.fromJson(d.data()));
        } catch (_) {}
      }
      store.applyRemote(calendars: list);
      // 新しいアカウント（サーバーにも何もない）には既定のカレンダーを書く
      if (list.isEmpty && !snap.metadata.isFromCache && !_calendarsSeeded) {
        _calendarsSeeded = true;
        store.seedRemoteCalendars();
      }
    }, onError: (_) => onState(SyncState.offline)));
  }

  void _listen<T>(String name, T Function(Map<String, dynamic>) fromJson,
      void Function(List<T>) apply) {
    _subs.add(_col(name).snapshots(includeMetadataChanges: true).listen((snap) {
      _track(name, snap.metadata);
      final list = <T>[];
      for (final d in snap.docs) {
        try {
          list.add(fromJson(d.data()));
        } catch (_) {
          // 壊れた1件だけ読み飛ばす
        }
      }
      apply(list);
    }, onError: (_) => onState(SyncState.offline)));
  }

  void _track(String name, SnapshotMetadata m) {
    _pending[name] = m.hasPendingWrites;
    _fromCache[name] = m.isFromCache;
    if (_pending.values.any((x) => x)) {
      onState(_fromCache.values.any((x) => x)
          ? SyncState.offline
          : SyncState.pending);
    } else if (_fromCache.values.any((x) => x)) {
      onState(SyncState.offline);
    } else {
      onState(SyncState.synced);
    }
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  Map<String, dynamic> _stamp(Map<String, dynamic> j) =>
      {...j, 'updatedAt': FieldValue.serverTimestamp()};

  @override
  void putEvent(Event e) => _col('events').doc(e.id).set(_stamp(e.toJson()));

  @override
  void removeEvent(String id) => _col('events').doc(id).delete();

  @override
  void putTask(TaskItem t) => _col('tasks').doc(t.id).set(_stamp(t.toJson()));

  @override
  void removeTask(String id) => _col('tasks').doc(id).delete();

  @override
  void putCalendar(CalendarDef c, int order) =>
      _col('calendars').doc(c.id).set(_stamp({...c.toJson(), 'order': order}));

  @override
  void removeCalendar(String id) => _col('calendars').doc(id).delete();

  /// アカウント削除用: このユーザーのデータをすべて消す
  Future<void> deleteAll() async {
    for (final name in ['events', 'tasks', 'calendars', 'pushSubs', 'pushQueue', 'pushTest']) {
      final snap = await _col(name).get();
      var batch = _db.batch();
      var n = 0;
      for (final d in snap.docs) {
        batch.delete(d.reference);
        if (++n % 400 == 0) {
          await batch.commit();
          batch = _db.batch();
        }
      }
      await batch.commit();
    }
  }
}
