import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'widgets.dart';

/// Microsoft To Do 風のリスト
enum TodoList { myDay, important, planned, all }

extension TodoListX on TodoList {
  String get label => switch (this) {
        TodoList.myDay => 'マイデイ',
        TodoList.important => '重要',
        TodoList.planned => '期限あり',
        TodoList.all => 'すべて',
      };

  /// マイデイ = 今日が期限、または期限切れのタスク
  bool matches(TaskItem t, DateTime today) => switch (this) {
        TodoList.myDay =>
          t.due != null && !dateOnly(t.due!).isAfter(today),
        TodoList.important => t.important,
        TodoList.planned => t.due != null,
        TodoList.all => true,
      };
}

class TodoPanel extends StatefulWidget {
  const TodoPanel({super.key});

  @override
  State<TodoPanel> createState() => _TodoPanelState();
}

class _TodoPanelState extends State<TodoPanel> {
  TodoList _list = TodoList.myDay;
  final TextEditingController _quick = TextEditingController();
  final FocusNode _focus = FocusNode();
  DateTime? _quickDue;
  bool _showDone = false;

  @override
  void dispose() {
    _quick.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final title = _quick.text.trim();
    if (title.isEmpty) return;
    final store = StoreScope.read(context);
    final today = dateOnly(DateTime.now());
    DateTime? due = _quickDue;
    // 今表示しているリストから消えてしまわないように期限を補う
    if (due == null &&
        (_list == TodoList.myDay || _list == TodoList.planned)) {
      due = today;
    }
    store.upsertTask(TaskItem(
      id: store.newId(),
      title: title,
      due: due,
      important: _list == TodoList.important,
    ));
    _quick.clear();
    setState(() => _quickDue = null);
    _focus.requestFocus();
  }

  Future<void> _pickQuickDue() async {
    final v = await showDatePicker(
      context: context,
      initialDate: _quickDue ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (v != null) setState(() => _quickDue = dateOnly(v));
  }

  static int _byImportanceThenDue(TaskItem a, TaskItem b) {
    if (a.important != b.important) return a.important ? -1 : 1;
    return compareTasks(a, b);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = dateOnly(DateTime.now());

    final inList = store.tasks.where((t) => _list.matches(t, today)).toList();
    final open = inList.where((t) => !t.done).toList()
      ..sort(_byImportanceThenDue);
    final done = inList.where((t) => t.done).toList()..sort(compareTasks);

    int countOf(TodoList l) =>
        store.tasks.where((t) => !t.done && l.matches(t, today)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              const Icon(FluentIcons.task_list_ltr_24_filled,
                  size: 22, color: Fl.brand),
              const SizedBox(width: 8),
              Text('To Do', style: FlText.subtitle1),
            ],
          ),
        ),
        FlTabList(
          labels: [for (final l in TodoList.values) l.label],
          counts: [for (final l in TodoList.values) countOf(l)],
          selected: TodoList.values.indexOf(_list),
          onSelected: (i) => setState(() => _list = TodoList.values[i]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: FlTextField(
            controller: _quick,
            focusNode: _focus,
            hint: 'タスクを追加',
            onSubmitted: (_) => _add(),
            leading: const Icon(FluentIcons.add_24_regular,
                size: 18, color: Fl.brand),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_quickDue != null)
                  Text(fmtDate(_quickDue!),
                      style: FlText.caption1.copyWith(color: Fl.brand)),
                IconButton(
                  tooltip: '期限',
                  icon: Icon(
                    FluentIcons.calendar_ltr_24_regular,
                    size: 18,
                    color: _quickDue != null ? Fl.brand : Fl.fg2,
                  ),
                  onPressed: _pickQuickDue,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 96),
            children: [
              if (open.isEmpty && done.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  child: Column(
                    children: [
                      const Icon(FluentIcons.checkmark_circle_48_regular,
                          size: 48, color: Fl.stroke1),
                      const SizedBox(height: 12),
                      Text(
                        _list == TodoList.myDay
                            ? '今日が期限のタスクはありません'
                            : 'タスクはありません',
                        textAlign: TextAlign.center,
                        style: FlText.body1.copyWith(color: Fl.fg3),
                      ),
                    ],
                  ),
                ),
              for (final t in open) _TaskRow(task: t),
              if (done.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _showDone = !_showDone),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Row(
                      children: [
                        Icon(
                          _showDone
                              ? FluentIcons.chevron_down_24_regular
                              : FluentIcons.chevron_right_24_regular,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text('完了済み ${done.length}',
                            style: FlText.body1Strong),
                      ],
                    ),
                  ),
                ),
              if (_showDone) for (final t in done) _TaskRow(task: t),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final info = dueInfo(context, t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Fl.bg1,
          borderRadius: BorderRadius.circular(Fl.r4),
          boxShadow: Fl.shadow2,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(Fl.r4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openTaskEditor(context, task: t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  FlCheckCircle(
                    checked: t.done,
                    onTap: () => StoreScope.read(context).toggleTask(t.id),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.title,
                          style: FlText.body1.copyWith(
                            decoration:
                                t.done ? TextDecoration.lineThrough : null,
                            color: t.done ? Fl.fg3 : Fl.fg1,
                          ),
                        ),
                        if (t.due != null)
                          Text(
                            info.text,
                            style: FlText.caption1
                                .copyWith(color: info.color ?? Fl.fg3),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '重要',
                    icon: Icon(
                      t.important
                          ? FluentIcons.star_24_filled
                          : FluentIcons.star_24_regular,
                      size: 20,
                      color: t.important ? Fl.brand : Fl.fg3,
                    ),
                    onPressed: () =>
                        StoreScope.read(context).toggleImportant(t.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
