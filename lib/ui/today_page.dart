import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'widgets.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final today = dateOnly(now);
    final weekLater = DateTime(today.year, today.month, today.day + 7);

    final events = store.eventsOn(today);
    final open = store.tasks.where((t) => !t.done && t.due != null).toList()
      ..sort(compareTasks);
    final overdue = open.where((t) => dateOnly(t.due!).isBefore(today)).toList();
    final dueToday = open.where((t) => dateOnly(t.due!) == today).toList();
    final soon = open.where((t) {
      final d = dateOnly(t.due!);
      return d.isAfter(today) && !d.isAfter(weekLater);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          '${today.month}月${today.day}日（${weekdayNames[today.weekday - 1]}）',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SectionHeader('今日の予定'),
        if (events.isEmpty) const EmptyNote('今日の予定はありません'),
        for (final e in events) EventTile(event: e),
        if (overdue.isNotEmpty) ...[
          const SectionHeader('期限切れ', color: Colors.red),
          for (final t in overdue) TaskTile(task: t),
        ],
        const SectionHeader('今日が締切'),
        if (dueToday.isEmpty) const EmptyNote('今日が締切のタスクはありません'),
        for (final t in dueToday) TaskTile(task: t),
        const SectionHeader('今後7日以内の締切'),
        if (soon.isEmpty) const EmptyNote('直近の締切はありません'),
        for (final t in soon) TaskTile(task: t),
      ],
    );
  }
}
