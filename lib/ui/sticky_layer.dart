import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../compare.dart';
import '../models.dart';
import '../parser.dart';
import '../sticky.dart';
import '../store.dart';
import 'edit_pages.dart' show showFlDialogOrPage;
import 'fluent.dart';
import 'fluent_extras.dart';

/// 付箋の地の色（黄色。テーマに合わせて淡くする）
const _stickyColor = Color(0xFFEAA300);

/// 付箋の幅
double stickyWidth(double areaWidth) => math.min(300, areaWidth - 16);

/// カレンダーの上に重ねる付箋の層（カレンダーの操作は付箋の外ならそのまま効く）
class StickyLayer extends StatelessWidget {
  const StickyLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.stickies.isEmpty) return SizedBox.shrink();
    return LayoutBuilder(builder: (context, cs) {
      return Stack(
        children: [
          for (final n in store.stickies)
            _PlacedSticky(key: ValueKey(n.id), note: n, area: cs.biggest),
        ],
      );
    });
  }
}

class _PlacedSticky extends StatefulWidget {
  const _PlacedSticky({super.key, required this.note, required this.area});
  final StickyNote note;
  final Size area;

  @override
  State<_PlacedSticky> createState() => _PlacedStickyState();
}

class _PlacedStickyState extends State<_PlacedSticky> {
  Offset? _drag; // ドラッグ中の左上

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final w = stickyWidth(widget.area.width);
    final maxLeft = math.max(0.0, widget.area.width - w - 8);
    final maxTop = math.max(0.0, widget.area.height - 48);
    final pos = _drag ?? Offset(8 + n.x * maxLeft, 8 + n.y * maxTop);
    return Positioned(
      left: pos.dx.clamp(0, maxLeft + 8),
      top: pos.dy.clamp(0, maxTop + 8),
      width: w,
      child: StickyCard(
        note: n,
        maxBodyHeight: math.max(120, widget.area.height * 0.5),
        onDragUpdate: (d) => setState(() => _drag = pos + d),
        onDragEnd: () {
          final p = _drag;
          if (p == null) return;
          n.x = maxLeft == 0 ? 0 : ((p.dx - 8) / maxLeft).clamp(0.0, 1.0);
          n.y = maxTop == 0 ? 0 : ((p.dy - 8) / maxTop).clamp(0.0, 1.0);
          setState(() => _drag = null);
          StoreScope.read(context).updateSticky(n);
        },
      ),
    );
  }
}

/// 付箋 1 枚: 見出し（ここをドラッグして動かす）・たたむ・編集・カレンダーに重ねる・はがす。
/// 本文はメモのまま。その下に、メモから読み取れた日時と自分の予定との重なりを出す
class StickyCard extends StatelessWidget {
  const StickyCard({
    super.key,
    required this.note,
    this.maxBodyHeight = 280,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final StickyNote note;
  final double maxBodyHeight;
  final void Function(Offset delta)? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = _readItems(store, note.text);
    final rows = compareWith(items, store.eventsOn);
    final n = rows.where((r) => r.conflicts).length;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Fl.tint(_stickyColor, Fl.isDark ? 0.28 : 0.22),
          borderRadius: BorderRadius.circular(Fl.r8),
          border: Border.all(color: Fl.stroke2),
          boxShadow: Fl.shadow8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 見出し（ドラッグで移動）
            MouseRegion(
              cursor: SystemMouseCursors.move,
              child: GestureDetector(
                onPanUpdate: onDragUpdate == null ? null : (d) => onDragUpdate!(d.delta),
                onPanEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 2, 2, 2),
                  child: Row(
                    children: [
                      FlIcon(FluentIcons.note_16_regular, size: 16, color: Fl.fg2),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note.heading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FlText.body1Strong,
                        ),
                      ),
                      if (rows.isNotEmpty && note.collapsed)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(n == 0 ? '重なりなし' : '重なり$n',
                              style: FlText.caption1
                                  .copyWith(color: n == 0 ? Fl.success : Fl.danger)),
                        ),
                      _btn(
                        note.collapsed ? '開く' : 'たたむ',
                        note.collapsed
                            ? FluentIcons.chevron_down_24_regular
                            : FluentIcons.chevron_up_24_regular,
                        () {
                          note.collapsed = !note.collapsed;
                          store.updateSticky(note);
                        },
                      ),
                      _btn('付箋をはがす', FluentIcons.dismiss_24_regular, () {
                        final messenger = ScaffoldMessenger.of(context);
                        final keep = StickyNote.fromJson(note.toJson());
                        store.removeSticky(note.id);
                        messenger.showSnackBar(SnackBar(
                          content: Text('付箋をはがしました'),
                          action: SnackBarAction(
                              label: '元に戻す',
                              onPressed: () {
                                store.stickies.add(keep);
                                store.updateSticky(keep);
                              }),
                        ));
                      }),
                    ],
                  ),
                ),
              ),
            ),
            if (!note.collapsed) ...[
              Divider(height: 1, color: Fl.stroke2),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(note.text, style: FlText.body1),
                      if (rows.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('自分の予定と比べると', style: FlText.caption1Strong),
                        SizedBox(height: 2),
                        for (final r in rows) _CompareLine(row: r),
                      ],
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: Fl.stroke2),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _edit(context, note),
                      icon: FlIcon(FluentIcons.edit_16_regular, size: 16),
                      label: Text('編集'),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => store.setCompare(note.heading, items),
                        icon: FlIcon(FluentIcons.calendar_ltr_16_regular, size: 16),
                        label: Text('カレンダーに重ねる'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _btn(String tip, IconData icon, VoidCallback onTap) => IconButton(
        tooltip: tip,
        icon: FlIcon(icon, size: 16, color: Fl.fg2),
        onPressed: onTap,
      );
}

