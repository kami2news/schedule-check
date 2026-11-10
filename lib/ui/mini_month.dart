import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';

/// 左側（狭い画面ではヘッダー下）に出す小さな月カレンダー
class MiniMonth extends StatelessWidget {
  const MiniMonth({super.key, required this.controller});

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
    final weekStart = startOfWeek(sel);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text('${sel.year}年${sel.month}月',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => controller.shiftMonth(-1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => controller.shiftMonth(1),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    weekdayNames[addDays(gridStart, i).weekday - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _day(
                      context,
                      store,
                      addDays(gridStart, r * 7 + c),
                      sel,
                      today,
                      weekStart,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, AppStore store, DateTime day, DateTime sel,
      DateTime today, DateTime weekStart) {
    final scheme = Theme.of(context).colorScheme;
    final inMonth = day.month == sel.month;
    final isSel = day == sel;
    final isToday = day == today;
    final inSelWeek = controller.view == CalView.week &&
        !day.isBefore(weekStart) &&
        day.isBefore(addDays(weekStart, 7));
    final hasItems = controller.eventsOn(store, day).isNotEmpty ||
        controller.tasksOn(store, day).isNotEmpty;

    return InkWell(
      onTap: () => controller.select(day),
      child: Container(
        height: 34,
        color: inSelWeek ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? scheme.primary : null,
                shape: BoxShape.circle,
                border: (isToday && !isSel)
                    ? Border.all(color: scheme.primary)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  color: isSel
                      ? scheme.onPrimary
                      : (inMonth
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                ),
              ),
            ),
            SizedBox(
              height: 4,
              child: hasItems
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.7),
                          shape: BoxShape.circle),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
