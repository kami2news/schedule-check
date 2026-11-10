import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'fluent.dart';

/// 左側（狭い画面ではヘッダー下）に出す小さな月カレンダー
class MiniMonth extends StatelessWidget {
  const MiniMonth({super.key, required this.controller});

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
    final weekStart = startOfWeek(sel);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(width: 8),
              Expanded(
                child: Text('${sel.year}年${sel.month}月',
                    style: FlText.body1Strong),
              ),
              IconButton(
                tooltip: '前の月',
                icon: Icon(FluentIcons.chevron_left_24_regular),
                onPressed: () => controller.shiftMonth(-1),
              ),
              IconButton(
                tooltip: '次の月',
                icon: Icon(FluentIcons.chevron_right_24_regular),
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
                    style: FlText.caption1.copyWith(color: Fl.fg3),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),
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
          SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, AppStore store, DateTime day, DateTime sel,
      DateTime today, DateTime weekStart) {
    final inMonth = day.month == sel.month;
    final isSel = day == sel;
    final isToday = day == today;
    final inSelWeek = controller.view == CalView.week &&
        !day.isBefore(weekStart) &&
        day.isBefore(addDays(weekStart, 7));
    final hasItems = controller.eventsOn(store, day).isNotEmpty ||
        controller.tasksOn(store, day).isNotEmpty;

    // 今日 = ブランド色の塗り、選択日 = 淡いブランド背景 + ブランド文字
    final Color? fill = isToday ? Fl.brand : (isSel ? Fl.brandTint : null);
    final Color textColor = isToday
        ? Colors.white
        : (isSel ? Fl.brandFg : (inMonth ? Fl.fg1 : Fl.fg3));

    return InkWell(
      onTap: () => controller.select(day),
      child: Container(
        height: 34,
        color: inSelWeek ? Fl.brandTint : null,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: (isSel && !isToday)
                    ? Border.all(color: Fl.brandFg)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: (isToday || isSel
                        ? FlText.caption1Strong
                        : FlText.caption1)
                    .copyWith(color: textColor),
              ),
            ),
            SizedBox(
              height: 4,
              child: hasItems
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Fl.brandFg, shape: BoxShape.circle),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