/// メモから読み取れた日時（予定として比べるもの。締め切りは除く）
List<Event> _readItems(AppStore store, String text) {
  final r = parseText(text, DateTime.now(), calendars: store.calendars, periods: store.periods);
  return [
    for (final c in r.candidates)
      if (c.type != ImportType.task && c.warning == null)
        Event(
          id: '',
          title: c.title.trim().isEmpty ? '(無題)' : c.title.trim(),
          calendarId: '',
          date: c.date,
          startMin: c.startMin,
          endMin: c.startMin == null ? null : c.endMin,
          endOffset: c.endOffset,
          place: c.place.trim(),
        ),
  ];
}

class _CompareLine extends StatelessWidget {
  const _CompareLine({required this.row});
  final CompareRow row;

  @override
  Widget build(BuildContext context) {
    final e = row.item;
    final ok = !row.conflicts;
    return Padding(
      padding: EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: FlIcon(
                ok ? FluentIcons.checkmark_circle_16_filled : FluentIcons.warning_16_regular,
                size: 14,
                color: ok ? Fl.success : Fl.danger),
          ),
          SizedBox(width: 4),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${fmtDate(row.day)} ${e.timeLabel} ${e.title}　'),
                TextSpan(
                  text: ok
                      ? '空いている'
                      : '重なる: ${row.mine.map((m) => '${m.title}（${m.timeLabel}）').join('、')}',
                  style: TextStyle(color: ok ? Fl.success : Fl.danger),
                ),
              ]),
              style: FlText.caption1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 付箋の文章を書き直す（空にするとはがす）
Future<void> _edit(BuildContext context, StickyNote note) {
  return showFlDialogOrPage(
    context,
    title: '付箋を編集',
    builder: (_) => _StickyEditor(note: note),
  );
}

/// 新しい付箋を貼る（予定のメモを書く・貼り付ける）
Future<void> openNewSticky(BuildContext context) {
  return showFlDialogOrPage(
    context,
    title: '付箋を貼る',
    builder: (_) => _StickyEditor(),
  );
}

class _StickyEditor extends StatefulWidget {
  const _StickyEditor({this.note});
  final StickyNote? note;

  @override
  State<_StickyEditor> createState() => _StickyEditorState();
}

class _StickyEditorState extends State<_StickyEditor> {
  late final _text = TextEditingController(text: widget.note?.text ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final store = StoreScope.read(context);
    final t = _text.text.trim();
    final n = widget.note;
    if (n == null) {
      if (t.isNotEmpty) store.addSticky(t);
    } else if (t.isEmpty) {
      store.removeSticky(n.id);
    } else {
      n.text = t;
      store.updateSticky(n);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('ほかの人の予定・連絡のメモなどを貼っておけます。日時が書いてあれば、自分の予定と重なるかを付箋の中に出します。保存はこの端末だけです。',
            style: FlText.caption1.copyWith(color: Fl.fg2)),
        SizedBox(height: 8),
        FlTextField(
          key: ValueKey('sticky-text'),
          controller: _text,
          hint: '例: 佐藤さん\n12/5(土) 18:00〜 飲み会\n12/6(日) 10:00-15:00 バイト',
          maxLines: 10,
          minLines: 6,
        ),
        SizedBox(height: 16),
        FlActions(
          primary: FilledButton(onPressed: _save, child: Text(widget.note == null ? '貼る' : '保存')),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
