import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../notify/system_notifier.dart';
import '../reminders.dart';
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

/// 予定を削除する。繰り返しの回から開いた場合は範囲（この回のみ／以降／すべて）を聞く。
/// 削除したら true
Future<bool> deleteEventInteractive(
    BuildContext context, Event e, DateTime? occurrence) async {
  final store = StoreScope.read(context);
  final linked = store.tasksFor(e, occurrence).where((t) => !t.done).length;
  if (e.weekly && occurrence != null) {
    final scope = await _askScope(context, delete: true);
    if (scope == null) return false;
    final occ = dateOnly(occurrence);
    switch (scope) {
      case RecurScope.one:
        store.deleteOccurrence(e, occ);
      case RecurScope.following:
        store.deleteFollowing(e, occ);
      case RecurScope.all:
        store.deleteSeries(e);
    }
    return true;
  }
  final what = e.weekly ? '繰り返しの予定全体' : 'この予定';
  final ok = await showFlConfirm(
    context,
    title: '$whatを削除しますか？',
    message: linked > 0
        ? '関連するタスク$linked件（終了報告など）もいっしょに削除されます。この操作は元に戻せません。'
        : 'この操作は元に戻せません。',
    confirmLabel: '削除',
  );
  if (!ok) return false;
  e.weekly ? store.deleteSeries(e) : store.deleteEvent(e.id);
  return true;
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
/// タスクの追加（[task] が null）または編集。
/// 追加のときは [title]・[due]・[important] で初期値を渡せる（To Do の入力欄からの続きなど）
Future<void> openTaskEditor(BuildContext context,
    {TaskItem? task,
    Event? forEvent,
    DateTime? occurrence,
    String? title,
    DateTime? due,
    bool important = false}) {
  if (task == null && forEvent != null) {
    return _openEditor(
        context, TaskEditPage(forEvent: forEvent, occurrence: occurrence));
  }
  return _openEditor(
      context,
      TaskEditPage(
          task: task,
          initialTitle: title,
          initialDue: due,
          initialImportant: important));
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initial,
    {DateTime? first}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2020),
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
            key: ValueKey('link-field'),
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
    // 補足の有無で部品の並びを変えない（変えると入力欄が作り直され、入力中にフォーカスが外れる）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlField(label: label, child: child),
        if (message != null)
          Transform.translate(
            offset: Offset(0, -8),
            child: Text(message,
                style: FlText.caption1.copyWith(color: Fl.danger)),
          ),
      ],
    );
  }
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

  /// 終了日が開始日の何日後か（夜勤などの日をまたぐ予定は 1 以上）
  int _endOffset = 0;
  Recurrence? _repeat;
  DateTime? _until;
  int? _reminder;
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
    _endOffset = e?.endOffset ?? 0;
    _date = (e != null && e.weekly && widget.occurrence != null)
        ? dateOnly(widget.occurrence!)
        : (e?.date ?? dateOnly(widget.initialDate ?? DateTime.now()));
    _allDay = e?.allDay ?? false;
    _start = e?.startMin ?? widget.initialStartMin ?? 9 * 60;
    _end = e?.endMin ?? math.min(_start + 60, 23 * 60 + 59);
    _repeat = e?.repeat;
    _until = e?.repeatUntil;
    // 新しい予定には、設定した既定の通知を最初から入れておく
    _reminder = e != null
        ? e.reminder
        : StoreScope.read(context).defaultReminder(_allDay ? 'allDay' : 'timed');
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
      // 同じ日のうちに終わらなくなったら、終了を1時間後に（深夜なら翌日にまたぐ）
      if (_endOffset == 0 && _end <= _start) {
        final end = _start + 60;
        _end = end % (24 * 60);
        if (end >= 24 * 60) _endOffset = 1;
      }
      _revalidate();
    });
  }

  Future<void> _chooseEnd() async {
    final v = await _pickTime(context, _end);
    if (v == null) return;
    setState(() {
      _end = v;
      // 開始より前の時刻を選んだら、翌日に終わる予定（夜勤など）として扱う
      if (_endOffset == 0 && _end <= _start) _endOffset = 1;
      _revalidate();
    });
  }

  /// 入力内容を確認し、問題があればメッセージを返す
  String? _validate() {
    if (_title.text.trim().isEmpty) return 'タイトルを入力してください';
    if (!_allDay && _endOffset == 0 && _end <= _start) {
      return '終了は開始より後にしてください（日をまたぐときは終了日を翌日に）';
    }
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
      endOffset: _endOffset,
      repeat: _repeat,
      repeatUntil: _repeat != null ? _until : null,
      place: _place.text.trim(),
      note: _note.text.trim(),
      url: _checkedUrl(_url) ?? '',
      exdates: e == null ? null : {...e.exdates},
      seriesId: e?.seriesId,
      originalDate: e?.originalDate,
      reminder: _reminder,
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
    final ok = await deleteEventInteractive(
        context, widget.event!, _isOccurrence ? widget.occurrence : null);
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FlEditorFrame(
      title: _isNew ? '予定を追加' : '予定を編集',
      onSave: _save,
      onDelete: _isNew ? null : _delete,
      error: _error,
      children: [
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
                      if (_isNew) {
                        _repeat = c.id == 'lecture' ? const Recurrence() : null;
                      }
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
                : _repeat != null
                    ? '${fmtLongDate(_date)} から（${_repeat!.label(_date)}）'
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
            // 終日と時刻ありでは通知の選び方が違うので、既定（なければ近いもの）に置き換える
            if (_reminder != null) {
              _reminder = StoreScope.read(context)
                      .defaultReminder(v ? 'allDay' : 'timed') ??
                  (v ? 360 : 15);
            }
            _revalidate();
          }),
        ),
        if (!_allDay)
          _PeriodPicker(
            start: _start,
            end: _end,
            onChanged: (st, en) => setState(() {
              _start = st;
              _end = en;
              _endOffset = 0; // 時限は同じ日のうちに終わる
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
        // 終了日（日をまたぐ予定・数日にわたる予定）
        FlField(
          label: '終了日',
          child: FlPickerField(
            key: ValueKey('end-date'),
            icon: FluentIcons.calendar_ltr_24_regular,
            text: switch (_endOffset) {
              0 => '${fmtLongDate(_date)}（開始日と同じ）',
              1 => '${fmtLongDate(addDays(_date, 1))}（翌日）',
              _ => '${fmtLongDate(addDays(_date, _endOffset))}（$_endOffset日後）',
            },
            onTap: () async {
              final v = await _pickDate(context, addDays(_date, _endOffset),
                  first: _date);
              if (v == null) return;
              setState(() {
                _endOffset =
                    (dateOnly(v).difference(dateOnly(_date)).inHours / 24).round();
                if (_endOffset < 0) _endOffset = 0;
                _revalidate();
              });
            },
          ),
        ),
        _RepeatEditor(
          date: _date,
          value: _repeat,
          onChanged: (r) => setState(() => _repeat = r),
        ),
        if (_repeat != null)
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
        ReminderField(
          value: _reminder,
          allDay: _allDay,
          onChanged: (v) => setState(() => _reminder = v),
        ),
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
  const TaskEditPage(
      {super.key,
      this.task,
      this.forEvent,
      this.occurrence,
      this.initialTitle,
      this.initialDue,
      this.initialImportant = false});

  final TaskItem? task;

  /// 新しく追加するときの初期値
  final String? initialTitle;
  final DateTime? initialDue;
  final bool initialImportant;

  /// 予定から「タスクを追加」したときの関連する予定（とその回）
  final Event? forEvent;
  final DateTime? occurrence;

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
  String? _eventId;
  DateTime? _eventDate;
  bool _followEnd = false;
  int? _reminder;

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? widget.initialTitle ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _url = TextEditingController(text: t?.url ?? '');
    _due = t?.due ?? widget.initialDue;
    _dueMin = t?.dueMin;
    _important = t?.important ?? widget.initialImportant;
    _eventId = t?.eventId ?? widget.forEvent?.id;
    final fe = widget.forEvent;
    _eventDate = t?.eventDate ??
        (fe != null && fe.weekly && widget.occurrence != null
            ? dateOnly(widget.occurrence!)
            : null);
    _followEnd = t?.followEnd ?? false;
    _reminder = t != null
        ? t.reminder
        : StoreScope.read(context).defaultDeadlineReminder(null);
    final ev = widget.forEvent;
    if (t == null && ev != null) {
      // 予定から作るときは、その日を期限の初期値にする
      _due = _eventDate ?? dateOnly(ev.date);
    }
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
    // 0:00 締め切りは前日の終日、23:59 はその日の終日にそろえる（予定の終了に合わせる場合は除く）
    var due = _due;
    int? dueMin = _due == null ? null : _dueMin;
    if (due != null && !(_eventId != null && _followEnd)) {
      (due, dueMin) = normalizeDeadline(due, dueMin);
    }
    store.upsertTask(TaskItem(
      id: widget.task?.id ?? store.newId(),
      title: title,
      due: due,
      dueMin: dueMin,
      done: widget.task?.done ?? false,
      important: _important,
      note: _note.text.trim(),
      url: _checkedUrl(_url) ?? '',
      eventId: _eventId,
      eventDate: _eventId == null ? null : _eventDate,
      followEnd: _eventId != null && _followEnd,
      reminder: _due == null ? null : _reminder,
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
      error: _error,
      children: [
        FlField(
          label: 'タイトル',
          child: FlTextField(
            controller: _title,
            autofocus: _isNew,
            onChanged: (_) => setState(_revalidate),
          ),
        ),
        Builder(builder: (context) {
          final ev = _eventId == null
              ? null
              : StoreScope.of(context).events.where((e) => e.id == _eventId).firstOrNull;
          if (ev == null) {
            // まだどの予定にも結びついていないとき: 予定を選んで関連付けられる
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await _pickEventFor(context, _due);
                    if (picked == null) return;
                    final (e, day) = picked;
                    setState(() {
                      _eventId = e.id;
                      _eventDate = e.weekly ? day : null;
                      // 期限が未設定なら、その予定の日を期限にする
                      _due ??= day;
                    });
                  },
                  icon: Icon(FluentIcons.calendar_link_24_regular, size: 18),
                  label: Text('予定に関連付ける（持ち物・準備・報告など）'),
                ),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Container(
              padding: EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(
                color: Fl.bg2,
                borderRadius: BorderRadius.circular(Fl.r4),
                border: Border.all(color: Fl.stroke2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    FlColorDot(color: StoreScope.of(context).colorOf(ev)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '関連する予定: ${ev.title}（${_eventDate != null ? fmtDate(_eventDate!) : fmtDate(ev.date)} ${ev.timeLabel}）',
                        style: FlText.caption1,
                      ),
                    ),
                    IconButton(
                      tooltip: '関連付けを外す',
                      icon: Icon(FluentIcons.dismiss_24_regular, size: 14),
                      onPressed: () => setState(() {
                        _eventId = null;
                        _eventDate = null;
                        _followEnd = false;
                      }),
                    ),
                  ]),
                  if (!ev.weekly && ev.startMin != null)
                    FlCheckRow(
                      label: '期限を予定の終了時刻に合わせる',
                      value: _followEnd,
                      onChanged: (v) => setState(() {
                        _followEnd = v;
                        if (v) {
                          _due = dateOnly(ev.date);
                          _dueMin = ev.endMin ?? ev.startMin;
                        }
                      }),
                    ),
                ],
              ),
            ),
          );
        }),
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
        if (_due != null)
          ReminderField(
            value: _reminder,
            allDay: _dueMin == null,
            onChanged: (v) => setState(() => _reminder = v),
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


/// タスクを結びつける予定を選ぶ（前後2週間の予定から）。選んだ予定とその回の日付を返す
Future<(Event, DateTime)?> _pickEventFor(BuildContext context, DateTime? near) {
  final store = StoreScope.read(context);
  final today = dateOnly(DateTime.now());
  final center = near == null ? today : dateOnly(near);
  final from = addDays(center, -7);
  final items = <(Event, DateTime)>[];
  for (var i = 0; i <= 21; i++) {
    final d = addDays(from, i);
    for (final e in store.events) {
      if (e.occursOn(d)) items.add((e, d));
    }
  }
  items.sort((a, b) {
    final c = a.$2.compareTo(b.$2);
    return c != 0 ? c : (a.$1.startMin ?? -1).compareTo(b.$1.startMin ?? -1);
  });
  return showFlDialog<(Event, DateTime)>(
    context,
    maxWidth: 440,
    child: Material(
      color: Fl.bg1,
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(children: [
                Expanded(child: Text('関連付ける予定', style: FlText.subtitle1)),
                IconButton(
                  tooltip: '閉じる',
                  icon: Icon(FluentIcons.dismiss_24_regular),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ]),
            ),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text('前後2週間に予定がありません',
                    style: FlText.body1.copyWith(color: Fl.fg3)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    for (final (e, d) in items)
                      InkWell(
                        borderRadius: BorderRadius.circular(Fl.r4),
                        onTap: () => Navigator.of(ctx).pop((e, d)),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(children: [
                            FlColorDot(color: store.colorOf(e)),
                            SizedBox(width: 10),
                            SizedBox(
                              width: 76,
                              child: Text(fmtDate(d),
                                  style: FlText.caption1.copyWith(
                                      color: d == today ? Fl.brandFg : Fl.fg2)),
                            ),
                            Expanded(
                              child: Text(e.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: FlText.body1),
                            ),
                            Text(e.timeLabel,
                                style: FlText.caption1.copyWith(color: Fl.fg3)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 繰り返しの選び方（よく使う形）
enum _RepeatPreset { none, daily, weekdays, weekly, biweekly, monthlyDate, monthlyWeekday }

_RepeatPreset _presetOf(Recurrence? r) {
  if (r == null) return _RepeatPreset.none;
  switch (r.freq) {
    case RepeatFreq.daily:
      return r.weekdays.length == 5 && !r.weekdays.contains(6) && !r.weekdays.contains(7)
          ? _RepeatPreset.weekdays
          : _RepeatPreset.daily;
    case RepeatFreq.weekly:
      return r.interval == 2 ? _RepeatPreset.biweekly : _RepeatPreset.weekly;
    case RepeatFreq.monthly:
      return r.monthlyBy == MonthlyBy.date
          ? _RepeatPreset.monthlyDate
          : _RepeatPreset.monthlyWeekday;
  }
}

/// 繰り返しの種類と曜日を選ぶ欄
class _RepeatEditor extends StatelessWidget {
  const _RepeatEditor(
      {required this.date, required this.value, required this.onChanged});

  final DateTime date;
  final Recurrence? value;
  final ValueChanged<Recurrence?> onChanged;

  String _label(_RepeatPreset p) {
    final w = weekdayNames[date.weekday - 1];
    final nth = (date.day - 1) ~/ 7 + 1;
    return switch (p) {
      _RepeatPreset.none => 'しない',
      _RepeatPreset.daily => '毎日',
      _RepeatPreset.weekdays => '平日（月〜金）',
      _RepeatPreset.weekly => '毎週',
      _RepeatPreset.biweekly => '隔週（2週ごと）',
      _RepeatPreset.monthlyDate => '毎月 ${date.day}日',
      _RepeatPreset.monthlyWeekday =>
        nth >= 5 ? '毎月 最終$w曜' : '毎月 第$nth$w曜',
    };
  }

  Recurrence? _make(_RepeatPreset p) => switch (p) {
        _RepeatPreset.none => null,
        _RepeatPreset.daily => const Recurrence(freq: RepeatFreq.daily),
        _RepeatPreset.weekdays =>
          const Recurrence(freq: RepeatFreq.daily, weekdays: {1, 2, 3, 4, 5}),
        _RepeatPreset.weekly => Recurrence(weekdays: value?.freq == RepeatFreq.weekly ? value!.weekdays : const {}),
        _RepeatPreset.biweekly => Recurrence(
            interval: 2,
            weekdays: value?.freq == RepeatFreq.weekly ? value!.weekdays : const {}),
        _RepeatPreset.monthlyDate => const Recurrence(freq: RepeatFreq.monthly),
        _RepeatPreset.monthlyWeekday =>
          const Recurrence(freq: RepeatFreq.monthly, monthlyBy: MonthlyBy.weekday),
      };

  @override
  Widget build(BuildContext context) {
    final preset = _presetOf(value);
    final r = value;
    final isWeekly = r != null && r.freq == RepeatFreq.weekly;
    final days = isWeekly ? (r.weekdays.isEmpty ? {date.weekday} : r.weekdays) : <int>{};
    final order = weekStartsOnSunday ? [7, 1, 2, 3, 4, 5, 6] : [1, 2, 3, 4, 5, 6, 7];
    return FlField(
      label: '繰り返し',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlDropdown<_RepeatPreset>(
            items: _RepeatPreset.values,
            value: preset,
            labelOf: _label,
            leadingOf: (_) => Icon(FluentIcons.arrow_repeat_all_24_regular,
                size: 16, color: Fl.fg3),
            onChanged: (p) => onChanged(_make(p)),
          ),
          if (isWeekly)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final d in order)
                    _DayChip(
                      label: weekdayNames[d - 1],
                      selected: days.contains(d),
                      onTap: () {
                        final next = {...days};
                        if (!next.remove(d)) next.add(d);
                        if (next.isEmpty) return; // 1つは残す
                        onChanged(Recurrence(
                            interval: r.interval,
                            weekdays: next.length == 1 && next.first == date.weekday
                                ? const {}
                                : next));
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 曜日の丸いトグル（Outlook の繰り返し設定と同じ見た目）
class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? Fl.brand : Colors.transparent,
          border: Border.all(color: selected ? Fl.brand : Fl.stroke1),
        ),
        child: Text(label,
            style: FlText.body1Strong
                .copyWith(color: selected ? Colors.white : Fl.fg1)),
      ),
    );
  }
}


/// 時限（1限〜）を選んで開始・終了を入れる。続けて隣の時限を押すと連続にできる
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker(
      {required this.start, required this.end, required this.onChanged});

  final int start;
  final int end;
  final void Function(int start, int end) onChanged;

  @override
  Widget build(BuildContext context) {
    final periods = StoreScope.of(context).periods;
    // 今の開始・終了に一致する時限の範囲
    final a = periods.indexWhere((p) => p.$1 == start);
    final b = periods.indexWhere((p) => p.$2 == end);
    final hasRange = a >= 0 && b >= a;
    return Padding(
      padding: EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Text('時限', style: FlText.body1Strong),
          SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < periods.length; i++)
                  _DayChip(
                    label: '${i + 1}',
                    selected: hasRange && i >= a && i <= b,
                    onTap: () {
                      // 隣の時限なら範囲を広げ、そうでなければその時限だけにする
                      if (hasRange && i == b + 1) {
                        onChanged(periods[a].$1, periods[i].$2);
                      } else if (hasRange && i == a - 1) {
                        onChanged(periods[i].$1, periods[b].$2);
                      } else {
                        onChanged(periods[i].$1, periods[i].$2);
                      }
                    },
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '時限の時刻を設定',
            icon: Icon(FluentIcons.settings_24_regular, size: 18, color: Fl.fg2),
            onPressed: () => showPeriodSettings(context),
          ),
        ],
      ),
    );
  }
}

/// 時限の時刻を設定するダイアログ
Future<void> showPeriodSettings(BuildContext context) {
  return showFlDialog<void>(context, maxWidth: 420, child: _PeriodSettings());
}

class _PeriodSettings extends StatefulWidget {
  @override
  State<_PeriodSettings> createState() => _PeriodSettingsState();
}

class _PeriodSettingsState extends State<_PeriodSettings> {
  late final List<(int, int)> _list = [...StoreScope.read(context).periods];

  Future<void> _pick(int i, bool isStart) async {
    final (s, e) = _list[i];
    final v = await showFlTimeList(context, isStart ? s : e);
    if (v == null) return;
    setState(() => _list[i] = isStart ? (v, e) : (s, v));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Fl.bg1,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('時限の時刻', style: FlText.subtitle1),
            SizedBox(height: 4),
            Text('授業の時程に合わせて変更してください。',
                style: FlText.caption1.copyWith(color: Fl.fg3)),
            SizedBox(height: 12),
            for (var i = 0; i < _list.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                        width: 40,
                        child: Text('${i + 1}限', style: FlText.body1Strong)),
                    Expanded(
                      child: FlPickerField(
                        icon: FluentIcons.clock_24_regular,
                        text: fmtMin(_list[i].$1),
                        onTap: () => _pick(i, true),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('〜'),
                    ),
                    Expanded(
                      child: FlPickerField(
                        icon: FluentIcons.clock_24_regular,
                        text: fmtMin(_list[i].$2),
                        onTap: () => _pick(i, false),
                      ),
                    ),
                    IconButton(
                      tooltip: 'この時限を削除',
                      icon: Icon(FluentIcons.dismiss_24_regular, size: 16),
                      onPressed: _list.length <= 1
                          ? null
                          : () => setState(() => _list.removeAt(i)),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () => setState(() {
                final last = _list.last;
                final s = last.$2 + 10;
                _list.add((s, s + (last.$2 - last.$1)));
              }),
              icon: Icon(FluentIcons.add_24_regular, size: 16),
              label: Text('時限を追加'),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: () {
                    if (_list.any((p) => p.$2 <= p.$1)) return;
                    StoreScope.read(context).setPeriods(_list);
                    Navigator.of(context).pop();
                  },
                  child: Text('保存'),
                ),
                SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('キャンセル'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// 通知（リマインダー）の選択
// ---------------------------------------------------------------------------

/// 予定・タスクの「通知」欄。選んだときにブラウザの通知の許可を求める
class ReminderField extends StatefulWidget {
  const ReminderField(
      {super.key,
      required this.value,
      required this.allDay,
      required this.onChanged,
      this.label = '通知',
      this.showNote = true});

  final String label;

  /// 通知の届き方の説明を下に出すか
  final bool showNote;

  final int? value;

  /// 終日（時刻なし）のとき true。選択肢が「前日 18:00」などになる
  final bool allDay;
  final ValueChanged<int?> onChanged;

  @override
  State<ReminderField> createState() => _ReminderFieldState();
}

class _ReminderFieldState extends State<ReminderField> {
  String _perm = notificationPermission();

  Future<void> _choose(int? v) async {
    widget.onChanged(v);
    if (v != null && _perm == 'default') {
      final p = await requestNotificationPermission();
      if (mounted) setState(() => _perm = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = widget.allDay ? kAllDayReminders : kTimedReminders;
    // PopupMenu は null を「閉じただけ」と区別できないので、「なし」は番兵の値で表す
    const none = 1 << 30;
    final cur = widget.value ?? none;
    final items = <int>[
      none,
      ...presets,
      if (cur != none && !presets.contains(cur)) cur,
    ];
    final note = widget.value == null || !widget.showNote
        ? null
        : switch (_perm) {
            'granted' => null,
            'denied' =>
              'ブラウザで通知がブロックされています。アプリを開いている間は画面内でお知らせします',
            'default' => 'ブラウザの通知を許可すると、別のタブを見ていても届きます',
            _ => 'アプリを開いている間に、画面内でお知らせします',
          };
    return FlField(
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlDropdown<int>(
            items: items,
            value: cur,
            labelOf: (v) => reminderLabel(v == none ? null : v, allDay: widget.allDay),
            leadingOf: (v) => Icon(
                v == none ? FluentIcons.alert_off_24_regular : FluentIcons.alert_24_regular,
                size: 16,
                color: Fl.fg2),
            onChanged: (v) => _choose(v == none ? null : v),
          ),
          if (note != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(note, style: FlText.caption1.copyWith(color: Fl.fg3)),
            ),
        ],
      ),
    );
  }
}
