import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../parser.dart';
import '../store.dart';
import 'fluent.dart';
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
  int _skipped = 0;
  bool _parsed = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    FocusScope.of(context).unfocus();
    final r = parseText(_text.text, DateTime.now());
    setState(() {
      _cands = r.candidates;
      _skipped = r.skipped;
      _parsed = true;
    });
  }

  int get _selectedCount => _cands.where((c) => c.selected).length;

  void _register() {
    final store = StoreScope.read(context);
    final events = <Event>[];
    final tasks = <TaskItem>[];
    for (final c in _cands.where((c) => c.selected)) {
      final title = c.title.trim().isEmpty ? '(無題)' : c.title.trim();
      if (c.type == ImportType.task) {
        tasks.add(TaskItem(
            id: store.newId(), title: title, due: c.date, dueMin: c.startMin));
      } else {
        final s = c.startMin;
        events.add(Event(
          id: store.newId(),
          title: title,
          kind: c.type.eventKind ?? EventKind.other,
          date: c.date,
          startMin: s,
          endMin: s == null ? null : (c.endMin ?? defaultEnd(s)),
        ));
      }
    }
    store.addMany(newEvents: events, newTasks: tasks);
    final n = events.length + tasks.length;
    setState(() {
      _cands = [];
      _parsed = false;
      _text.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('予定${events.length}件・タスク${tasks.length}件を登録しました（計$n件）')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text(
          'メールやLINEの連絡文などを貼り付けると、日付が書かれた行を予定やタスクの候補として取り出します。'
          '登録前に内容を確認・修正できます。',
          style: FlText.body1.copyWith(color: Fl.fg2),
        ),
        const SizedBox(height: 12),
        FlTextField(
          controller: _text,
          minLines: 6,
          maxLines: 10,
          hint: '例）\n11/15 10:00-18:00 シフト\n11月20日 レポート提出 23:59',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _parse,
          icon: const Icon(FluentIcons.sparkle_24_regular, size: 18),
          label: const Text('解析する'),
        ),
        if (_parsed) ...[
          const SectionHeader('見つかった候補'),
          if (_cands.isEmpty)
            const EmptyNote('日付つきの行が見つかりませんでした（例: 11/15、11月15日、2026/11/15、明日）'),
          for (final c in _cands)
            _CandidateTile(
              key: ObjectKey(c),
              c: c,
              onChanged: () => setState(() {}),
            ),
          if (_skipped > 0)
            EmptyNote('日付が見つからず読み飛ばした行: $_skipped'),
          if (_cands.isNotEmpty) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selectedCount == 0 ? null : _register,
              child: Text('選択した$_selectedCount件を登録'),
            ),
          ],
        ],
      ],
    );
  }
}

class _CandidateTile extends StatefulWidget {
  const _CandidateTile({super.key, required this.c, required this.onChanged});

  final Candidate c;
  final VoidCallback onChanged;

  @override
  State<_CandidateTile> createState() => _CandidateTileState();
}

class _CandidateTileState extends State<_CandidateTile> {
  late final TextEditingController _title =
      TextEditingController(text: widget.c.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Candidate get c => widget.c;

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

  Future<int?> _pickTime(int initial) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
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

  @override
  Widget build(BuildContext context) {
    final isTask = c.type == ImportType.task;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Fl.bg1,
        borderRadius: BorderRadius.circular(Fl.r8),
        border: Border.all(color: Fl.stroke1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: c.selected,
                  onChanged: (v) {
                    c.selected = v ?? false;
                    _changed();
                  },
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
              padding: const EdgeInsets.only(left: 12),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<ImportType>(
                    value: c.type,
                    underline: const SizedBox.shrink(),
                    style: FlText.body1,
                    borderRadius: BorderRadius.circular(Fl.r4),
                    items: [
                      for (final t in ImportType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      c.type = v;
                      if (v == ImportType.task) c.endMin = null;
                      _changed();
                    },
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(FluentIcons.calendar_ltr_24_regular, size: 18),
                    label: Text(fmtDate(c.date)),
                  ),
                  TextButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(FluentIcons.clock_24_regular, size: 18),
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
                      icon: const Icon(FluentIcons.dismiss_24_regular, size: 16),
                      onPressed: () {
                        c.startMin = null;
                        c.endMin = null;
                        _changed();
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text('元の行: ${c.source}',
                  style: FlText.caption1.copyWith(color: Fl.fg3)),
            ),
          ],
        ),
      ),
    );
  }
}
