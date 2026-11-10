import 'package:flutter/material.dart';

import '../models.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'mini_month.dart';

/// 広い画面の左サイドバー（新しい予定・ミニカレンダー・表示するカレンダー）
class CalendarSidebar extends StatelessWidget {
  const CalendarSidebar(
      {super.key, required this.controller, required this.onImport});

  final CalendarController controller;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () =>
                    openEventEditor(context, date: controller.selected),
                icon: const Icon(Icons.add),
                label: const Text('新しい予定'),
              ),
            ),
            const SizedBox(height: 12),
            MiniMonth(controller: controller),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('カレンダー',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold)),
            ),
            for (final k in EventKind.values)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: k.color,
                value: !controller.hidden.contains(k),
                onChanged: (_) => controller.toggleKind(k),
                title: Text(k.label),
              ),
            CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: controller.showTasks,
              onChanged: (v) => controller.setShowTasks(v ?? true),
              title: const Text('タスクの期限'),
            ),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.content_paste),
              title: const Text('メールなどから取り込む'),
              onTap: onImport,
            ),
          ],
        );
      },
    );
  }
}
