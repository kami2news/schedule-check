import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import 'controller.dart';
import 'fluent.dart';
import 'mini_month.dart';
import 'month_view.dart';
import 'time_grid.dart';

/// カレンダー本体（ヘッダー + 日/週/月ビュー）
///
/// [compact] が true のときは狭い画面向けに、タイトルをタップすると
/// ミニカレンダーを開閉できるようにする。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller, this.compact = false});

  final CalendarController controller;
  final bool compact;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _showMini = false;

  /// Outlook と同じ「週 ▾」形式の表示切り替えメニュー
  Widget _viewMenu(CalendarController c) {
    return PopupMenuButton<CalView>(
      tooltip: '表示形式',
      position: PopupMenuPosition.under,
      initialValue: c.view,
      onSelected: c.setView,
      itemBuilder: (context) => [
        for (final v in CalView.values)
          PopupMenuItem<CalView>(
            value: v,
            height: 36,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: v == c.view
                      ? const Icon(FluentIcons.checkmark_24_regular, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(v.label),
              ],
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Fl.bg1,
          border: Border.all(color: Fl.stroke1),
          borderRadius: BorderRadius.circular(Fl.r4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.view.label, style: FlText.body1Strong),
            const SizedBox(width: 6),
            const Icon(FluentIcons.chevron_down_24_regular, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, CalendarController c) {
    final compact = widget.compact;
    final todayButton = compact
        ? OutlinedButton(onPressed: c.goToday, child: const Text('今日'))
        : OutlinedButton.icon(
            onPressed: c.goToday,
            icon: const Icon(FluentIcons.calendar_ltr_24_regular, size: 16),
            label: const Text('今日'),
          );

    final arrows = [
      IconButton(
        tooltip: '前へ',
        icon: const Icon(FluentIcons.chevron_left_24_regular),
        onPressed: () => c.step(-1),
      ),
      IconButton(
        tooltip: '次へ',
        icon: const Icon(FluentIcons.chevron_right_24_regular),
        onPressed: () => c.step(1),
      ),
    ];

    final titleStyle = compact ? FlText.subtitle2 : FlText.subtitle1;
    final Widget title = compact
        ? InkWell(
            borderRadius: BorderRadius.circular(Fl.r4),
            onTap: () => setState(() => _showMini = !_showMini),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(c.title,
                        style: titleStyle, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showMini
                        ? FluentIcons.chevron_up_24_regular
                        : FluentIcons.chevron_down_24_regular,
                    size: 16,
                  ),
                ],
              ),
            ),
          )
        : Text(c.title, style: titleStyle);

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
          : const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          if (!compact) ...[
            todayButton,
            const SizedBox(width: 4),
            ...arrows,
            const SizedBox(width: 8),
          ],
          Expanded(child: Align(alignment: Alignment.centerLeft, child: title)),
          if (compact) ...[
            todayButton,
            const SizedBox(width: 2),
            ...arrows,
          ],
          const SizedBox(width: 8),
          _viewMenu(c),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final Widget body;
        switch (c.view) {
          case CalView.day:
            body = TimeGrid(
              key: const ValueKey('grid-day'),
              controller: c,
              days: [c.selected],
            );
            break;
          case CalView.week:
            final start = startOfWeek(c.selected);
            body = TimeGrid(
              key: const ValueKey('grid-week'),
              controller: c,
              days: [for (var i = 0; i < 7; i++) addDays(start, i)],
            );
            break;
          case CalView.month:
            body = MonthView(key: const ValueKey('month'), controller: c);
            break;
        }
        return Column(
          children: [
            _header(context, c),
            if (widget.compact)
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.topCenter,
                child: _showMini
                    ? MiniMonth(controller: c)
                    : const SizedBox(width: double.infinity),
              ),
            const Divider(height: 1),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
