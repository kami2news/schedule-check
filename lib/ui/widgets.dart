import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'edit_pages.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(text,
          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
    );
  }
}

class KindChip extends StatelessWidget {
  const KindChip(this.kind, {super.key});

  final EventKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(kind.label,
          style: TextStyle(
              fontSize: 12, color: kind.color, fontWeight: FontWeight.bold)),
    );
  }
}

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => EventEditPage(event: e),
        )),
        leading: Container(
          width: 6,
          height: 40,
          decoration: BoxDecoration(
            color: e.kind.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        title: Text(e.title),
        subtitle:
            Text([e.timeLabel, if (e.place.isNotEmpty) e.place].join('  ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (e.weekly) const Icon(Icons.repeat, size: 16),
            if (e.weekly) const SizedBox(width: 6),
            KindChip(e.kind),
          ],
        ),
      ),
    );
  }
}

/// 期限までの残りを「あと3日」などで表す
({String text, Color? color}) dueInfo(BuildContext context, TaskItem t) {
  if (t.due == null) return (text: '期限なし', color: null);
  final today = dateOnly(DateTime.now());
  final diff = dateOnly(t.due!).difference(today).inDays;
  final time = t.dueMin == null ? '' : ' ${fmtMin(t.dueMin!)}';
  final base = '${fmtDate(t.due!)}$time';
  if (t.done) return (text: base, color: null);
  if (diff < 0) return (text: '$base  ${-diff}日超過', color: Colors.red);
  if (diff == 0) return (text: '$base  今日まで', color: Colors.deepOrange);
  if (diff == 1) return (text: '$base  明日まで', color: Colors.orange);
  return (text: '$base  あと$diff日', color: null);
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final info = dueInfo(context, t);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TaskEditPage(task: t),
        )),
        leading: Checkbox(
          value: t.done,
          onChanged: (_) => StoreScope.read(context).toggleTask(t.id),
        ),
        title: Text(
          t.title,
          style: TextStyle(
            decoration: t.done ? TextDecoration.lineThrough : null,
            color: t.done ? Theme.of(context).colorScheme.outline : null,
          ),
        ),
        subtitle: Text(info.text, style: TextStyle(color: info.color)),
      ),
    );
  }
}
