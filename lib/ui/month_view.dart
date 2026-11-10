import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';

/// Outlook 風の月表示
class MonthView extends StatelessWidget {
  const MonthView({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final sel = controller.selected;
    final first = DateTime(sel.year, sel.month, 1);
    final gridStart = startOfWeek(first);
    final last = DateTime(sel.year, sel.month + 1, 0);
    final rows = last.difference(gridStart).inDays ~/ 7 + 1;
    final today = dateOnly(DateTime.now());
    final lineColor = scheme.outlineVariant.withValues(alpha: 0.7);

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    weekdayNames[addDays(gridStart, i).weekday - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
        Divider(height: 1, color: lineColor),
        Expanded(
          child: Column(
            children: [
              for (var r = 0; r < rows; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < 7; c++)
                        Expanded(
                          child: _cell(
                            context,
                            store,
                            addDays(gridStart, r * 7 + c),
                            sel,
                            today,
                            lineColor,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, AppStore store, DateTime day,
      DateTime sel, DateTime today, Color lineColor) {
    final scheme = Theme.of(context).colorScheme;
    final inMonth = day.month == sel.month;
    final isToday = day == today;
    final isSel = day == sel;
    final events = controller.eventsOn(store, day);
    final tasks = controller.tasksOn(store, day);
    final total = events.length + tasks.length;

    return InkWell(
      onTap: () {
        controller.select(day);
        controller.setView(CalView.day);
      },
      onLongPress: () => openEventEditor(context, date: day),
      child: Container(
        decoration: BoxDecoration(
          color: isSel ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
          border: Border(
            right: BorderSide(color: lineColor),
            bottom: BorderSide(color: lineColor),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, cs) {
            final maxChips =
                math.max(0, math.min(6, ((cs.maxHeight - 28) / 16).floor()));
            final shown = total <= maxChips
                ? total
                : (maxChips > 0 ? maxChips - 1 : 0);
            final hidden = total - shown;

            final chips = <Widget>[];
            var n = 0;
            for (final e in events) {
              if (n++ >= shown) break;
              chips.add(_chip(
                color: e.kind.color.withValues(alpha: 0.22),
                bar: e.kind.color,
                text: e.title,
                faded: !inMonth,
              ));
            }
            for (final t in tasks) {
              if (n++ >= shown) break;
              chips.add(_taskChip(context, t, !inMonth));
            }

            return Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? scheme.primary : null,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : null,
                        color: isToday
                            ? scheme.onPrimary
                            : (inMonth
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  ...chips,
                  if (hidden > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text('+$hidden',
                          style: TextStyle(
                              fontSize: 10, color: scheme.onSurfaceVariant)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chip({
    required Color color,
    required Color bar,
    required String text,
    required bool faded,
  }) {
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Container(
        height: 14,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border(left: BorderSide(color: bar, width: 3)),
        ),
        alignment: Alignment.centerLeft,
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, height: 1.1)),
      ),
    );
  }

  Widget _taskChip(BuildContext context, TaskItem t, bool faded) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Container(
        height: 14,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(t.done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 11, color: t.done ? scheme.primary : scheme.outline),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  decoration: t.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
