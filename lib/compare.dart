import 'models.dart';
import 'sharing.dart';

/// 「比べる」: ほかの人の予定（共有リンク・貼り付けた文章）を、保存せずにカレンダーへ仮に置き、
/// 自分の予定と重なるかを見る。

/// 仮に置く予定の id の頭とカレンダーの id
const kComparePrefix = 'cmp~';
const kCompareCalendarId = 'compare~';

/// 仮に置く予定の色（紫。自分のカレンダーの色と区別しやすい）
const kCompareColor = 0xFF8764B8;

bool isCompareEvent(Event e) => e.id.startsWith(kComparePrefix);

/// 共有リンクの予定（ShareItem）を、仮に置く予定にする
List<Event> shareItemsToEvents(List<ShareItem> items) => [
      for (var i = 0; i < items.length; i++)
        Event(
          id: '$kComparePrefix$i',
          title: items[i].title,
          calendarId: kCompareCalendarId,
          date: items[i].date,
          startMin: items[i].start,
          endMin: items[i].end,
          endOffset: items[i].endOffset,
          place: items[i].place,
          showAs: ShowAs.tentative,
        ),
    ];

/// 比べた結果の 1 行: 仮に置いた予定と、その時間に重なる自分の予定
class CompareRow {
  CompareRow(this.item, this.day, this.mine, this.mineAllDay);

  final Event item;
  final DateTime day;

  /// 時間が重なる自分の予定
  final List<Event> mine;

  /// 同じ日の自分の終日の予定（重なりではないが参考に出す）
  final List<Event> mineAllDay;

  bool get conflicts => mine.isNotEmpty;
}

/// 仮に置いた予定 [items] を、自分の予定（[eventsOn] が返す、その日にかかる予定）と比べる。
/// 「空き時間」の自分の予定は重なりに数えない
List<CompareRow> compareWith(
    List<Event> items, List<Event> Function(DateTime day) eventsOn) {
  final rows = <CompareRow>[];
  for (final it in items) {
    final day = dateOnly(it.date);
    // 仮の予定がかかる日ごと（日をまたぐ予定は翌日も）に見る
    final mine = <Event>[];
    final allDay = <Event>[];
    for (var k = 0; k <= it.endOffset; k++) {
      final d = addDays(day, k);
      final a = it.sliceOn(d);
      if (a == null) continue;
      for (final e in eventsOn(d)) {
        if (isCompareEvent(e) || e.showAs == ShowAs.free) continue;
        final b = e.sliceOn(d);
        if (b == null) continue;
        if (b.allDay) {
          if (k == 0 && !allDay.contains(e)) allDay.add(e);
          continue;
        }
        if (a.allDay) continue;
        if (a.start < b.end && b.start < a.end && !mine.contains(e)) mine.add(e);
      }
    }
    rows.add(CompareRow(it, day, mine, allDay));
  }
  rows.sort((x, y) {
    final c = x.day.compareTo(y.day);
    return c != 0 ? c : (x.item.startMin ?? -1).compareTo(y.item.startMin ?? -1);
  });
  return rows;
}
