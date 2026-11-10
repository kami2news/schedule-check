import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'mini_month.dart';

/// 広い画面の左サイドバー（新しい予定・ミニカレンダー・マイカレンダー）。
/// Outlook と同じく、パネルではなくキャンバス上にそのまま置く。
class CalendarSidebar extends StatelessWidget {
  const CalendarSidebar(
      {super.key, required this.controller, required this.onImport});

  final CalendarController controller;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () =>
                    openEventEditor(context, date: controller.selected),
                icon: Icon(FluentIcons.calendar_add_24_regular, size: 18),
                label: Text('新しい予定'),
              ),
            ),
            SizedBox(height: 12),
            MiniMonth(controller: controller),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text('マイカレンダー', style: FlText.body1Strong),
            ),
            for (final k in EventKind.values)
              FlCheckRow(
                label: k.label,
                color: k.color,
                value: !controller.hidden.contains(k),
                onChanged: (_) => controller.toggleKind(k),
              ),
            FlCheckRow(
              label: 'タスクの期限',
              value: controller.showTasks,
              onChanged: controller.setShowTasks,
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            InkWell(
              onTap: onImport,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(FluentIcons.clipboard_paste_24_regular,
                        size: 20, color: Fl.fg2),
                    SizedBox(width: 12),
                    Text('メールなどから取り込む', style: FlText.body1),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
