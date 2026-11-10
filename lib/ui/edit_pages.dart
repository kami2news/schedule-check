import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'fluent.dart';
import 'fluent_extras.dart';
import 'layout.dart';
import 'widgets.dart';

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
                padding: EdgeInsets.fromLTRB(24, 16, 12, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: FlText.subtitle1)),
                    IconButton(
                      tooltip: '閉じる',
                      icon: Icon(FluentIcons.dismiss_24_regular),
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
/// [occurrence] は、毎週の予定をカレンダー上のどの回から開いたか
Future<void> openEventEditor(BuildContext context,
    {Event? event, DateTime? date, int? startMin, DateTime? occurrence}) {
  return _openEditor(
      context,
      EventEditPage(
          event: event,
          initialDate: date,
          initialStartMin: startMin,
          occurrence: occurrence));
}

/// 繰り返しの予定を変更・削除する範囲
enum RecurScope { one, following, all }

Future<RecurScope?> _askScope(BuildContext context, {required bool delete}) {
  return showFlChoice<RecurScope>(
    context,
    title: delete ? '繰り返しの予定を削除' : '繰り返しの予定を変更',
    options: [
      (RecurScope.one, 'この回のみ'),
      (RecurScope.following, 'この回以降'),
      (RecurScope.all, 'すべての回'),
    ],
    initial: RecurScope.one,
    confirmLabel: delete ? '削除' : '保存',
    danger: delete,
  );
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

Future<int?> _pickTime(BuildContext context, int initialMin) {
  return showFlTimeList(context, initialMin, extra: [23 * 60 + 59]);
}

Future<bool> _confirmDelete(BuildContext context, String what) {
  return showFlConfirm(
    context,
    title: '$whatを削除しますか？',
    message: 'この操作は元に戻せません。',
    confirmLabel: '削除',
  );
}

/// リンク欄。入力があれば「参加」「開く」ボタンを横に出す
Widget _linkField(
    BuildContext context, TextEditingController c, VoidCallback onChanged,
    {String hint = 'Zoom・Teams などのURL'}) {
  final url = c.text.trim();
  return FlField(
    label: 'リンク（任意）',
    child: Row(
      children: [
        Expanded(
          child: FlTextField(
            controller: c,
            hint: hint,
            onChanged: (_) => onChanged(),
            leading: Icon(
                url.isEmpty ? FluentIcons.link_24_regular : linkIcon(url),
                size: 16,
                color: Fl.fg3),
          ),
        ),
        if (url.isNotEmpty) ...[
          SizedBox(width: 8),
          FlLinkButton(url: url),
        ],
      ],
    ),
  ).withHelp(url.isNotEmpty && normalizeUrl(url) == null
      ? '有効なURLを入力してください（例: https://zoom.us/j/...）'
      : null);
}

/// リンク欄の値を確認する。空なら ''、無効なら null、有効なら整えたURL
String? _checkedUrl(TextEditingController c) {
  final t = c.text.trim();
  if (t.isEmpty) return '';
  return normalizeUrl(t);
}

extension on FlField {
  /// 入力欄の下に赤い補足を出す
  Widget withHelp(String? message) {
    if (message == null) return this;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlField(label: label, child: child),
        Transform.translate(
          offset: Offset(0, -8),
          child: Text(message,
              style: FlText.caption1.copyWith(color: Fl.danger)),
        ),
      ],
    );
  }
}

