import 'package:flutter/material.dart';

import '../models.dart';
import 'controller.dart';
import 'mini_month.dart';
import 'month_view.dart';
import 'time_grid.dart';

/// カレンダー本体（ヘッダー + 日/週/月ビュー）
///
/// [compact] が true のときは狭い画面向けに、ヘッダーを2段にしてタイトルを
/// タップするとミニカレンダーを開閉できるようにする。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller, this.compact = false});

  final CalendarController controller;
  final bool compact;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _showMini = false;

  Widget _viewSwitch(CalendarController c) {
    return SegmentedButton<CalView>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final v in CalView.values)
          ButtonSegment(value: v, label: Text(v.label)),
      ],
      selected: {c.view},
      onSelectionChanged: (s) => c.setView(s.first),
    );
  }

  Widget _header(BuildContext context, CalendarController c) {
    final titleStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.bold);

    final Widget title = widget.compact
        ? InkWell(
            onTap: () => setState(() => _showMini = !_showMini),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(c.title,
                        style: titleStyle, overflow: TextOverflow.ellipsis),
                  ),
                  Icon(_showMini ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          )
        : Text(c.title, style: titleStyle);

    final row = Row(
      children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: title)),
        TextButton(onPressed: c.goToday, child: const Text('今日')),
        IconButton(
          tooltip: '前へ',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => c.step(-1),
        ),
        IconButton(
          tooltip: '次へ',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => c.step(1),
        ),
        if (!widget.compact) ...[
          const SizedBox(width: 8),
          _viewSwitch(c),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: widget.compact
          ? Column(
              children: [
                row,
                SizedBox(width: double.infinity, child: _viewSwitch(c)),
                const SizedBox(height: 4),
              ],
            )
          : row,
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
                duration: const Duration(milliseconds: 200),
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
