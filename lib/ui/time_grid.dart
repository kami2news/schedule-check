import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'event_peek.dart';
import 'fluent.dart';
import 'fluent_extras.dart';
import 'widgets.dart';

const double _hourH = 56;
const double _gutter = 48;

/// 週表示で1日の列に最低限必要な幅（これより狭い画面では横スクロール）
const double _minDayWidth = 92;

class _Placed {
  _Placed(this.event, this.col);

  final Event event;
  final int col;
  int cols = 1;
}

int _endOf(Event e) {
  final s = e.startMin!;
  return math.max(e.endMin ?? s + 30, s + 30);
}

/// 重なる予定を横に並べるための列割り当て
List<_Placed> _layoutDay(List<Event> events) {
  final sorted = [...events]
    ..sort((a, b) => a.startMin!.compareTo(b.startMin!));
  final placed = <_Placed>[];
  var cluster = <_Placed>[];
  var colEnds = <int>[];
  var clusterEnd = -1;

  void flush() {
    for (final p in cluster) {
      p.cols = colEnds.length;
    }
    placed.addAll(cluster);
    cluster = <_Placed>[];
    colEnds = <int>[];
    clusterEnd = -1;
  }

  for (final e in sorted) {
    final s = e.startMin!;
    final end = _endOf(e);
    if (cluster.isNotEmpty && s >= clusterEnd) flush();
    var col = colEnds.indexWhere((x) => x <= s);
    if (col < 0) {
      colEnds.add(end);
      col = colEnds.length - 1;
    } else {
      colEnds[col] = end;
    }
    cluster.add(_Placed(e, col));
    if (end > clusterEnd) clusterEnd = end;
  }
  flush();
  return placed;
}

/// Outlook 風の時間グリッド（日・週表示）
class TimeGrid extends StatefulWidget {
  const TimeGrid({super.key, required this.controller, required this.days});

