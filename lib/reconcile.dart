import 'dart:math' as math;

import 'models.dart';
import 'parser.dart';

/// 取り込み候補と、すでにある予定・タスクとの照合結果の種類
enum MatchKind {
  /// どれとも関係しない新しい予定
  fresh,

  /// すでに同じ予定がある
  duplicate,

  /// 既存の予定の日時が変わった連絡
  update,

  /// 既存の予定が中止になった連絡
  cancel,

  /// 新しい予定だが、ほかの予定と時間が重なる
  conflict,
}

/// 照合の結果
class MatchResult {
  MatchResult(this.kind,
      {this.event,
      this.task,
      this.conflicts = const [],
      this.canApply = true,
      this.enrich = false,
      this.occurrence});

  final MatchKind kind;

  /// 対象になる既存の予定（同じ・変更・中止のとき）
  final Event? event;

  /// 対象になる既存のタスク
  final TaskItem? task;

  /// 時間が重なる予定
  final List<Event> conflicts;

  /// 反映できるか（毎週の予定は1日だけの変更ができないので false）
  final bool canApply;

  /// 同じ予定に、メール側にしかない情報（リンク・場所・メモ）を足せるか
  final bool enrich;

  /// 対象が毎週の予定のとき、その回の日付（この回のみ／以降に反映する）
  final DateTime? occurrence;

  bool get isRecurring => occurrence != null;

  bool get hasTarget => event != null || task != null;

  /// 最初にチェックを入れておくか（削除は念のため手動で選んでもらう）
  bool get defaultSelected => switch (kind) {
        MatchKind.fresh || MatchKind.conflict => true,
        MatchKind.duplicate => enrich,
        MatchKind.update => canApply,
        // 毎週の予定の1回分を消すだけなら最初からチェック、単発の予定の削除は手動で
        MatchKind.cancel => canApply && isRecurring,
      };
}

final _cancelRe = RegExp(r'休講|中止|キャンセル|取りやめ|取り止め|取りやめ|見送り|なくなりました|なしになりました');
final _changeRe = RegExp(r'変更|延期|振替|振り替え|繰り上げ|繰り下げ|日程調整|再設定|移動');

