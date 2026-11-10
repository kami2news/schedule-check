import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';

const double _hourH = 56;
const double _gutter = 48;

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
      ScrollController(initialScrollOffset: 7 * _hourH);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color _weekendColor(BuildContext context, DateTime d) {
    if (d.weekday == DateTime.sunday) return Colors.red;
    if (d.weekday == DateTime.saturday) return Colors.blue;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _dayHeader(BuildContext context, DateTime d, bool isToday) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.controller;
    return InkWell(
      onTap: () {
        c.select(d);
        if (c.view != CalView.day) c.setView(CalView.day);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(weekdayNames[d.weekday - 1],
                style: TextStyle(fontSize: 12, color: _weekendColor(context, d))),
            const SizedBox(height: 2),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? scheme.primary : null,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isToday ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDayEventChip(BuildContext context, Event e) {
    return GestureDetector(
      onTap: () => openEventEditor(context, event: e),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: e.kind.color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          e.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ),
    );
  }

  Widget _allDayTaskChip(BuildContext context, TaskItem t) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => openTaskEditor(context, task: t),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => StoreScope.read(context).toggleTask(t.id),
              child: Icon(
                t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14,
                color: t.done ? scheme.primary : scheme.outline,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  decoration: t.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(BuildContext context, Event e, double h) {
    final scheme = Theme.of(context).colorScheme;
    final lines = math.max(1, ((h - 4) / 14).floor());
    return GestureDetector(
      onTap: () => openEventEditor(context, event: e),
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 2, 2, 2),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              e.kind.color.withValues(alpha: 0.22), scheme.surface),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: e.kind.color, width: 4)),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: e.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (lines > 1)
              TextSpan(
                  text: '\n${e.timeLabel}'
                      '${e.place.isEmpty ? '' : '  ${e.place}'}'),
          ]),
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurface, height: 1.2),
        ),
      ),
    );
  }

  Widget _dayColumn(BuildContext context, DateTime day, double colW,
      List<Event> timed, bool isToday) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    return Stack(
      children: [
        if (isToday)
          Positioned.fill(
            child: ColoredBox(color: scheme.primary.withValues(alpha: 0.05)),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final raw = (d.localPosition.dy / _hourH * 60 / 30).floor() * 30;
              final m = math.max(0, math.min(raw, 23 * 60 + 30));
              openEventEditor(context, date: day, startMin: m);
            },
            child: const SizedBox.expand(),
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
              math.max(
                  (_endOf(p.event) - p.event.startMin!) / 60 * _hourH - 2, 20.0),
            ),
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
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                  Expanded(child: Container(height: 2, color: Colors.red)),
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
    final scheme = Theme.of(context).colorScheme;

    final events = [for (final d in days) c.eventsOn(store, d)];
    final tasks = [for (final d in days) c.tasksOn(store, d)];
    var maxAll = 0;
    for (var i = 0; i < days.length; i++) {
      final n = events[i].where((e) => e.allDay).length + tasks[i].length;
      if (n > maxAll) maxAll = n;
    }

    final lineColor = scheme.outlineVariant.withValues(alpha: 0.7);

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: _gutter),
            for (final d in days)
              Expanded(child: _dayHeader(context, d, d == today)),
          ],
        ),
        if (maxAll > 0)
          Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: lineColor)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _gutter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, right: 6),
                    child: Text('終日',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                  ),
                ),
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Column(
                      children: [
                        for (final e in events[i].where((e) => e.allDay))
                          _allDayEventChip(context, e),
                        for (final t in tasks[i]) _allDayTaskChip(context, t),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Divider(height: 1, color: lineColor),
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
                              style: TextStyle(
                                  fontSize: 10, color: scheme.onSurfaceVariant),
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
                                child: Container(height: 1, color: lineColor),
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
                                        left: BorderSide(color: lineColor)),
                                  ),
                                  child: _dayColumn(
                                    context,
                                    days[i],
                                    colW,
                                    events[i]
                                        .where((e) => !e.allDay)
                                        .toList(),
                                    days[i] == today,
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
  }
}
