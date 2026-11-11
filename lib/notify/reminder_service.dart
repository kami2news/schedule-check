import 'dart:async';

import '../reminders.dart';
import '../store.dart';
import 'system_notifier.dart';

/// アプリを開いている間、通知の時刻になった予定・タスクを知らせる。
///
/// ブラウザの通知が許可されていればそれを出し、あわせて画面内にも表示する
/// （[onFire]）。前回の確認から今までの分をまとめて調べるので、
/// タブが裏で止まっていても戻ったときに出る（ただし [catchUp] より古いものは出さない）。
class ReminderService {
  ReminderService(
    this.store, {
    this.onFire,
    this.interval = const Duration(seconds: 20),
    this.catchUp = const Duration(minutes: 30),
  });

  final AppStore store;
  final void Function(ReminderItem item, bool systemShown)? onFire;
  final Duration interval;
  final Duration catchUp;

  Timer? _timer;
  DateTime? _last;

  static const _key = 'reminderCheckedAt';

  void start() {
    final now = DateTime.now();
    final saved = DateTime.tryParse(store.uiValue(_key) ?? '');
    final floor = now.subtract(catchUp);
    _last = saved == null || saved.isBefore(floor) ? floor : saved;
    tick(now);
    _timer = Timer.periodic(interval, (_) => tick(DateTime.now()));
  }

  /// [now] までに鳴らすべき通知を出す。出したものを返す
  List<ReminderItem> tick(DateTime now) {
    final from = _last ?? now.subtract(interval);
    if (!now.isAfter(from)) return const [];
    final items = remindersBetween(store.events, store.tasks, from, now);
    _last = now;
    store.setUiValue(_key, now.toIso8601String());
    // この端末でプッシュ通知を受け取っているなら、そちらと二重にならないよう画面内だけにする
    final pushOn = store.uiValue('pushOn') == '1';
    for (final r in items) {
      final shown = !pushOn && showSystemNotification(r.title, r.body, tag: r.key);
      onFire?.call(r, shown);
    }
    return items;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
