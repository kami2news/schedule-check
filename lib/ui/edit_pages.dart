import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'layout.dart';

/// 広い画面ではダイアログ、狭い画面では全画面で開く
Future<void> _openEditor(BuildContext context, Widget page) {
  if (useDialog(context)) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: page,
        ),
      ),
    );
  }
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page));
}

/// 予定の追加（[event] が null）または編集
Future<void> openEventEditor(BuildContext context,
    {Event? event, DateTime? date, int? startMin}) {
  return _openEditor(context,
      EventEditPage(event: event, initialDate: date, initialStartMin: startMin));
}

/// タスクの追加（[task] が null）または編集
Future<void> openTaskEditor(BuildContext context, {TaskItem? task}) {
  return _openEditor(context, TaskEditPage(task: task));
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
}

Future<int?> _pickTime(BuildContext context, int initialMin) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initialMin ~/ 60, minute: initialMin % 60),
  );
  if (t == null) return null;
  return t.hour * 60 + t.minute;
}

Future<bool> _confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$whatを削除しますか？'),
      content: const Text('この操作は元に戻せません。'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除')),
      ],
    ),
  );
  return ok ?? false;
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

// ---------------------------------------------------------------------------
// 予定（シフト・授業・その他）の追加／編集
// ---------------------------------------------------------------------------

class EventEditPage extends StatefulWidget {
  const EventEditPage(
      {super.key, this.event, this.initialDate, this.initialStartMin});

  final Event? event;
  final DateTime? initialDate;

  /// 時間グリッドの空き枠をタップしたときの開始時刻（分）
  final int? initialStartMin;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _place;
  late final TextEditingController _note;
  late EventKind _kind;
  late DateTime _date;
  late bool _allDay;
  late int _start;
  late int _end;
  late bool _weekly;
  DateTime? _until;

  bool get _isNew => widget.event == null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _place = TextEditingController(text: e?.place ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _kind = e?.kind ?? EventKind.other;
    _date = e?.date ?? dateOnly(widget.initialDate ?? DateTime.now());
    _allDay = e?.allDay ?? false;
    _start = e?.startMin ?? widget.initialStartMin ?? 9 * 60;
    _end = e?.endMin ?? math.min(_start + 60, 23 * 60 + 59);
    _weekly = e?.weekly ?? false;
    _until = e?.repeatUntil;
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _chooseStart() async {
    final v = await _pickTime(context, _start);
    if (v == null) return;
    setState(() {
      _start = v;
      if (_end <= _start) _end = (_start + 60).clamp(0, 23 * 60 + 59).toInt();
    });
  }

  Future<void> _chooseEnd() async {
    final v = await _pickTime(context, _end);
    if (v == null) return;
    setState(() => _end = v);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack(context, 'タイトルを入力してください');
      return;
    }
    if (!_allDay && _end <= _start) {
      _snack(context, '終了時刻は開始時刻より後にしてください');
      return;
    }
    final store = StoreScope.read(context);
    store.upsertEvent(Event(
      id: widget.event?.id ?? store.newId(),
      title: title,
      kind: _kind,
      date: _date,
      startMin: _allDay ? null : _start,
      endMin: _allDay ? null : _end,
      weekly: _weekly,
      repeatUntil: _weekly ? _until : null,
      place: _place.text.trim(),
      note: _note.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await _confirmDelete(context, widget.event!.weekly ? '繰り返しの予定全体' : 'この予定')) {
      return;
    }
    if (!mounted) return;
    StoreScope.read(context).deleteEvent(widget.event!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '予定を追加' : '予定を編集'),
        actions: [
          if (!_isNew)
            IconButton(
                onPressed: _delete,
                tooltip: '削除',
                icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: _isNew,
            decoration: const InputDecoration(
                labelText: 'タイトル', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SegmentedButton<EventKind>(
            segments: [
              for (final k in EventKind.values)
                ButtonSegment(value: k, label: Text(k.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() {
              _kind = s.first;
              // 授業は毎週の時間割として登録することが多いので初期値を変える
              if (_isNew) _weekly = _kind == EventKind.lecture;
            }),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_weekly
                ? '${fmtDate(_date)} から（毎週${weekdayNames[_date.weekday - 1]}曜）'
                : fmtDate(_date)),
            onTap: () async {
              final v = await _pickDate(context, _date);
              if (v != null) setState(() => _date = v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('終日'),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          if (!_allDay)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _chooseStart,
                    icon: const Icon(Icons.schedule),
                    label: Text('開始 ${fmtMin(_start)}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _chooseEnd,
                    icon: const Icon(Icons.schedule),
                    label: Text('終了 ${fmtMin(_end)}'),
                  ),
                ),
              ],
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('毎週くり返す'),
            subtitle: const Text('時間割や固定シフト向け'),
            value: _weekly,
            onChanged: (v) => setState(() => _weekly = v),
          ),
          if (_weekly)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy),
              title: Text(_until == null ? '終了日なし' : '${fmtDate(_until!)} まで'),
              trailing: _until == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _until = null)),
              onTap: () async {
                final v = await _pickDate(context, _until ?? _date);
                if (v != null) setState(() => _until = v);
              },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _place,
            decoration: const InputDecoration(
                labelText: '場所（任意）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'メモ（任意）', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// タスク（締切）の追加／編集
// ---------------------------------------------------------------------------

class TaskEditPage extends StatefulWidget {
  const TaskEditPage({super.key, this.task});

  final TaskItem? task;

  @override
  State<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  DateTime? _due;
  int? _dueMin;
  bool _important = false;

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _due = t?.due;
    _dueMin = t?.dueMin;
    _important = t?.important ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack(context, 'タイトルを入力してください');
      return;
    }
    final store = StoreScope.read(context);
    store.upsertTask(TaskItem(
      id: widget.task?.id ?? store.newId(),
      title: title,
      due: _due,
      dueMin: _due == null ? null : _dueMin,
      done: widget.task?.done ?? false,
      important: _important,
      note: _note.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!await _confirmDelete(context, 'このタスク')) return;
    if (!mounted) return;
    StoreScope.read(context).deleteTask(widget.task!.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'タスクを追加' : 'タスクを編集'),
        actions: [
          if (!_isNew)
            IconButton(
                onPressed: _delete,
                tooltip: '削除',
                icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: _isNew,
            decoration: const InputDecoration(
                labelText: 'タイトル', border: OutlineInputBorder()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(_important ? Icons.star : Icons.star_border,
                color: _important ? Colors.amber : null),
            title: const Text('重要'),
            value: _important,
            onChanged: (v) => setState(() => _important = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: Text(_due == null ? '期限なし（タップして設定）' : fmtDate(_due!)),
            trailing: _due == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _due = null;
                      _dueMin = null;
                    })),
            onTap: () async {
              final v = await _pickDate(context, _due ?? DateTime.now());
              if (v != null) setState(() => _due = dateOnly(v));
            },
          ),
          if (_due != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dueMin == null ? '時刻を指定しない' : '締切時刻 ${fmtMin(_dueMin!)}'),
              value: _dueMin != null,
              onChanged: (v) async {
                if (!v) {
                  setState(() => _dueMin = null);
                  return;
                }
                final picked = await _pickTime(context, _dueMin ?? 23 * 60 + 59);
                if (picked != null) setState(() => _dueMin = picked);
              },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'メモ（任意）', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}
