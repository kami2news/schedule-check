import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'fluent_extras.dart';

/// Outlook 風の月表示
class MonthView extends StatelessWidget {
  const MonthView({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sel = controller.selected;
    final first = DateTime(sel.year, sel.month, 1);
    final gridStart = startOfWeek(first);
    final last = DateTime(sel.year, sel.month + 1, 0);
    final rows = last.difference(gridStart).inDays ~/ 7 + 1;
    final today = dateOnly(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    weekdayNames[addDays(gridStart, i).weekday - 1],
                    textAlign: TextAlign.center,
                    style: FlText.caption1.copyWith(color: Fl.fg3),
                  ),
                ),
              ),
          ],
        ),
        Divider(height: 1),
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
      DateTime sel, DateTime today) {
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
          color: isSel ? Fl.brandTint.withValues(alpha: 0.6) : null,
          border: Border(
            right: BorderSide(color: Fl.stroke2),
            bottom: BorderSide(color: Fl.stroke2),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, cs) {
            final maxChips =
                math.max(0, math.min(6, ((cs.maxHeight - 28) / 18).floor()));
            final shown = total <= maxChips
                ? total
                : (maxChips > 0 ? maxChips - 1 : 0);
            final hidden = total - shown;

            final chips = <Widget>[];
            var n = 0;
            for (final e in events) {
              if (n++ >= shown) break;
              chips.add(_eventChip(e, store.colorOf(e), !inMonth));
            }
            for (final t in tasks) {
              if (n++ >= shown) break;
              chips.add(_taskChip(t, !inMonth));
            }

            // 月の1日だけ「11月1日」のように月も表示する（Outlook と同じ）
            final label = day.day == 1 ? '${day.month}月1日' : '${day.day}';

            return Padding(
              padding: EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: EdgeInsets.symmetric(
                        horizontal: label.length > 2 ? 6 : 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? Fl.brand : null,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      label,
                      style: FlText.caption1Strong.copyWith(
                        color: isToday
                            ? Colors.white
                            : (inMonth ? Fl.fg1 : Fl.fg3),
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  ...chips,
                  if (hidden > 0)
                    Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text('+$hidden',
                          style: FlText.caption2.copyWith(color: Fl.fg3)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _eventChip(Event e, Color color, bool faded) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: SizedBox(
          height: 16,
          width: double.infinity,
          child: FlAccentBox(
            accent: color,
            showAs: e.showAs,
            bar: 3,
            padding: EdgeInsets.fromLTRB(3, 0, 2, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FlText.caption2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskChip(TaskItem t, bool faded) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: SizedBox(
          height: 16,
          width: double.infinity,
          child: Row(
            children: [
              Icon(
                t.done
                    ? FluentIcons.checkmark_circle_16_filled
                    : FluentIcons.circle_16_regular,
                size: 12,
                color: t.done ? Fl.brandFg : Fl.fg3,
              ),
              SizedBox(width: 3),
              Expanded(
                child: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlText.caption2.copyWith(
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
}
