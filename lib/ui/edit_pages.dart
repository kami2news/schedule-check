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
                      icon: FlIcon(FluentIcons.dismiss_24_regular),
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

Future<int?> _pickTime(BuildContext context, int initialMin,
    {String Function(int)? note, String? title}) {
  return showFlTimeList(context, initialMin,
      extra: [23 * 60 + 59], note: note, title: title);
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
            leading: FlIcon(
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

  /// 回ごとに自動で作る ToDo のひな形（繰り返しのときだけ）
  late List<ClassTodo> _todos;
  DateTime? _until;
  int? _reminder;
  String? _error;

  /// 時限のボタンで選んだ時限（0 始まり。飛び飛びでもよい）。時刻を手で直すと null に戻る
  Set<int>? _periodSel;

  /// 今の開始・終了にちょうど合う時限の範囲（なければ空）
  Set<int> _rangeSel() {
    final r = periodRangeOf(StoreScope.read(context).periods, _start, _end, _endOffset);
    return r == null ? {} : {for (var i = r.$1; i <= r.$2; i++) i};
  }

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
    _todos = [for (final t in e?.todos ?? const <ClassTodo>[]) ClassTodo.fromJson(t.toJson())];
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
    final v = await _pickTime(context, _start, title: '開始時刻');
    if (v == null) return;
    setState(() {
      _periodSel = null;
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
    // 各時刻に開始からの所要時間を添える（開始以前の時刻は翌日に終わる扱い）
    final v = await _pickTime(context, _end, title: '終了時刻',
        note: (m) => durationNote(_start, m, endOffset: _endOffset));
    if (v == null) return;
    setState(() {
      _periodSel = null;
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

  List<CalendarDef> _calendarChoices(AppStore store) {
    final e = widget.event;
    final owner = e == null ? null : store.sourceOf(e)?.owner;
    if (owner != null) return store.shared[owner]!.wrappedCalendars;
    if (e != null) return store.calendars;
    return [
      ...store.calendars,
      for (final s in store.shared.values)
        if (s.canEdit) ...s.wrappedCalendars,
    ];
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final store = StoreScope.read(context);
    final e = widget.event;
    // 選んだ時限が飛び飛び・昼休みなどをはさむなら、まとまりごとに別の予定にする（1 つ目をこの予定に）
    var (st, en, off) = (_start, _end, _endOffset);
    final extra = <(int, int, int, int)>[]; // (日数, 開始, 終了, 終了の日数)
    final sel = _allDay ? const <int>{} : (_periodSel ?? _rangeSel());
    if (sel.isNotEmpty) {
      final blocks = periodSelectionBlocks(store.periods, sel);
      final f0 = blocks.isEmpty ? null : periodToEvent(blocks.first.$1, blocks.first.$2);
      // 時刻の欄を手で直したあとなら、選んだ時限は使わない
      // 時限のボタンで選んだときは、時刻の欄が 1 つ目のまとまりと合っているか確かめる
      final ok = _periodSel == null || (f0 != null && f0.start == _start && f0.end == _end);
      if (blocks.length > 1 && ok) {
        final shift = blocks.first.$1 - blocks.first.$1 % (24 * 60);
        final f = periodToEvent(blocks.first.$1, blocks.first.$2);
        (st, en, off) = (f.start, f.end, f.endOffset);
        for (final (bs, be) in blocks.skip(1)) {
          final t = periodToEvent(bs, be);
          extra.add(((bs - shift) ~/ (24 * 60), t.start, t.end, t.endOffset));
        }
      }
    }
    final edited = Event(
      id: e?.id ?? store.newId(),
      title: _title.text.trim(),
      calendarId: store.calendarOf(_cal).id,
      showAs: _showAs,
      date: _date,
      startMin: _allDay ? null : st,
      endMin: _allDay ? null : en,
      endOffset: off,
      repeat: _repeat,
      repeatUntil: _repeat != null ? _until : null,
      place: _place.text.trim(),
      note: _note.text.trim(),
      url: _checkedUrl(_url) ?? '',
      exdates: e == null ? null : {...e.exdates},
      seriesId: e?.seriesId,
      originalDate: e?.originalDate,
      reminder: _reminder,
      todos: _repeat == null ? [] : _todos,
    );

    // 休みの後ろのまとまりを足すときの基準の日と繰り返し
    var extraDate = edited.date;
    var extraRepeat = edited.repeat;
    if (_isOccurrence) {
      final scope = await _askScope(context, delete: false);
      if (scope == null || !mounted) return;
      final occ = dateOnly(widget.occurrence!);
      switch (scope) {
        case RecurScope.one:
          store.changeOccurrence(e!, occ, edited);
          // この回だけ: 後ろの分も、この日だけの予定
          extraRepeat = null;
        case RecurScope.following:
          store.changeFollowing(e!, occ, edited);
        case RecurScope.all:
          // この回で日付を動かした分だけ、最初の回もずらす
          final shift = dateOnly(_date).difference(occ).inDays;
          final all = edited.weekly
              ? edited.copyWith(date: e!.firstDate.add(Duration(days: shift)))
              : edited;
          store.upsertEvent(all);
          extraDate = all.date;
      }
    } else {
      store.upsertEvent(edited);
    }
    // 休みの後ろのまとまりは新しい予定として足す（繰り返しは、変えた範囲と同じ）
    for (final (days, s2, e2, o2) in extra) {
      store.upsertEvent(Event(
        id: store.newId(),
        title: edited.title,
        calendarId: edited.calendarId,
        showAs: edited.showAs,
        date: addDays(extraDate, days),
        startMin: s2,
        endMin: e2,
        endOffset: o2,
        repeat: extraRepeat,
        repeatUntil: extraRepeat != null ? edited.repeatUntil : null,
        place: edited.place,
        note: edited.note,
        url: edited.url,
        reminder: edited.reminder,
      ));
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
              FlIcon(FluentIcons.arrow_repeat_all_24_regular,
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
                    // 共有されている相手の予定は相手のカレンダーの中だけで、自分の予定は自分のカレンダーの
                    // 中だけで移せる。新しい予定は「編集可」で共有されている相手のカレンダーにも作れる
                    items: _calendarChoices(store),
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
            selected: _periodSel ?? _rangeSel(),
            onChanged: (sel) => setState(() {
              _periodSel = sel;
              final blocks = periodSelectionBlocks(StoreScope.read(context).periods, sel);
              if (blocks.isNotEmpty) {
                // 時刻の欄は 1 つ目のまとまり（日をまたぐ時限は終了日を翌日に）
                final t = periodToEvent(blocks.first.$1, blocks.first.$2);
                _start = t.start;
                _end = t.end;
                _endOffset = t.endOffset;
              }
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
        if (_repeat != null && !_isOccurrence)
          _ClassTodoEditor(
            todos: _todos,
            newId: () => StoreScope.read(context).newId(),
            onChanged: () => setState(() {}),
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
            leading: FlIcon(FluentIcons.location_24_regular,
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
                  icon: FlIcon(FluentIcons.calendar_link_24_regular, size: 18),
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
                      icon: FlIcon(FluentIcons.dismiss_24_regular, size: 14),
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
              final picked =
                  await _pickTime(context, _dueMin ?? 23 * 60 + 59, title: '期限の時刻');
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
                  icon: FlIcon(FluentIcons.dismiss_24_regular),
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
            leadingOf: (_) => FlIcon(FluentIcons.arrow_repeat_all_24_regular,
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
        // KM1 のチップ: PC 32px、タッチ 44px
        width: Fl.touch ? 44 : 32,
        height: Fl.touch ? 44 : 32,
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


/// 時限（1限〜）を押して選ぶ（押すたびに選ぶ・外すが切り替わる。飛び飛びでもよい）。
/// 続いている範囲・昼休みなどの休みごとに別の予定になる
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final periods = StoreScope.of(context).periods;
    final blocks = periodSelectionBlocks(periods, selected);
    final row = Padding(
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
                    selected: selected.contains(i),
                    onTap: () => onChanged(selected.contains(i)
                        ? ({...selected}..remove(i))
                        : {...selected, i}),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '時限の時刻を設定',
            icon: FlIcon(FluentIcons.settings_24_regular, size: 18, color: Fl.fg2),
            onPressed: () => showPeriodSettings(context),
          ),
        ],
      ),
    );
    if (blocks.length < 2) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(_splitNote(periods, selected, blocks, '保存すると'),
              style: FlText.caption1.copyWith(color: Fl.fg2)),
        ),
      ],
    );
  }
}

/// 「1〜4限・6〜8限（9:00〜12:10・13:00〜16:10）。保存すると2つの予定に分けます（昼休み… をはさむ分も分けます）」
String _splitNote(
    List<(int, int)> periods, Set<int> selected, List<(int, int)> blocks, String when) {
  final times = blocks.map((b) => '${fmtPeriodMin(b.$1)}〜${fmtPeriodMin(b.$2)}').join('・');
  return '${periodSelectionLabel(selected)}（$times）。$whenそれぞれ別の予定にします（${blocks.length}つ）';
}

/// 時限を選ぶダイアログ（取り込み画面用）。押すたびに選ぶ・外すが切り替わる（飛び飛びでもよい）。
/// 返り値は選んだ時限（0 始まり）
Future<Set<int>?> showPeriodRangePicker(BuildContext context, {Set<int>? initial}) {
  return showFlDialog<Set<int>>(context,
      maxWidth: 480, child: _PeriodRangePicker(initial: initial));
}

class _PeriodRangePicker extends StatefulWidget {
  const _PeriodRangePicker({this.initial});
  final Set<int>? initial;

  @override
  State<_PeriodRangePicker> createState() => _PeriodRangePickerState();
}

class _PeriodRangePickerState extends State<_PeriodRangePicker> {
  late Set<int> _sel = {...?widget.initial};

  @override
  Widget build(BuildContext context) {
    final periods = StoreScope.of(context).periods;
    final sel = _sel.where((i) => i < periods.length).toSet();
    final blocks = periodSelectionBlocks(periods, sel);
    return Material(
      color: Fl.bg1,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('時限で選ぶ', style: FlText.subtitle1)),
              IconButton(
                tooltip: '時限の時刻を設定',
                icon: FlIcon(FluentIcons.settings_24_regular, size: 18, color: Fl.fg2),
                onPressed: () => showPeriodSettings(context),
              ),
            ]),
            SizedBox(height: 4),
            Text('出る時限を押して選びます（もう一度押すと外れます）。飛び飛びでも選べます',
                style: FlText.caption1.copyWith(color: Fl.fg2)),
            SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < periods.length; i++)
                  _DayChip(
                    label: '${i + 1}',
                    selected: sel.contains(i),
                    onTap: () => setState(() =>
                        _sel = sel.contains(i) ? ({...sel}..remove(i)) : {...sel, i}),
                  ),
              ],
            ),
            SizedBox(height: 12),
            if (blocks.isNotEmpty) ...[
              Text(
                  '${periodSelectionLabel(sel)}　'
                  '${blocks.map((b) => '${fmtPeriodMin(b.$1)}〜${fmtPeriodMin(b.$2)}').join('・')}',
                  style: FlText.body1Strong),
              if (blocks.length > 1)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('時限の空き・昼休みなどの休みで区切って、${blocks.length}つの予定にします',
                      style: FlText.caption1.copyWith(color: Fl.fg2)),
                ),
            ],
            SizedBox(height: 20),
            FlActions(
              primary: FilledButton(
                onPressed: blocks.isEmpty ? null : () => Navigator.of(context).pop(sel),
                child: Text('決定'),
              ),
              onCancel: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 時限の時刻を設定するダイアログ
Future<void> showPeriodSettings(BuildContext context) {
  // 時限が多くても一覧で見られるよう、広く・高めに（中はスクロール）
  return showFlDialog<void>(context,
      maxWidth: 560, maxHeight: 720, child: _PeriodSettings());
}

class _PeriodSettings extends StatefulWidget {
  @override
  State<_PeriodSettings> createState() => _PeriodSettingsState();
}

class _PeriodSettingsState extends State<_PeriodSettings> {
  late final List<(int, int)> _list = [...StoreScope.read(context).periods];

  /// 時刻を選ぶ。時限は通しの分（24:00 を超えると翌日）で持ち、選んだ時刻が
  /// - 開始: 前の時限の開始より前なら翌日（23:00 の次の 0:10 は翌0:10）
  /// - 終了: 開始以前なら翌日（23:30〜0:20 は翌0:20 に終わる）
  /// とみなす
  Future<void> _pick(int i, bool isStart) async {
    final (s, e) = _list[i];
    final prevStart = i > 0 ? _list[i - 1].$1 : 0;
    final v = await showFlTimeColumns(context, (isStart ? s : e) % (24 * 60),
        title: '${i + 1}限の${isStart ? '開始' : '終了'}',
        note: isStart
            ? (m) => periodAfter(m, prevStart) >= 24 * 60 ? '（翌日）' : ''
            // 終了を選ぶときは授業の長さを添える（開始以前の時刻は翌日に終わる）
            : (m) => durationNote(s % (24 * 60), m));
    if (v == null) return;
    setState(() {
      if (isStart) {
        final ns = periodAfter(v, prevStart);
        // 終了は時刻をそのままに、新しい開始より後にそろえる
        _list[i] = (ns, periodAfter(e, ns + 1));
      } else {
        _list[i] = (s, periodAfter(v, s + 1));
      }
    });
  }

  /// 保存できない理由（なければ null）
  String? get _error {
    for (var i = 0; i < _list.length; i++) {
      final (s, e) = _list[i];
      if (e <= s) return '${i + 1}限の終了が開始より前か同じです';
      if (e - s >= 24 * 60) return '${i + 1}限が24時間以上になっています';
      if (i > 0 && s < _list[i - 1].$2) {
        return '${i + 1}限の開始が$i限の終了（${fmtPeriodMin(_list[i - 1].$2)}）より前です';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
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
            Text('授業の時程に合わせて変更してください（5分刻み）。'
                '開始より前の終了時刻は翌日（日をまたぐ時限）、前の時限より前の開始時刻も翌日になります。',
                style: FlText.caption1.copyWith(color: Fl.fg3)),
            SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        text: fmtPeriodMin(_list[i].$1),
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
                        text: fmtPeriodMin(_list[i].$2),
                        onTap: () => _pick(i, false),
                      ),
                    ),
                    // 授業の長さ（50分 など）。スマホの幅では省く
                    if (MediaQuery.sizeOf(context).width >= 480)
                    SizedBox(
                      width: 44,
                      child: Text(
                        _list[i].$2 > _list[i].$1
                            ? '${_list[i].$2 - _list[i].$1}分'
                            : '',
                        textAlign: TextAlign.right,
                        style: FlText.caption1.copyWith(color: Fl.fg3),
                      ),
                    ),
                    IconButton(
                      tooltip: 'この時限を削除',
                      icon: FlIcon(FluentIcons.dismiss_24_regular, size: 16),
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
                if (s >= 2 * 24 * 60 - 60) return; // 翌日の終わりまで
                _list.add((s, s + (last.$2 - last.$1)));
              }),
              icon: FlIcon(FluentIcons.add_24_regular, size: 16),
              label: Text('時限を追加'),
            ),
                  ],
                ),
              ),
            ),
            if (error != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  FlIcon(FluentIcons.error_circle_16_filled, size: 16, color: Fl.danger),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(error,
                        style: FlText.caption1.copyWith(color: Fl.danger)),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            FlActions(
              primary: FilledButton(
                onPressed: () {
                  if (_error != null) return;
                  StoreScope.read(context).setPeriods(_list);
                  Navigator.of(context).pop();
                },
                child: Text('保存'),
              ),
              onCancel: () => Navigator.of(context).pop(),
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
            leadingOf: (v) => FlIcon(
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

/// 回ごとの ToDo（授業の回ごとに自動で ToDo に入れるもののひな形）
class _ClassTodoEditor extends StatefulWidget {
  const _ClassTodoEditor({required this.todos, required this.newId, required this.onChanged});

  final List<ClassTodo> todos;
  final String Function() newId;
  final VoidCallback onChanged;

  @override
  State<_ClassTodoEditor> createState() => _ClassTodoEditorState();
}

class _ClassTodoEditorState extends State<_ClassTodoEditor> {
  final _title = TextEditingController();
  ClassTodoDue _due = ClassTodoDue.day;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _add() {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    widget.todos.add(ClassTodo(id: widget.newId(), title: t, due: _due));
    _title.clear();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12),
      child: FlField(
        label: '回ごとの ToDo（任意）',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('予習・課題・持ち物など。繰り返しの回ごとに ToDo へ自動で入ります（終了日まで。終了日がなければ8週間先の回まで）',
                style: FlText.caption1.copyWith(color: Fl.fg3)),
            SizedBox(height: 6),
            for (final t in widget.todos)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    FlIcon(FluentIcons.task_list_ltr_24_regular, size: 16, color: Fl.fg2),
                    SizedBox(width: 8),
                    Expanded(child: Text(t.title, style: FlText.body1)),
                    SizedBox(
                      width: 150,
                      child: FlDropdown<ClassTodoDue>(
                        items: ClassTodoDue.values,
                        value: t.due,
                        labelOf: (v) => v.label,
                        onChanged: (v) {
                          t.due = v;
                          widget.onChanged();
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: '「${t.title}」をやめる',
                      icon: FlIcon(FluentIcons.dismiss_24_regular, size: 16),
                      onPressed: () {
                        widget.todos.remove(t);
                        widget.onChanged();
                      },
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: FlTextField(
                    key: ValueKey('class-todo'),
                    controller: _title,
                    hint: '例: 予習、レポート提出',
                    onSubmitted: (_) => _add(),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: FlDropdown<ClassTodoDue>(
                    items: ClassTodoDue.values,
                    value: _due,
                    labelOf: (v) => v.label,
                    onChanged: (v) => setState(() => _due = v),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton(onPressed: _add, child: Text('追加')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
