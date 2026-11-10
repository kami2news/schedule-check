import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'edit_pages.dart';
import 'widgets.dart';

class WeekPage extends StatefulWidget {
  const WeekPage({super.key});

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  late DateTime _weekStart = _mondayOf(DateTime.now());

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  void _shift(int weeks) {
    setState(() {
      _weekStart = DateTime(
          _weekStart.year, _weekStart.month, _weekStart.day + 7 * weeks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = dateOnly(DateTime.now());
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i)
    ];
    final last = days.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            IconButton(
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                '${fmtDate(_weekStart)} – ${fmtDate(last)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right)),
            TextButton(
              onPressed: () =>
                  setState(() => _weekStart = _mondayOf(DateTime.now())),
              child: const Text('今週'),
            ),
          ],
        ),
        for (final day in days) _DaySection(day: day, today: today, store: store),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection(
      {required this.day, required this.today, required this.store});

  final DateTime day;
  final DateTime today;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = day == today;
    final events = store.eventsOn(day);
    final tasks = store.tasksDueOn(day);
    final empty = events.isEmpty && tasks.isEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: isToday ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isToday ? scheme.primary : scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${day.month}/${day.day}（${weekdayNames[day.weekday - 1]}）',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: day.weekday == 7
                      ? Colors.red
                      : (day.weekday == 6 ? Colors.blue : null),
                ),
              ),
              if (isToday)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('今日', style: TextStyle(fontSize: 12)),
                ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'この日に予定を追加',
                icon: const Icon(Icons.add, size: 20),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => EventEditPage(initialDate: day),
                )),
              ),
            ],
          ),
          if (empty) const EmptyNote('予定なし'),
          for (final e in events) EventTile(event: e),
          for (final t in tasks) TaskTile(task: t),
        ],
      ),
    );
  }
}
