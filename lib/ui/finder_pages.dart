import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../finder.dart';
import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'event_peek.dart';
import 'fluent.dart';
import 'fluent_extras.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// 検索
// ---------------------------------------------------------------------------

/// 予定とタスクを検索する。予定を選ぶとその日に移動してプレビューを開く
Future<void> openSearch(BuildContext context, CalendarController controller) {
  return showFlDialogOrPage(
    context,
    title: '検索',
    builder: (_) => _SearchPage(controller: controller),
  );
}

class _SearchPage extends StatefulWidget {
  const _SearchPage({required this.controller});

  final CalendarController controller;

  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final hits = searchAll(_q.text, store.events, store.tasks, DateTime.now());
    final today = dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: FlTextField(
            controller: _q,
            autofocus: true,
            hint: '予定・タスク・場所・メモを検索',
            leading: Icon(FluentIcons.search_24_regular, size: 16, color: Fl.fg3),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _q.text.trim().isEmpty
              ? Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('スペースで区切ると、すべての言葉を含むものを探します',
                      style: FlText.body1.copyWith(color: Fl.fg3)),
                )
              : hits.isEmpty
                  ? Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('見つかりませんでした',
                          style: FlText.body1.copyWith(color: Fl.fg3)),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: hits.length,
                      itemBuilder: (context, i) {
                        final h = hits[i];
                        final prev = i == 0 ? null : hits[i - 1];
                        String section(SearchHit x) => x.task != null
                            ? 'タスク'
                            : (x.date != null && !x.date!.isBefore(today)
                                ? 'これからの予定'
                                : '過去の予定');
                        final header = prev == null || section(prev) != section(h)
                            ? Padding(
                                padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
                                child: Text(section(h), style: FlText.body1Strong),
                              )
                            : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (header != null) header,
                            h.event != null ? _eventTile(context, h) : _taskTile(context, h.task!),
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _eventTile(BuildContext context, SearchHit h) {
    final e = h.event!;
    final store = StoreScope.of(context);
    final when = e.repeat != null
        ? '${e.repeat!.label(e.date)}・次回 ${h.date == null ? '-' : fmtDate(h.date!)}'
        : fmtDate(e.date);
    return InkWell(
      borderRadius: BorderRadius.circular(Fl.r4),
      onTap: () {
        final nav = Navigator.of(context);
        final d = h.date ?? e.firstDate;
        widget.controller.select(d);
        nav.pop();
        openEventPeek(nav.context, e, d);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(width: 4, height: 36, color: store.colorOf(e)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: FlText.body1Strong, overflow: TextOverflow.ellipsis),
                  Text(
                    [when, e.timeLabel, if (e.place.isNotEmpty) e.place].join('  '),
                    style: FlText.caption1.copyWith(color: Fl.fg2),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskTile(BuildContext context, TaskItem t) {
    return InkWell(
      borderRadius: BorderRadius.circular(Fl.r4),
      onTap: () => openTaskEditor(context, task: t),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            FlCheckCircle(
              checked: t.done,
              onTap: () => StoreScope.read(context).toggleTask(t.id),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: FlText.body1.copyWith(
                          decoration: t.done ? TextDecoration.lineThrough : null)),
                  if (t.due != null)
                    Text(dueInfo(context, t).text,
                        style: FlText.caption1.copyWith(color: Fl.fg2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 空き時間の候補日
// ---------------------------------------------------------------------------

/// 空き時間を探して、候補日を文章でコピーする（面談の日程調整など）
Future<void> openFreeTime(BuildContext context) {
  return showFlDialogOrPage(
    context,
    title: '空き時間を探す',
    builder: (_) => _FreeTimePage(),
  );
}

class _FreeTimePage extends StatefulWidget {
  @override
  State<_FreeTimePage> createState() => _FreeTimePageState();
}

class _FreeTimePageState extends State<_FreeTimePage> {
  int _days = 14;
  int _dayStart = 9 * 60;
  int _dayEnd = 19 * 60;
  int _min = 60;
  bool _weekends = false;
  int _buffer = 0;
  bool _allDayBusy = true;

  /// 空き時間の計算に入れないカレンダー（例: 自分用のメモのカレンダー）
  final Set<String> _ignored = {};
  final Set<String> _picked = {};

  Widget _option<T>(String label, T value, List<(T, String)> items, ValueChanged<T> onChanged) {
    return SizedBox(
      width: 200,
      child: FlField(
        label: label,
        child: FlDropdown<T>(
          items: [for (final (v, _) in items) v],
          value: value,
          labelOf: (v) => items.firstWhere((x) => x.$1 == v).$2,
          onChanged: (v) => setState(() {
            onChanged(v);
            _picked.clear();
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final slots = findFreeSlots(
      store.events,
      now,
      FreeTimeOptions(
        days: _days,
        dayStart: _dayStart,
        dayEnd: _dayEnd,
        minMinutes: _min,
        weekends: _weekends,
        buffer: _buffer,
        allDayBusy: _allDayBusy,
      ),
      now: now,
      ignoreCalendars: _ignored,
    );
    final chosen = slots.where((s) => _picked.contains(s.label)).toList();
    final copyTarget = chosen.isEmpty ? slots : chosen;

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Text('予定（「空き時間」にしたものを除く）が入っていない時間を探します。候補を選んでコピーすると、メールなどに貼り付けられます。',
            style: FlText.body1.copyWith(color: Fl.fg2)),
        SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: [
            _option<int>('期間', _days, [(7, '今日から1週間'), (14, '今日から2週間'), (28, '今日から4週間')],
                (v) => _days = v),
            _option<int>('最短の長さ', _min, [(30, '30分以上'), (60, '1時間以上'), (90, '1時間30分以上'), (120, '2時間以上'), (180, '3時間以上')],
                (v) => _min = v),
            _option<int>('前後の余裕（移動など）', _buffer, [(0, 'なし'), (15, '15分'), (30, '30分'), (60, '1時間')],
                (v) => _buffer = v),
            SizedBox(
              width: 200,
              child: FlField(
                label: '時間帯',
                child: Row(children: [
                  Expanded(
                    child: FlPickerField(
                      icon: FluentIcons.clock_24_regular,
                      text: fmtMin(_dayStart),
                      onTap: () async {
                        final v = await showFlTimeList(context, _dayStart);
                        if (v != null && v < _dayEnd) setState(() => _dayStart = v);
                      },
                    ),
                  ),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('〜')),
                  Expanded(
                    child: FlPickerField(
                      icon: FluentIcons.clock_24_regular,
                      text: fmtMin(_dayEnd),
                      onTap: () async {
                        final v = await showFlTimeList(context, _dayEnd);
                        if (v != null && v > _dayStart) setState(() => _dayEnd = v);
                      },
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
        FlCheckRow(
          label: '土日も候補にする',
          value: _weekends,
          onChanged: (v) => setState(() {
            _weekends = v;
            _picked.clear();
          }),
        ),
        FlCheckRow(
          label: '終日の予定がある日は候補にしない',
          value: _allDayBusy,
          onChanged: (v) => setState(() {
            _allDayBusy = v;
            _picked.clear();
          }),
        ),
        SizedBox(height: 8),
        Text('予定として数えるカレンダー', style: FlText.body1Strong),
        SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: [
            for (final c in store.calendars)
              InkWell(
                borderRadius: BorderRadius.circular(Fl.r4),
                onTap: () => setState(() {
                  if (!_ignored.remove(c.id)) _ignored.add(c.id);
                  _picked.clear();
                }),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    FlColorDot(
                        color: c.color,
                        filled: !_ignored.contains(c.id),
                        size: 14),
                    SizedBox(width: 6),
                    Text(c.name,
                        style: FlText.body1.copyWith(
                            color: _ignored.contains(c.id) ? Fl.fg3 : Fl.fg1)),
                  ]),
                ),
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(0, 12, 0, 4),
          child: Row(children: [
            Expanded(
              child: Text(
                slots.isEmpty ? '空き時間が見つかりませんでした' : '空き時間 ${slots.length}件（タップで選択）',
                style: FlText.body1Strong,
              ),
            ),
            FilledButton.icon(
              onPressed: slots.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: formatSlots(copyTarget)));
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                          content: Text('${copyTarget.length}件の候補をコピーしました')));
                    },
              icon: Icon(FluentIcons.copy_24_regular, size: 18),
              label: Text(chosen.isEmpty ? 'すべてコピー' : '選んだ${chosen.length}件をコピー'),
            ),
          ]),
        ),
        for (final s in slots)
          InkWell(
            borderRadius: BorderRadius.circular(Fl.r4),
            onTap: () => setState(() {
              if (!_picked.remove(s.label)) _picked.add(s.label);
            }),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                FlCheckCircle(
                  checked: _picked.contains(s.label),
                  onTap: () => setState(() {
                    if (!_picked.remove(s.label)) _picked.add(s.label);
                  }),
                ),
                Expanded(child: Text(s.label, style: FlText.body1)),
                Text(
                  s.minutes >= 60
                      ? '${s.minutes ~/ 60}時間${s.minutes % 60 == 0 ? '' : '${s.minutes % 60}分'}'
                      : '${s.minutes}分',
                  style: FlText.caption1.copyWith(color: Fl.fg3),
                ),
              ]),
            ),
          ),
        if (copyTarget.isNotEmpty) ...[
          SizedBox(height: 12),
          Text('コピーされる文章', style: FlText.caption1Strong.copyWith(color: Fl.fg2)),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Fl.bg2,
              borderRadius: BorderRadius.circular(Fl.r4),
              border: Border.all(color: Fl.stroke2),
            ),
            child: SelectableText(formatSlots(copyTarget), style: FlText.body1),
          ),
        ],
      ],
    );
  }
}
