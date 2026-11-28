import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../compare.dart';
import '../models.dart';
import '../store.dart';
import 'edit_pages.dart' show showFlDialogOrPage;
import 'fluent.dart';
import 'fluent_extras.dart';

/// カレンダーの上に出す帯: 「佐藤さんの予定」を仮に置いて比べています（重なり 2 件）［一覧］［終える］
class CompareBanner extends StatelessWidget {
  const CompareBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.compareEvents.isEmpty) return SizedBox.shrink();
    final rows = compareWith(store.compareEvents, store.eventsOn);
    final n = rows.where((r) => r.conflicts).length;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Fl.tint(Color(kCompareColor)),
        border: Border(bottom: BorderSide(color: Fl.stroke2)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            FlIcon(FluentIcons.person_24_regular, size: 16, color: Color(kCompareColor)),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                '「${store.compareCalendar.name}」を仮に置いて比べています'
                '（${rows.length}件・${n == 0 ? '重なりなし' : '重なり$n件'}）',
                style: FlText.body1,
              ),
            ),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
              onPressed: () => showCompareList(context),
              child: Text('一覧'),
            ),
            TextButton(
              onPressed: store.clearCompare,
              child: Text('比べるのを終える'),
            ),
          ]),
        ],
      ),
    );
  }
}

/// 比べた結果の一覧（仮に置いた予定ごとに、重なる自分の予定）
Future<void> showCompareList(BuildContext context) {
  return showFlDialogOrPage(context,
      title: '比べた結果', builder: (_) => _CompareList());
}

class _CompareList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rows = compareWith(store.compareEvents, store.eventsOn);
    final n = rows.where((r) => r.conflicts).length;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(store.compareCalendar.name, style: FlText.subtitle2),
        SizedBox(height: 2),
        Text(
            '${rows.length}件のうち、自分の予定と時間が重なるのは$n件です。'
            '仮に置いた予定は保存されません（アプリを閉じるか「比べるのを終える」で消えます）。',
            style: FlText.caption1.copyWith(color: Fl.fg2)),
        SizedBox(height: 12),
        if (rows.isEmpty) Text('比べる予定はありません', style: FlText.body1),
        for (var i = 0; i < rows.length; i++) ...[
          if (i == 0 || rows[i].day != rows[i - 1].day)
            Padding(
              padding: EdgeInsets.only(top: 10, bottom: 4),
              child: Text(fmtLongDate(rows[i].day),
                  style: FlText.body1Strong
                      .copyWith(color: weekendFg(rows[i].day) ?? Fl.fg1)),
            ),
          _Row(row: rows[i]),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final CompareRow row;

  @override
  Widget build(BuildContext context) {
    final e = row.item;
    final ok = !row.conflicts;
    final reg = row.registered != null;
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Fl.bg1,
        borderRadius: BorderRadius.circular(Fl.r4),
        border: Border(left: BorderSide(color: Color(kCompareColor), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.title.isEmpty ? '(無題)' : e.title, style: FlText.body1Strong),
          Text('${e.timeLabel}${e.place.isEmpty ? '' : '・${e.place}'}',
              style: FlText.caption1.copyWith(color: Fl.fg2)),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FlIcon(
                  ok ? FluentIcons.checkmark_circle_16_filled : FluentIcons.warning_16_regular,
                  size: 16,
                  color: ok ? Fl.success : Fl.danger),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  ok
                      ? (reg ? '本予定に登録済み' : '自分の予定と重なりません')
                      : '重なる: ${row.mine.map((m) => '${m.title}（${m.timeLabel}）').join('、')}',
                  style: FlText.caption1.copyWith(color: ok ? Fl.success : Fl.danger),
                ),
              ),
            ],
          ),
          Align(alignment: Alignment.centerRight, child: PromoteButton(row: row)),
          if (row.mineAllDay.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 2, left: 22),
              child: Text(
                  '同じ日の終日の予定: ${row.mineAllDay.map((m) => m.title).join('、')}',
                  style: FlText.caption1.copyWith(color: Fl.fg3)),
            ),
        ],
      ),
    );
  }
}

/// 仮の予定を本予定に入れて、お知らせ（元に戻す・編集）を出す
void promoteInteractive(BuildContext context, Event item, {String note = ''}) {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final keepCompare = isCompareEvent(item) ? item : null;
  final e = store.promote(item, context: note);
  messenger.showSnackBar(SnackBar(
    content: Text('「${e.title}」を${store.calendarOf(e.calendarId).name}に登録しました'),
    action: SnackBarAction(
      label: '元に戻す',
      onPressed: () {
        store.deleteEvent(e.id);
        if (keepCompare != null) store.restoreCompare(keepCompare);
      },
    ),
  ));
}

/// 「本予定に入れる」小さなボタン（登録済みなら印だけ）
class PromoteButton extends StatelessWidget {
  const PromoteButton({super.key, required this.row, this.note = ''});
  final CompareRow row;

  /// 振り分けの手がかりにする文章（付箋のメモ全体など）
  final String note;

  @override
  Widget build(BuildContext context) {
    if (row.registered != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          FlIcon(FluentIcons.checkmark_12_filled, size: 12, color: Fl.brand),
          SizedBox(width: 2),
          Text('登録済み', style: FlText.caption1.copyWith(color: Fl.brand)),
        ]),
      );
    }
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => promoteInteractive(context, row.item, note: note),
      child: Text('本予定に入れる'),
    );
  }
}
