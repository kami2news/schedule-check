import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'edit_pages.dart';
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

  IconData get icon => switch (this) {
        TodoList.myDay => Icons.wb_sunny_outlined,
        TodoList.important => Icons.star_border,
        TodoList.planned => Icons.calendar_today_outlined,
        TodoList.all => Icons.all_inbox_outlined,
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
    final scheme = Theme.of(context).colorScheme;
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('To Do',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: TodoList.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final l = TodoList.values[i];
              return Center(
                child: ChoiceChip(
                  avatar: Icon(l.icon, size: 16),
                  label: Text('${l.label} ${countOf(l)}'),
                  selected: _list == l,
                  onSelected: (_) => setState(() => _list = l),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.add),
                ),
                Expanded(
                  child: TextField(
                    controller: _quick,
                    focusNode: _focus,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      hintText: 'タスクを追加',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_quickDue != null)
                  Text(fmtDate(_quickDue!),
                      style: TextStyle(fontSize: 12, color: scheme.primary)),
                IconButton(
                  tooltip: '期限',
                  icon: Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: _quickDue != null ? scheme.primary : null,
                  ),
                  onPressed: _pickQuickDue,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (open.isEmpty && done.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _list == TodoList.myDay
                        ? '今日が期限のタスクはありません'
                        : 'タスクはありません',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.outline),
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
                        Icon(_showDone ? Icons.expand_more : Icons.chevron_right),
                        const SizedBox(width: 4),
                        Text('完了済み ${done.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final scheme = Theme.of(context).colorScheme;
    final info = dueInfo(context, t);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openTaskEditor(context, task: t),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Checkbox(
                shape: const CircleBorder(),
                value: t.done,
                onChanged: (_) => StoreScope.read(context).toggleTask(t.id),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        decoration: t.done ? TextDecoration.lineThrough : null,
                        color: t.done ? scheme.outline : null,
                      ),
                    ),
                    if (t.due != null)
                      Text(
                        info.text,
                        style: TextStyle(
                            fontSize: 12,
                            color: info.color ?? scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '重要',
                icon: Icon(
                  t.important ? Icons.star : Icons.star_border,
                  color: t.important ? Colors.amber : scheme.outline,
                ),
                onPressed: () =>
                    StoreScope.read(context).toggleImportant(t.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
