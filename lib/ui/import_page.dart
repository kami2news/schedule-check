import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../parser.dart';
import '../reconcile.dart';
import '../store.dart';
import 'fluent.dart';
import 'fluent_extras.dart';
import 'widgets.dart';

/// メールや連絡文を貼り付けて、日付つきの行を予定／タスク候補として取り込む画面
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _text = TextEditingController();
  List<Candidate> _cands = [];
  final Map<Candidate, MatchResult> _matches = {};

  /// 毎週の予定への変更・中止を「この回以降」にも反映する候補
  final Set<Candidate> _following = {};
  int _skipped = 0;
  bool _parsed = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    FocusScope.of(context).unfocus();
    final r = parseText(_text.text, DateTime.now(),
        calendars: StoreScope.read(context).calendars,
        periods: StoreScope.read(context).periods);
    final store = StoreScope.read(context);
    _matches.clear();
    for (final c in r.candidates) {
      final m = reconcile(c, store.events, store.tasks);
      _matches[c] = m;
      c.selected = m.defaultSelected;
    }
    setState(() {
      _cands = r.candidates;
      _skipped = r.skipped;
      _parsed = true;
    });
  }

  /// 候補を編集したら照合し直す（結果の種類が変わったらチェックも初期値に戻す）
  void _rematch(Candidate c) {
    final store = StoreScope.read(context);
    final m = reconcile(c, store.events, store.tasks);
    final old = _matches[c];
    if (old == null || old.kind != m.kind || old.event != m.event) {
      c.selected = m.defaultSelected;
    }
    _matches[c] = m;
    setState(() {});
  }

  int get _selectedCount => _cands.where((c) => c.selected).length;

  void _register() {
    final store = StoreScope.read(context);
    final events = <Event>[];
    final tasks = <TaskItem>[];
    var updated = 0, deleted = 0;
    // 勤務と終了報告など、同じ連絡から作る予定とタスクの対応
    final groupEvent = <int, String>{};
    for (final c in _cands) {
      // 既存の予定と同じ・変更なら、その予定に結びつける
      final m = _matches[c];
      if (c.linkGroup != null && c.linkEnd && m?.event != null &&
          (m!.kind == MatchKind.duplicate || m.kind == MatchKind.update) &&
          !m.isRecurring) {
        groupEvent[c.linkGroup!] = m.event!.id;
      }
    }
    for (final c in _cands.where((c) => c.selected)) {
      final m = _matches[c] ?? MatchResult(MatchKind.fresh);
      final title = c.title.trim().isEmpty ? '(無題)' : c.title.trim();
      // リンクとして開けない値はメモに残す
      final rawUrl = c.url.trim();
      final url = normalizeUrl(rawUrl) ?? '';
      final extraNote = rawUrl.isNotEmpty && url.isEmpty ? 'リンク: $rawUrl' : '';
      final note = [c.note.trim(), extraNote].where((x) => x.isNotEmpty).join('\n');
      final place = c.place.trim();

      String merged(String old) =>
          note.isEmpty || old.contains(note) ? old : (old.isEmpty ? note : '$old\n$note');

      switch (m.kind) {
        case MatchKind.cancel:
          if (!m.canApply) break;
          final ev = m.event;
          if (ev != null && m.isRecurring) {
            _following.contains(c)
                ? store.deleteFollowing(ev, m.occurrence!)
                : store.deleteOccurrence(ev, m.occurrence!);
          } else if (ev != null) {
            store.deleteEvent(ev.id);
          }
          if (m.task != null) store.deleteTask(m.task!.id);
          deleted++;
        case MatchKind.duplicate:
        case MatchKind.update:
          if (!m.canApply) break;
          final e = m.event, t = m.task;
          if (e != null && m.kind == MatchKind.update && m.isRecurring) {
            // 毎週の予定は、その回（または以降）だけを変える
            final changed = e.copyWith(date: m.occurrence);
            if (c.startMin != null) {
              changed.startMin = c.startMin;
              changed.endMin = c.endMin ?? defaultEnd(c.startMin!);
            }
            if (changed.url.isEmpty) changed.url = url;
            if (changed.place.isEmpty) changed.place = place;
            changed.note = merged(changed.note);
            _following.contains(c)
                ? store.changeFollowing(e, m.occurrence!, changed)
                : store.changeOccurrence(e, m.occurrence!, changed);
          } else if (e != null) {
            if (m.kind == MatchKind.update) {
              if (!e.weekly) e.date = dateOnly(c.date);
              if (c.startMin != null) {
                e.startMin = c.startMin;
                e.endMin = c.endMin ?? defaultEnd(c.startMin!);
              }
            }
            if (e.url.isEmpty) e.url = url;
            if (e.place.isEmpty) e.place = place;
            e.note = merged(e.note);
            store.upsertEvent(e);
          } else if (t != null) {
            if (m.kind == MatchKind.update) {
              final (d, min) = normalizeDeadline(c.date, c.startMin);
              t.due = d;
              if (c.startMin != null) t.dueMin = min;
            }
            if (t.url.isEmpty) t.url = url;
            t.note = merged(t.note);
            store.upsertTask(t);
          }
          updated++;
        case MatchKind.fresh:
        case MatchKind.conflict:
          if (c.type == ImportType.task) {
            final linked = c.linkGroup == null ? null : groupEvent[c.linkGroup!];
            // 種類を「タスク」に変えた候補もあるので、ここでも締め切りの形にそろえる
            final (due, dueMin) = linked != null
                ? (c.date, c.startMin)
                : normalizeDeadline(c.date, c.startMin);
            tasks.add(TaskItem(
              id: store.newId(),
              title: title,
              due: due,
              dueMin: dueMin,
              eventId: linked,
              followEnd: linked != null,
              reminder: linked != null ? null : store.defaultDeadlineReminder(dueMin),
              url: url,
              // タスクには場所の欄がないのでメモにまとめる
              note: [if (place.isNotEmpty) '場所: $place', if (note.isNotEmpty) note]
                  .join('\n'),
            ));
          } else {
            final s = c.startMin;
            final newId = store.newId();
            if (c.linkGroup != null && c.linkEnd) groupEvent[c.linkGroup!] = newId;
            events.add(Event(
              id: newId,
              title: title,
              calendarId: c.calendarId,
              showAs: c.showAs,
              date: c.date,
              startMin: s,
              endMin: s == null ? null : (c.endMin ?? defaultEnd(s)),
              place: place,
              url: url,
              note: note,
              reminder: store.defaultReminder(s == null ? 'allDay' : 'timed'),
            ));
          }
      }
    }
    store.addMany(newEvents: events, newTasks: tasks);
    final added = events.length + tasks.length;
    setState(() {
      _cands = [];
      _matches.clear();
      _following.clear();
      _parsed = false;
      _text.clear();
    });
    final parts = [
      if (added > 0) '追加$added件',
      if (updated > 0) '更新$updated件',
      if (deleted > 0) '削除$deleted件',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(parts.isEmpty ? '変更はありませんでした' : '${parts.join('・')}を反映しました')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text(
          'メールやLINEの連絡文などを貼り付けると、日付が書かれた行を予定やタスクの候補として取り出します。'
          'すぐ下の行にある Zoom などのリンク・場所・ミーティングID などは、その予定のリンクやメモに入ります。'
          '登録前に内容を確認・修正できます。',
          style: FlText.body1.copyWith(color: Fl.fg2),
        ),
        SizedBox(height: 12),
        FlTextField(
          controller: _text,
          minLines: 6,
          maxLines: 10,
          hint: '例）\n11/15 10:00-18:00 シフト\n11/18 14:00-15:00 面談\nZoom: https://zoom.us/j/...\nミーティングID: 123 456 789\n\n11月20日 レポート提出 23:59',
        ),
        SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _parse,
          icon: Icon(FluentIcons.sparkle_24_regular, size: 18),
          label: Text('解析する'),
        ),
        if (_parsed) ...[
          SectionHeader('見つかった候補'),
          if (_cands.isEmpty)
            EmptyNote('日付つきの行が見つかりませんでした（例: 11/15、11月15日、2026/11/15、明日）'),
          for (final c in _cands)
            _CandidateTile(
              key: ObjectKey(c),
              c: c,
              match: _matches[c],
              following: _following.contains(c),
              onFollowingChanged: (v) => setState(() {
                v ? _following.add(c) : _following.remove(c);
              }),
              onChanged: () => _rematch(c),
            ),
          if (_skipped > 0)
            EmptyNote('日付が見つからず読み飛ばした行: $_skipped'),
          if (_cands.isNotEmpty) ...[
            SizedBox(height: 12),
            FilledButton(
              onPressed: _selectedCount == 0 ? null : _register,
              child: Text('選択した$_selectedCount件を反映'),
            ),
          ],
        ],
      ],
    );
  }
}