/// タイトルの比較用に、記号・空白・連絡の定型語を取り除く
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[\s　・、。,.\-–—_/|｜()（）\[\]【】「」『』:：!！?？~〜～#＃]'), '')
    .replaceAll(
        RegExp(r'のご案内|のお知らせ|について|の変更|変更|中止|休講|キャンセル|延期|確定|予定|のお願い'), '');

Set<String> _bigrams(String s) {
  if (s.length < 2) return {s};
  return {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
}

/// タイトルの似ている度合い（0〜1）
double titleSimilarity(String a, String b) {
  final x = _norm(a), y = _norm(b);
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  final shorter = x.length <= y.length ? x : y;
  final longer = x.length <= y.length ? y : x;
  // 「面談」と「研究室面談」のように、一方がもう一方を含む
  if (shorter.length >= 2 && longer.contains(shorter)) return 0.85;
  final bx = _bigrams(x), by = _bigrams(y);
  final inter = bx.intersection(by).length;
  return inter / (bx.length + by.length - inter);
}

const _similar = 0.5;

int _endOf(int start, int? end) => end ?? defaultEnd(start);

bool _sameTime(Candidate c, Event e) {
  if (c.startMin == null || e.startMin == null) {
    return c.startMin == null && e.startMin == null;
  }
  if ((c.startMin! - e.startMin!).abs() > 15) return false;
  if (c.endMin == null || e.endMin == null) return true;
  return (c.endMin! - e.endMin!).abs() <= 15;
}

bool _hasExtra(Candidate c, {String url = '', String place = '', String note = ''}) {
  final cn = c.note.trim();
  return (c.url.trim().isNotEmpty && url.trim().isEmpty) ||
      (c.place.trim().isNotEmpty && place.trim().isEmpty) ||
      (cn.isNotEmpty && !note.contains(cn));
}

/// 候補を、すでにある予定・タスクと照合する
MatchResult reconcile(Candidate c, List<Event> events, List<TaskItem> tasks) {
  final text = '${c.source} ${c.title}';
  final isCancel = _cancelRe.hasMatch(text);
  final isChange = !isCancel && _changeRe.hasMatch(text);

  if (c.type == ImportType.task) return _reconcileTask(c, tasks, isCancel, isChange);

  final day = dateOnly(c.date);
  final sameDay = events.where((e) => e.occursOn(day)).toList();

  Event? best(Iterable<Event> list) {
    Event? r;
    var score = _similar;
    for (final e in list) {
      final s = titleSimilarity(c.title, e.title);
      if (s >= score) {
        // 同点なら開始時刻が近いほう
        if (r != null && s == score && c.startMin != null) {
          final dr = ((r.startMin ?? 0) - c.startMin!).abs();
          final de = ((e.startMin ?? 0) - c.startMin!).abs();
          if (de >= dr) continue;
        }
        r = e;
        score = s;
      }
    }
    return r;
  }

  // ---- 中止の連絡 ----
  if (isCancel) {
    var target = best(sameDay);
    // 「休講」だけのように名前が無い場合、その日の授業／シフトが1つならそれとみなす
    if (target == null && _norm(c.title).isEmpty) {
      final same = sameDay.where((e) => e.calendarId == c.calendarId).toList();
      if (same.length == 1) target = same.first;
    }
    if (target == null) return MatchResult(MatchKind.cancel, canApply: false);
    return MatchResult(MatchKind.cancel,
        event: target, occurrence: target.weekly ? day : null);
  }

  // ---- 同じ日に似た予定がある ----
  final target = best(sameDay);
  if (target != null) {
    if (_sameTime(c, target)) {
      return MatchResult(MatchKind.duplicate,
          event: target,
          enrich: _hasExtra(c,
              url: target.url, place: target.place, note: target.note));
    }
    return MatchResult(MatchKind.update,
        event: target, occurrence: target.weekly ? day : null);
  }

  // ---- 「変更」の連絡なら、前後3週間から元の予定を探す ----
  if (isChange) {
    final near = events.where((e) =>
        !e.weekly && dateOnly(e.date).difference(day).inDays.abs() <= 21);
    final t = best(near);
    if (t != null) return MatchResult(MatchKind.update, event: t);
  }

  // ---- 時間の重なり ----
  if (c.startMin != null) {
    final s = c.startMin!, e = _endOf(s, c.endMin);
    final over = sameDay.where((x) {
      if (x.startMin == null) return false;
      final xs = x.startMin!, xe = _endOf(xs, x.endMin);
      return s < xe && xs < e;
    }).toList();
    if (over.isNotEmpty) return MatchResult(MatchKind.conflict, conflicts: over);
  }
  return MatchResult(MatchKind.fresh);
}

MatchResult _reconcileTask(
    Candidate c, List<TaskItem> tasks, bool isCancel, bool isChange) {
  TaskItem? target;
  var score = _similar;
  for (final t in tasks.where((t) => !t.done)) {
    final s = titleSimilarity(c.title, t.title);
    // 期限が同じものを優先し、違う期限は「変更・中止」の連絡のときだけ見る
    final sameDue = t.due != null && dateOnly(t.due!) == dateOnly(c.date);
    if (!sameDue && !isChange && !isCancel) continue;
    final adj = sameDue ? s + 0.01 : s;
    if (adj >= score) {
      target = t;
      score = adj;
    }
  }
  if (target == null) {
    return isCancel ? MatchResult(MatchKind.cancel, canApply: false) : MatchResult(MatchKind.fresh);
  }
  if (isCancel) return MatchResult(MatchKind.cancel, task: target);
  final sameDue =
      target.due != null && dateOnly(target.due!) == dateOnly(c.date);
  final sameMin = c.startMin == null || target.dueMin == c.startMin;
  if (sameDue && sameMin) {
    return MatchResult(MatchKind.duplicate,
        task: target, enrich: _hasExtra(c, url: target.url, note: target.note));
  }
  return MatchResult(MatchKind.update, task: target);
}

/// 予定の時間表示（照合結果の説明用）
String describeEvent(Event e) {
  final d = e.repeat != null ? e.repeat!.label(e.date) : fmtDate(e.date);
  return '$d ${e.timeLabel}';
}

String describeCandidateTime(Candidate c) {
  final d = fmtDate(c.date);
  if (c.startMin == null) return c.type == ImportType.task ? d : '$d 終日';
  if (c.type == ImportType.task) return '$d ${fmtMin(c.startMin!)}';
  final e = c.endMin ?? defaultEnd(c.startMin!);
  return '$d ${fmtMin(c.startMin!)}–${fmtMin(math.min(e, 24 * 60 - 1))}';
}