  final CalendarController controller;
  final List<DateTime> days;

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<TimeGrid> {
  final ScrollController _scroll =
      ScrollController(initialScrollOffset: 7 * _hourH - 12);
  final ScrollController _hScroll = ScrollController();
  bool _hJumped = false;

  @override
  void dispose() {
    _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  Widget _dayHeader(BuildContext context, DateTime d, bool isToday) {
    final c = widget.controller;
    return InkWell(
      onTap: () {
        c.select(d);
        if (c.view != CalView.day) c.setView(CalView.day);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayNames[d.weekday - 1],
              style: (isToday ? FlText.caption1Strong : FlText.caption1)
                  .copyWith(color: isToday ? Fl.brandFg : Fl.fg3),
            ),
            SizedBox(height: 2),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? Fl.brand : null,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${d.day}',
                style: FlText.subtitle2
                    .copyWith(color: isToday ? Colors.white : Fl.fg1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDayEventChip(BuildContext context, Event e, DateTime day) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: GestureDetector(
        onTap: () => openEventPeek(context, e, day),
        child: SizedBox(
          width: double.infinity,
          child: FlAccentBox(
            accent: StoreScope.read(context).colorOf(e),
            showAs: e.showAs,
            child: Text(e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FlText.caption1),
          ),
        ),
      ),
    );
  }

  Widget _allDayTaskChip(BuildContext context, TaskItem t) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: GestureDetector(
        onTap: () => openTaskEditor(context, task: t),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Fl.bg1,
            border: Border.all(color: Fl.stroke1),
            borderRadius: BorderRadius.circular(Fl.r4),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => StoreScope.read(context).toggleTask(t.id),
                child: Icon(
                  t.done
                      ? FluentIcons.checkmark_circle_16_filled
                      : FluentIcons.circle_16_regular,
                  size: 14,
                  color: t.done ? Fl.brandFg : Fl.fg3,
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  // 時刻つきの締め切りは時刻も添える（時間の欄にも印が出る）
                  t.hasTimeMark ? '${fmtMin(t.dueMin!)} ${t.title}' : t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlText.caption1.copyWith(
                    decoration: t.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(BuildContext context, Event e, DateTime day, double h, double w) {
    // 細い列では1文字ずつ折り返さないよう、タイトル1行だけを省略表示にする
    final narrow = w < 40;
    final lines = narrow ? 1 : math.max(1, ((h - 4) / 16).floor());
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: () => openEventPeek(context, e, day),
      child: FlAccentBox(
        accent: StoreScope.read(context).colorOf(e),
        showAs: e.showAs,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                if (e.url.isNotEmpty)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(linkIcon(e.url, small: true),
                          size: 12,
                          color: StoreScope.read(context).colorOf(e)),
                    ),
                  ),
                TextSpan(text: e.title),
              ]),
              maxLines: lines > 1 ? lines - 1 : 1,
              softWrap: !narrow,
              overflow: TextOverflow.ellipsis,
              style: FlText.caption1Strong,
            ),
            // 時刻・場所は折り返さず1行で省略する
            if (lines > 1)
              Text(
                '${e.timeLabel}${e.place.isEmpty ? '' : '  ${e.place}'}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: FlText.caption1.copyWith(color: Fl.fg2),
              ),
          ],
        ),
      ),
    ));
  }

  /// 時刻つきの締め切りの印。その時刻に1分の枠（線）を引き、短い札を付ける
  Widget _deadlineMark(BuildContext context, TaskItem t) {
    final color = t.done ? Fl.fg3 : Fl.warning;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => openTaskEditor(context, task: t),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1分ぶんの枠（見えるよう最低2px）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: math.max(_hourH / 60, 2),
              child: ColoredBox(color: color),
            ),
            Positioned(
              top: 2,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Fl.bg1,
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(Fl.r4),
                      bottomRight: Radius.circular(Fl.r4),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        t.done
                            ? FluentIcons.checkmark_circle_16_filled
                            : FluentIcons.flag_16_regular,
                        size: 11,
                        color: color),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${fmtMin(t.dueMin!)} ${t.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlText.caption2.copyWith(
                          color: t.done ? Fl.fg3 : Fl.fg1,
                          decoration: t.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayColumn(BuildContext context, DateTime day, double colW,
      List<Event> timed, bool isToday, List<TaskItem> marks) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    return Stack(
      children: [
        if (isToday)
          Positioned.fill(
            child: ColoredBox(color: Fl.brandTint.withValues(alpha: 0.5)),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final raw = (d.localPosition.dy / _hourH * 60 / 30).floor() * 30;
              final m = math.max(0, math.min(raw, 23 * 60 + 30));
              openEventEditor(context, date: day, startMin: m);
            },
            child: SizedBox.expand(),
          ),
        ),
        for (final p in _layoutDay(timed))
          Positioned(
            top: p.event.startMin! / 60 * _hourH,
            left: p.col * (colW / p.cols) + 1,
            width: colW / p.cols - 3,
            height: math.max(
                (_endOf(p.event) - p.event.startMin!) / 60 * _hourH - 2, 20.0),
            child: _block(
              context,
              p.event,
              day,
              math.max(
                  (_endOf(p.event) - p.event.startMin!) / 60 * _hourH - 2, 20.0),
              colW / p.cols - 3,
            ),
          ),
        // 締め切りの印は予定の上に重ねる
        for (final t in marks)
          Positioned(
            top: t.dueMin! / 60 * _hourH,
            left: 0,
            width: colW - 2,
            height: 18,
            child: _deadlineMark(context, t),
          ),
        if (isToday)
          Positioned(
            top: nowMin / 60 * _hourH - 4,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: Fl.dangerLine, shape: BoxShape.circle),
                  ),
                  Expanded(child: Container(height: 2, color: Fl.dangerLine)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = widget.controller;
    final days = widget.days;
    final today = dateOnly(DateTime.now());

    final events = [for (final d in days) c.eventsOn(store, d)];
    final tasks = [for (final d in days) c.tasksOn(store, d)];
    var maxAll = 0;
    for (var i = 0; i < days.length; i++) {
      final n = events[i].where((e) => e.allDay).length + tasks[i].length;
      if (n > maxAll) maxAll = n;
    }

    final content = Column(
      children: [
        Row(
          children: [
            SizedBox(width: _gutter),
            for (final d in days)
              Expanded(child: _dayHeader(context, d, d == today)),
          ],
        ),
        if (maxAll > 0)
          Container(
            padding: EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Fl.stroke2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _gutter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4, right: 6),
                    child: Text('終日',
                        textAlign: TextAlign.right,
                        style: FlText.caption2.copyWith(color: Fl.fg3)),
                  ),
                ),
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Column(
                      children: [
                        for (final e in events[i].where((e) => e.allDay))
                          _allDayEventChip(context, e, days[i]),
                        for (final t in tasks[i]) _allDayTaskChip(context, t),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * _hourH,
              child: Row(
                children: [
                  SizedBox(
                    width: _gutter,
                    child: Stack(
                      children: [
                        for (var h = 1; h < 24; h++)
                          Positioned(
                            top: h * _hourH - 8,
                            left: 0,
                            right: 6,
                            child: Text(
                              '$h:00',
                              textAlign: TextAlign.right,
                              style: FlText.caption2.copyWith(color: Fl.fg3),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, cs) {
                        final colW = cs.maxWidth / days.length;
                        return Stack(
                          children: [
                            for (var h = 1; h < 24; h++)
                              Positioned(
                                top: h * _hourH,
                                left: 0,
                                right: 0,
                                child: Container(height: 1, color: Fl.stroke2),
                              ),
                            // 30分の補助線（より淡く）
                            for (var h = 0; h < 24; h++)
                              Positioned(
                                top: h * _hourH + _hourH / 2,
                                left: 0,
                                right: 0,
                                child: Container(height: 1, color: Fl.stroke3),
                              ),
                            for (var i = 0; i < days.length; i++)
                              Positioned(
                                left: i * colW,
                                width: colW,
                                top: 0,
                                bottom: 0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                        left: BorderSide(color: Fl.stroke2)),
                                  ),
                                  child: _dayColumn(
                                    context,
                                    days[i],
                                    colW,
                                    events[i]
                                        .where((e) => !e.allDay)
                                        .toList(),
                                    days[i] == today,
                                    tasks[i].where((t) => t.hasTimeMark).toList(),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    // 狭い画面の週表示: 1日あたりの最小幅を確保して横スクロールにする
    return LayoutBuilder(builder: (context, cs) {
      final perDay = (cs.maxWidth - _gutter) / days.length;
      if (days.length == 1 || perDay >= _minDayWidth) return content;
      final width = _gutter + _minDayWidth * days.length;
      if (!_hJumped) {
        _hJumped = true;
        final i = days.indexOf(c.selected);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_hScroll.hasClients || i < 0) return;
          final target = (i * _minDayWidth - _minDayWidth / 2)
              .clamp(0.0, _hScroll.position.maxScrollExtent);
          _hScroll.jumpTo(target);
        });
      }
      return Scrollbar(
        controller: _hScroll,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, child: content),
        ),
      );
    });
  }
}