class _CandidateTile extends StatefulWidget {
  const _CandidateTile(
      {super.key,
      required this.c,
      required this.match,
      required this.following,
      required this.onFollowingChanged,
      required this.onChanged});

  final Candidate c;
  final MatchResult? match;
  final bool following;
  final ValueChanged<bool> onFollowingChanged;
  final VoidCallback onChanged;

  @override
  State<_CandidateTile> createState() => _CandidateTileState();
}

class _CandidateTileState extends State<_CandidateTile> {
  late final TextEditingController _title =
      TextEditingController(text: widget.c.title);
  late final TextEditingController _url =
      TextEditingController(text: widget.c.url);
  late final TextEditingController _place =
      TextEditingController(text: widget.c.place);
  late final TextEditingController _note =
      TextEditingController(text: widget.c.note);
  late bool _showDetails = widget.c.url.isNotEmpty ||
      widget.c.note.isNotEmpty ||
      widget.c.place.isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  Candidate get c => widget.c;

  /// 反映できる操作があるか（同じ予定で足す情報が無い・毎週の予定の変更などは選べない）
  bool get _selectable {
    final m = widget.match;
    if (m == null) return true;
    if (!m.canApply) return false;
    if (m.kind == MatchKind.duplicate && !m.enrich) return false;
    return true;
  }

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  Future<void> _pickDate() async {
    final v = await showDatePicker(
      context: context,
      initialDate: c.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (v != null) {
      c.date = dateOnly(v);
      _changed();
    }
  }

  Future<int?> _pickTime(int initial) {
    return showFlTimeList(context, initial, extra: [23 * 60 + 59]);
  }

  Future<void> _pickStart() async {
    final v = await _pickTime(c.startMin ?? 9 * 60);
    if (v == null) return;
    c.startMin = v;
    if (c.endMin != null && c.endMin! <= v) c.endMin = null;
    _changed();
  }

  Future<void> _pickEnd() async {
    final s = c.startMin;
    if (s == null) return;
    final v = await _pickTime(c.endMin ?? defaultEnd(s));
    if (v == null) return;
    if (v <= s) return;
    c.endMin = v;
    _changed();
  }

  Widget _detailRow(IconData icon, Widget field) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 8, right: 8),
            child: Icon(icon, size: 16, color: Fl.fg3),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTask = c.type == ImportType.task;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Fl.bg1,
        borderRadius: BorderRadius.circular(Fl.r8),
        border: Border.all(color: Fl.stroke1),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.match != null && widget.match!.kind != MatchKind.fresh)
              Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 0, 6),
                child: _MatchBanner(
                  match: widget.match!,
                  c: c,
                  following: widget.following,
                  onFollowingChanged: widget.onFollowingChanged,
                ),
              ),
            Row(
              children: [
                Checkbox(
                  value: c.selected && _selectable,
                  onChanged: _selectable
                      ? (v) {
                          c.selected = v ?? false;
                          _changed();
                        }
                      : null,
                ),
                Expanded(
                  child: FlTextField(
                    controller: _title,
                    onChanged: (v) => c.title = v,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(left: 12),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    child: Builder(builder: (context) {
                      final store = StoreScope.of(context);
                      const taskKey = '__task__';
                      return FlDropdown<String>(
                        items: [
                          for (final cal in store.calendars) cal.id,
                          taskKey,
                        ],
                        value: isTask ? taskKey : store.calendarOf(c.calendarId).id,
                        labelOf: (k) => k == taskKey
                            ? 'タスク（締切）'
                            : store.calendarOf(k).name,
                        leadingOf: (k) => k == taskKey
                            ? Icon(FluentIcons.task_list_ltr_24_regular,
                                size: 14, color: Fl.fg2)
                            : FlColorDot(color: store.calendarOf(k).color),
                        onChanged: (k) {
                          if (k == taskKey) {
                            c.type = ImportType.task;
                            c.endMin = null;
                          } else {
                            if (c.type == ImportType.task) {
                              c.type = ImportType.event;
                            }
                            c.calendarId = k;
                          }
                          _changed();
                        },
                      );
                    }),
                  ),
                  if (!isTask && c.showAs != ShowAs.busy)
                    Text(c.showAs.label,
                        style: FlText.caption1.copyWith(color: Fl.fg3)),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: Icon(FluentIcons.calendar_ltr_24_regular, size: 18),
                    label: Text(fmtDate(c.date)),
                  ),
                  TextButton.icon(
                    onPressed: _pickStart,
                    icon: Icon(FluentIcons.clock_24_regular, size: 18),
                    label: Text(c.startMin == null
                        ? (isTask ? '時刻なし' : '終日')
                        : fmtMin(c.startMin!)),
                  ),
                  if (!isTask && c.startMin != null)
                    TextButton(
                      onPressed: _pickEnd,
                      child: Text(
                          '〜 ${fmtMin(c.endMin ?? defaultEnd(c.startMin!))}'),
                    ),
                  if (c.startMin != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '時刻を消す',
                      icon: Icon(FluentIcons.dismiss_24_regular, size: 16),
                      onPressed: () {
                        c.startMin = null;
                        c.endMin = null;
                        _changed();
                      },
                    ),
                ],
              ),
            ),
            if (_showDetails)
              Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 0, 0),
                child: Column(
                  children: [
                    _detailRow(
                      FluentIcons.link_24_regular,
                      FlTextField(
                        controller: _url,
                        hint: 'リンク（Zoom・Teams など）',
                        onChanged: (v) => c.url = v,
                      ),
                    ),
                    if (!isTask)
                      _detailRow(
                        FluentIcons.location_24_regular,
                        FlTextField(
                          controller: _place,
                          hint: '場所',
                          onChanged: (v) => c.place = v,
                        ),
                      ),
                    _detailRow(
                      FluentIcons.note_24_regular,
                      FlTextField(
                        controller: _note,
                        hint: 'メモ（ミーティングID・パスコードなど）',
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (v) => c.note = v,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(left: 4),
                child: TextButton.icon(
                  onPressed: () => setState(() => _showDetails = true),
                  icon: Icon(FluentIcons.add_24_regular, size: 16),
                  label: Text('リンク・メモを追加'),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
              child: Text('元の行: ${c.source}',
                  style: FlText.caption1.copyWith(color: Fl.fg3)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 照合結果の説明（登録済み・変更・中止・重なり）
class _MatchBanner extends StatelessWidget {
  const _MatchBanner(
      {required this.match,
      required this.c,
      required this.following,
      required this.onFollowingChanged});

  final MatchResult match;
  final Candidate c;
  final bool following;
  final ValueChanged<bool> onFollowingChanged;

  @override
  Widget build(BuildContext context) {
    final e = match.event, t = match.task;
    final name = e != null ? '「${e.title}」（${describeEvent(e)}）' : (t != null ? '「${t.title}」' : '');
    final (IconData icon, Color color, String text) = switch (match.kind) {
      MatchKind.duplicate => (
          FluentIcons.checkmark_circle_16_regular,
          Fl.fg2,
          match.enrich
              ? '登録済みの$nameと同じです。チェックすると、リンク・場所・メモを既存の予定に追加します'
              : '登録済みの$nameと同じです（追加しません）'
        ),
      MatchKind.update => (
          FluentIcons.edit_16_regular,
          Fl.warning,
          match.isRecurring
              ? '毎週の予定$nameの${fmtDate(match.occurrence!)}の回を ${describeCandidateTime(c)} に変更します'
              : e != null
                  ? '既存の$nameを ${describeCandidateTime(c)} に変更します'
                  : '既存のタスク$nameの期限を ${describeCandidateTime(c)} に変更します'
        ),
      MatchKind.cancel => (
          FluentIcons.dismiss_circle_16_regular,
          Fl.danger,
          !match.hasTarget
              ? '中止の連絡のようですが、対象の予定が見つかりません'
              : match.isRecurring
                  ? '毎週の予定$nameの${fmtDate(match.occurrence!)}の回の中止（休講など）の連絡です。チェックすると、この回を削除します'
                  : '$nameの中止の連絡です。チェックすると、この予定を削除します'
        ),
      MatchKind.conflict => (
          FluentIcons.warning_16_regular,
          Fl.warning,
          '${match.conflicts.map((x) => '「${x.title}」（${x.timeLabel}）').join('、')}と時間が重なっています'
        ),
      MatchKind.fresh => (FluentIcons.add_16_regular, Fl.fg2, ''),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Fl.tint(color, Fl.isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(Fl.r4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: FlText.caption1.copyWith(color: Fl.fg1)),
                // 毎週の予定の変更・中止は、以降の回にも反映できる
                if (match.isRecurring &&
                    (match.kind == MatchKind.update ||
                        match.kind == MatchKind.cancel))
                  InkWell(
                    onTap: () => onFollowingChanged(!following),
                    child: Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FlCheckCircle(
                            checked: following,
                            onTap: () => onFollowingChanged(!following),
                          ),
                          SizedBox(width: 2),
                          Text(
                            match.kind == MatchKind.cancel
                                ? 'この回以降もすべて削除する'
                                : 'この回以降にも反映する',
                            style: FlText.caption1Strong,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
