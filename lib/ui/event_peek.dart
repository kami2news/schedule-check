import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'fluent_extras.dart';
import 'widgets.dart';

/// 予定のプレビュー（Outlook でクリックしたときに出るカード）。
/// [day] は繰り返しの予定のどの回か。
Future<void> openEventPeek(BuildContext context, Event e, DateTime day) {
  return showFlDialog<void>(
    context,
    maxWidth: 440,
    child: _EventPeek(eventId: e.id, day: dateOnly(day)),
  );
}

/// 住所・場所名を地図アプリ（Google マップ）で開く
Future<void> openMap(BuildContext context, String place) {
  final q = Uri.encodeComponent(place);
  return openLink(context, 'https://www.google.com/maps/search/?api=1&query=$q');
}

class _EventPeek extends StatelessWidget {
  const _EventPeek({required this.eventId, required this.day});

  final String eventId;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = store.events.where((x) => x.id == eventId).firstOrNull;
    if (e == null) {
      // 削除された・別の回に切り出されたなど
      return Material(
        color: Fl.bg1,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('この予定は見つかりません', style: FlText.body1),
        ),
      );
    }
    final color = store.colorOf(e);
    final cal = store.calendarOf(e.calendarId);
    final tasks = store.tasksFor(e, day);
    final when = e.repeat != null
        ? '${fmtLongDate(day)}  ${e.timeLabel}'
        : '${fmtLongDate(e.date)}  ${e.timeLabel}';

    Widget row(IconData icon, Widget child) => Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: Fl.fg3),
              ),
              SizedBox(width: 10),
              Expanded(child: child),
            ],
          ),
        );

    return Material(
      color: Fl.bg1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 上端にカレンダーの色の帯（Outlook のプレビューと同じ）
          Container(height: 6, color: color),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(e.title, style: FlText.subtitle1),
                  ),
                ),
                IconButton(
                  tooltip: '編集',
                  icon: Icon(FluentIcons.edit_24_regular, size: 20),
                  onPressed: () {
                    // プレビューを閉じてから、同じ回の編集画面を開く
                    final nav = Navigator.of(context);
                    nav.pop();
                    openEventEditor(nav.context, event: e, occurrence: day);
                  },
                ),
                IconButton(
                  tooltip: '削除',
                  icon: Icon(FluentIcons.delete_24_regular,
                      size: 20, color: Fl.danger),
                  onPressed: () async {
                    final ok = await deleteEventInteractive(
                        context, e, e.weekly ? day : null);
                    if (ok && context.mounted) Navigator.of(context).pop();
                  },
                ),
                IconButton(
                  tooltip: '閉じる',
                  icon: Icon(FluentIcons.dismiss_24_regular, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(
                    FluentIcons.clock_24_regular,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(when, style: FlText.body1),
                        if (e.repeat != null)
                          Text(e.repeat!.label(e.date),
                              style: FlText.caption1.copyWith(color: Fl.fg3)),
                        if (e.isException)
                          Text('繰り返しのうち、この回だけ変更しています',
                              style: FlText.caption1.copyWith(color: Fl.fg3)),
                      ],
                    ),
                  ),
                  row(
                    FluentIcons.calendar_ltr_24_regular,
                    Row(children: [
                      FlColorDot(color: color),
                      SizedBox(width: 6),
                      Text(cal.name, style: FlText.body1),
                      if (e.showAs != ShowAs.busy) ...[
                        SizedBox(width: 10),
                        FlShowAsSwatch(showAs: e.showAs, color: color),
                        SizedBox(width: 4),
                        Text(e.showAs.label,
                            style: FlText.caption1.copyWith(color: Fl.fg2)),
                      ],
                    ]),
                  ),
                  if (e.place.isNotEmpty)
                    row(
                      FluentIcons.location_24_regular,
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(e.place, style: FlText.body1),
                          InkWell(
                            onTap: () => openMap(context, e.place),
                            child: Text('地図で開く',
                                style: FlText.body1.copyWith(color: Fl.brandFg)),
                          ),
                        ],
                      ),
                    ),
                  if (e.url.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10, left: 26),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FlLinkButton(url: e.url),
                      ),
                    ),
                  if (e.note.isNotEmpty)
                    row(
                      FluentIcons.note_24_regular,
                      SelectableText(e.note, style: FlText.body1),
                    ),
                  // 関連するタスク
                  Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text('関連するタスク', style: FlText.body1Strong),
                  ),
                  for (final t in tasks)
                    Row(children: [
                      FlCheckCircle(
                        checked: t.done,
                        onTap: () => StoreScope.read(context).toggleTask(t.id),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => openTaskEditor(context, task: t),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              t.due == null
                                  ? t.title
                                  : '${t.title}（${dueInfo(context, t).text}）',
                              style: FlText.body1.copyWith(
                                decoration:
                                    t.done ? TextDecoration.lineThrough : null,
                                color: t.done ? Fl.fg3 : Fl.fg1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => openTaskEditor(context,
                          forEvent: e, occurrence: e.weekly ? day : null),
                      icon: Icon(FluentIcons.add_24_regular, size: 16),
                      label: Text('タスクを追加（持ち物・準備など）'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
