import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'widgets.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.tasks.isEmpty) {
      return const Center(
        child: Text(
          'タスクはまだありません。\n右下の＋から追加できます',
          textAlign: TextAlign.center,
        ),
      );
    }
    final open = store.tasks.where((t) => !t.done).toList()
      ..sort(compareTasks);
    final done = store.tasks.where((t) => t.done).toList()
      ..sort(compareTasks);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        SectionHeader('未完了（${open.length}）'),
        if (open.isEmpty) const EmptyNote('未完了のタスクはありません'),
        for (final t in open) TaskTile(task: t),
        if (done.isNotEmpty) ...[
          SectionHeader('完了済み（${done.length}）'),
          for (final t in done) TaskTile(task: t),
        ],
      ],
    );
  }
}
