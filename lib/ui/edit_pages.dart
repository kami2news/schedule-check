import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'fluent.dart';
import 'fluent_extras.dart';
import 'layout.dart';

/// 広い画面ではダイアログ、狭い画面では全画面で開く
Future<void> _openEditor(BuildContext context, Widget page) {
  if (useDialog(context)) {
    return showFlDialog<void>(context, child: page, maxHeight: 680);
  }
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page));
}

/// タイトル付きの枠（ヘッダー + 閉じる）で任意の画面をダイアログ／全画面表示する
Future<void> showFlDialogOrPage(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  Widget frame(BuildContext ctx) => Material(
        color: Fl.bg1,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: FlText.subtitle1)),
                    IconButton(
                      tooltip: '閉じる',
                      icon: const Icon(FluentIcons.dismiss_24_regular),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(child: builder(ctx)),
            ],
          ),
        ),
      );
  if (useDialog(context)) {
    return showFlDialog<void>(context,
        child: Builder(builder: frame), maxHeight: 680);
  }
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (ctx) => frame(ctx)));
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

Future<bool> _confirmDelete(BuildContext context, String what) {
  return showFlConfirm(
    context,
    title: '$whatを削除しますか？',
    message: 'この操作は元に戻せません。',
    confirmLabel: '削除',
  );
}

Widget _errorText(String? msg) {
  if (msg == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(FluentIcons.error_circle_16_filled,
            size: 16, color: Fl.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(msg, style: FlText.caption1.copyWith(color: Fl.danger)),
        ),
      ],
    ),
  );
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
  String? _error;

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
      setState(() => _error = 'タイトルを入力してください');
      return;
    }
    if (!_allDay && _end <= _start) {
      setState(() => _error = '終了時刻は開始時刻より後にしてください');
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
    return FlEditorFrame(
      title: _isNew ? '予定を追加' : '予定を編集',
      onSave: _save,
      onDelete: _isNew ? null : _delete,
      children: [
        _errorText(_error),
        FlField(
          label: 'タイトル',
          child: FlTextField(controller: _title, autofocus: _isNew),
        ),
        FlField(
          label: '種類',
          child: FlToggleGroup<EventKind>(
            items: EventKind.values,
            value: _kind,
            labelOf: (k) => k.label,
            onChanged: (k) => setState(() {
              _kind = k;
              // 授業は毎週の時間割として登録することが多いので初期値を変える
              if (_isNew) _weekly = _kind == EventKind.lecture;
            }),
          ),
        ),
        FlField(
          label: '日付',
          child: FlPickerField(
            icon: FluentIcons.calendar_ltr_24_regular,
            text: _weekly
                ? '${fmtLongDate(_date)} から（毎週${weekdayNames[_date.weekday - 1]}曜）'
                : fmtLongDate(_date),
            onTap: () async {
              final v = await _pickDate(context, _date);
              if (v != null) setState(() => _date = dateOnly(v));
            },
          ),
        ),
        FlSwitchTile(
          title: '終日',
          value: _allDay,
          onChanged: (v) => setState(() => _allDay = v),
        ),
        if (!_allDay)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: FlField(
                    label: '開始',
                    child: FlPickerField(
                      icon: FluentIcons.clock_24_regular,
                      text: fmtMin(_start),
                      onTap: _chooseStart,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FlField(
                    label: '終了',
                    child: FlPickerField(
                      icon: FluentIcons.clock_24_regular,
                      text: fmtMin(_end),
                      onTap: _chooseEnd,
                    ),
                  ),
                ),
              ],
            ),
          ),
        FlSwitchTile(
          title: '毎週くり返す',
          subtitle: '時間割や固定シフト向け',
          icon: FluentIcons.arrow_repeat_all_24_regular,
          value: _weekly,
          onChanged: (v) => setState(() => _weekly = v),
        ),
        if (_weekly)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FlField(
              label: 'くり返しの終了日',
              child: FlPickerField(
                icon: FluentIcons.calendar_cancel_24_regular,
                text: _until == null ? '終了日なし' : '${fmtLongDate(_until!)} まで',
                placeholder: _until == null,
                onClear: _until == null
                    ? null
                    : () => setState(() => _until = null),
                onTap: () async {
                  final v = await _pickDate(context, _until ?? _date);
                  if (v != null) setState(() => _until = dateOnly(v));
                },
              ),
            ),
          ),
        const SizedBox(height: 8),
        FlField(
          label: '場所（任意）',
          child: FlTextField(controller: _place),
        ),
        FlField(
          label: 'メモ（任意）',
          child: FlTextField(controller: _note, minLines: 3, maxLines: 3),
        ),
      ],
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
  String? _error;

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
      setState(() => _error = 'タイトルを入力してください');
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
    return FlEditorFrame(
      title: _isNew ? 'タスクを追加' : 'タスクを編集',
      onSave: _save,
      onDelete: _isNew ? null : _delete,
      children: [
        _errorText(_error),
        FlField(
          label: 'タイトル',
          child: FlTextField(controller: _title, autofocus: _isNew),
        ),
        FlSwitchTile(
          title: '重要',
          icon: _important
              ? FluentIcons.star_24_filled
              : FluentIcons.star_24_regular,
          value: _important,
          onChanged: (v) => setState(() => _important = v),
        ),
        const SizedBox(height: 8),
        FlField(
          label: '期限',
          child: FlPickerField(
            icon: FluentIcons.calendar_ltr_24_regular,
            text: _due == null ? '期限なし（タップして設定）' : fmtLongDate(_due!),
            placeholder: _due == null,
            onClear: _due == null
                ? null
                : () => setState(() {
                      _due = null;
                      _dueMin = null;
                    }),
            onTap: () async {
              final v = await _pickDate(context, _due ?? DateTime.now());
              if (v != null) setState(() => _due = dateOnly(v));
            },
          ),
        ),
        if (_due != null)
          FlSwitchTile(
            title: _dueMin == null ? '時刻を指定しない' : '締切時刻 ${fmtMin(_dueMin!)}',
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
        FlField(
          label: 'メモ（任意）',
          child: FlTextField(controller: _note, minLines: 3, maxLines: 3),
        ),
      ],
    );
  }
}