Widget _errorText(String? msg) {
  if (msg == null) return SizedBox.shrink();
  return Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(FluentIcons.error_circle_16_filled,
            size: 16, color: Fl.danger),
        SizedBox(width: 6),
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
      {super.key,
      this.event,
      this.initialDate,
      this.initialStartMin,
      this.occurrence});

  final Event? event;
  final DateTime? initialDate;

  /// 毎週の予定を開いた回の日付（この回のみ／以降の変更に使う）
  final DateTime? occurrence;

  /// 時間グリッドの空き枠をタップしたときの開始時刻（分）
  final int? initialStartMin;

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _place;
  late final TextEditingController _note;
  late final TextEditingController _url;
  late String _cal;
  late ShowAs _showAs;
  late DateTime _date;
  late bool _allDay;
  late int _start;
  late int _end;
  late bool _weekly;
  DateTime? _until;
  String? _error;

  bool get _isNew => widget.event == null;

  /// 毎週の予定を、カレンダー上の特定の回から開いたか
  bool get _isOccurrence =>
      widget.event != null && widget.event!.weekly && widget.occurrence != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _place = TextEditingController(text: e?.place ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _url = TextEditingController(text: e?.url ?? '');
    _cal = e?.calendarId ?? 'other';
    _showAs = e?.showAs ?? ShowAs.busy;
    _date = (e != null && e.weekly && widget.occurrence != null)
        ? dateOnly(widget.occurrence!)
        : (e?.date ?? dateOnly(widget.initialDate ?? DateTime.now()));
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
    _url.dispose();
    super.dispose();
  }

  Future<void> _chooseStart() async {
    final v = await _pickTime(context, _start);
    if (v == null) return;
    setState(() {
      _start = v;
      if (_end <= _start) _end = (_start + 60).clamp(0, 23 * 60 + 59).toInt();
      _revalidate();
    });
  }

  Future<void> _chooseEnd() async {
    final v = await _pickTime(context, _end);
    if (v == null) return;
    setState(() {
      _end = v;
      _revalidate();
    });
  }

  /// 入力内容を確認し、問題があればメッセージを返す
  String? _validate() {
    if (_title.text.trim().isEmpty) return 'タイトルを入力してください';
    if (!_allDay && _end <= _start) return '終了時刻は開始時刻より後にしてください';
    if (_checkedUrl(_url) == null) return 'リンクの形式が正しくありません';
    return null;
  }

  /// エラー表示中なら、入力が変わるたびに確認し直して解消したら消す
  void _revalidate() {
    if (_error != null) _error = _validate();
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final store = StoreScope.read(context);
    final e = widget.event;
    final edited = Event(
      id: e?.id ?? store.newId(),
      title: _title.text.trim(),
      calendarId: store.calendarOf(_cal).id,
      showAs: _showAs,
      date: _date,
      startMin: _allDay ? null : _start,
      endMin: _allDay ? null : _end,
      weekly: _weekly,
      repeatUntil: _weekly ? _until : null,
      place: _place.text.trim(),
      note: _note.text.trim(),
      url: _checkedUrl(_url) ?? '',
      exdates: e == null ? null : {...e.exdates},
      seriesId: e?.seriesId,
      originalDate: e?.originalDate,
    );

    if (_isOccurrence) {
      final scope = await _askScope(context, delete: false);
      if (scope == null || !mounted) return;
      final occ = dateOnly(widget.occurrence!);
      switch (scope) {
        case RecurScope.one:
          store.changeOccurrence(e!, occ, edited);
        case RecurScope.following:
          store.changeFollowing(e!, occ, edited);
        case RecurScope.all:
          // この回で日付を動かした分だけ、最初の回もずらす
          final shift = dateOnly(_date).difference(occ).inDays;
          store.upsertEvent(edited.weekly
              ? edited.copyWith(date: e!.firstDate.add(Duration(days: shift)))
              : edited);
      }
    } else {
      store.upsertEvent(edited);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.event!;
    final store = StoreScope.read(context);
    if (_isOccurrence) {
      final scope = await _askScope(context, delete: true);
      if (scope == null || !mounted) return;
      final occ = dateOnly(widget.occurrence!);
      switch (scope) {
        case RecurScope.one:
          store.deleteOccurrence(e, occ);
        case RecurScope.following:
          store.deleteFollowing(e, occ);
        case RecurScope.all:
          store.deleteSeries(e);
      }
    } else {
      if (!await _confirmDelete(context, e.weekly ? '繰り返しの予定全体' : 'この予定')) {
        return;
      }
      if (!mounted) return;
      e.weekly ? store.deleteSeries(e) : store.deleteEvent(e.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FlEditorFrame(
      title: _isNew ? '予定を追加' : '予定を編集',
      onSave: _save,
      onDelete: _isNew ? null : _delete,
      children: [
        _errorText(_error),
        if (_isOccurrence || (widget.event?.isException ?? false))
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(FluentIcons.arrow_repeat_all_24_regular,
                  size: 16, color: Fl.fg3),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  _isOccurrence
                      ? '毎週の予定の${fmtDate(widget.occurrence!)}の回です。保存・削除のときに「この回のみ／この回以降／すべての回」を選べます'
                      : '毎週の予定のうち、${fmtDate(widget.event!.originalDate!)}の回だけを変更した予定です',
                  style: FlText.caption1.copyWith(color: Fl.fg3),
                ),
              ),
            ]),
          ),
        FlField(
          label: 'タイトル',
          child: FlTextField(
            controller: _title,
            autofocus: _isNew,
            onChanged: (_) => setState(_revalidate),
          ),
        ),
        Builder(builder: (context) {
          final store = StoreScope.of(context);
          final cal = store.calendarOf(_cal);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FlField(
                  label: 'カレンダー',
                  child: FlDropdown<CalendarDef>(
                    items: store.calendars,
                    value: cal,
                    labelOf: (c) => c.name,
                    leadingOf: (c) => FlColorDot(color: c.color),
                    onChanged: (c) => setState(() {
                      _cal = c.id;
                      // 授業は毎週の時間割として登録することが多いので初期値を変える
                      if (_isNew) _weekly = c.id == 'lecture';
                    }),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FlField(
                  label: '表示方法',
                  child: FlDropdown<ShowAs>(
                    items: ShowAs.values,
                    value: _showAs,
                    labelOf: (v) => v.label,
                    leadingOf: (v) =>
                        FlShowAsSwatch(showAs: v, color: cal.color),
                    onChanged: (v) => setState(() => _showAs = v),
                  ),
                ),
              ),
            ],
          );
        }),
        FlField(
          label: '日付',
          child: FlPickerField(
            icon: FluentIcons.calendar_ltr_24_regular,
            text: _isOccurrence
                ? '${fmtLongDate(_date)}（毎週${weekdayNames[_date.weekday - 1]}曜の回）'
                : _weekly
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
          onChanged: (v) => setState(() {
            _allDay = v;
            _revalidate();
          }),
        ),
        if (!_allDay)
          Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
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
                SizedBox(width: 12),
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
            padding: EdgeInsets.only(top: 8),
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
        SizedBox(height: 8),
        FlField(
          label: '場所（任意）',
          child: FlTextField(
            controller: _place,
            leading: Icon(FluentIcons.location_24_regular,
                size: 16, color: Fl.fg3),
          ),
        ),
        _linkField(context, _url, () => setState(_revalidate)),
        FlField(
          label: 'メモ（任意）',
          child: FlTextField(
            controller: _note,
            hint: 'ミーティングID・パスコード・持ち物など',
            minLines: 3,
            maxLines: 6,
          ),
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
  late final TextEditingController _url;
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
    _url = TextEditingController(text: t?.url ?? '');
    _due = t?.due;
    _dueMin = t?.dueMin;
    _important = t?.important ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _url.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'タイトルを入力してください';
    if (_checkedUrl(_url) == null) return 'リンクの形式が正しくありません';
    return null;
  }

  void _revalidate() {
    if (_error != null) _error = _validate();
  }

  void _save() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final title = _title.text.trim();
    final store = StoreScope.read(context);
    store.upsertTask(TaskItem(
      id: widget.task?.id ?? store.newId(),
      title: title,
      due: _due,
      dueMin: _due == null ? null : _dueMin,
      done: widget.task?.done ?? false,
      important: _important,
      note: _note.text.trim(),
      url: _checkedUrl(_url) ?? '',
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
          child: FlTextField(
            controller: _title,
            autofocus: _isNew,
            onChanged: (_) => setState(_revalidate),
          ),
        ),
        FlSwitchTile(
          title: '重要',
          icon: _important
              ? FluentIcons.star_24_filled
              : FluentIcons.star_24_regular,
          value: _important,
          onChanged: (v) => setState(() => _important = v),
        ),
        SizedBox(height: 8),
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
        SizedBox(height: 8),
        _linkField(context, _url, () => setState(_revalidate),
            hint: '提出先・資料などのURL'),
        FlField(
          label: 'メモ（任意）',
          child: FlTextField(controller: _note, minLines: 3, maxLines: 6),
        ),
      ],
    );
  }
}
