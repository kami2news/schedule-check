import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'finder_pages.dart';
import 'fluent_extras.dart';
import 'mini_month.dart';
import 'settings_page.dart';

/// 広い画面の左サイドバー（新しい予定・ミニカレンダー・マイカレンダー）。
/// Outlook と同じく、パネルではなくキャンバス上にそのまま置く。
class CalendarSidebar extends StatelessWidget {
  const CalendarSidebar(
      {super.key, required this.controller, required this.onImport});

  final CalendarController controller;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: () =>
                    openEventEditor(context, date: controller.selected),
                icon: Icon(FluentIcons.calendar_add_24_regular, size: 18),
                label: Text('新しい予定'),
              ),
            ),
            SizedBox(height: 12),
            MiniMonth(controller: controller),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            CalendarList(controller: controller),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            _SideAction(
              icon: FluentIcons.clipboard_paste_24_regular,
              label: 'メールなどから取り込む',
              onTap: onImport,
            ),
            _SideAction(
              icon: FluentIcons.calendar_search_20_regular,
              label: '空き時間の候補をコピー',
              onTap: () => openFreeTime(context),
            ),
            _SideAction(
              icon: FluentIcons.settings_24_regular,
              label: '設定',
              onTap: () => openSettings(context),
            ),
          ],
        );
      },
    );
  }
}

/// 「マイカレンダー」の一覧。丸をタップで表示／非表示、… から編集・削除
class CalendarList extends StatelessWidget {
  const CalendarList({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                    child: Text('マイカレンダー', style: FlText.body1Strong)),
                IconButton(
                  tooltip: 'カレンダーを追加',
                  icon: Icon(FluentIcons.add_24_regular, size: 18),
                  onPressed: () => showCalendarEditor(context),
                ),
              ],
            ),
          ),
          for (final c in store.calendars)
            _CalendarRow(
              cal: c,
              visible: !controller.hidden.contains(c.id),
              onToggle: () => controller.toggleCalendar(c.id),
            ),
          _CalendarRowBase(
            dot: FlColorDot(
                color: Fl.fg3, filled: controller.showTasks, size: 14),
            label: 'タスクの期限',
            onTap: () => controller.setShowTasks(!controller.showTasks),
          ),
        ],
      ),
    );
  }
}

class _CalendarRowBase extends StatelessWidget {
  const _CalendarRowBase(
      {required this.dot, required this.label, required this.onTap, this.trailing});

  final Widget dot;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 36,
        child: Padding(
          padding: EdgeInsets.only(left: 20, right: 8),
          child: Row(
            children: [
              dot,
              SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis, style: FlText.body1),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow(
      {required this.cal, required this.visible, required this.onToggle});

  final CalendarDef cal;
  final bool visible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _CalendarRowBase(
      dot: FlColorDot(color: cal.color, filled: visible, size: 14),
      label: cal.name,
      onTap: onToggle,
      trailing: PopupMenuButton<String>(
        tooltip: 'その他のオプション',
        position: PopupMenuPosition.under,
        icon: Icon(FluentIcons.more_horizontal_24_regular,
            size: 16, color: Fl.fg3),
        onSelected: (v) {
          if (v == 'edit') showCalendarEditor(context, cal: cal);
          if (v == 'delete') _confirmDeleteCalendar(context, cal);
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'edit',
            height: 36,
            child: Row(children: [
              Icon(FluentIcons.edit_24_regular, size: 16),
              SizedBox(width: 10),
              Text('名前と色を変更'),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            height: 36,
            child: Row(children: [
              Icon(FluentIcons.delete_24_regular, size: 16, color: Fl.danger),
              SizedBox(width: 10),
              Text('削除', style: FlText.body1.copyWith(color: Fl.danger)),
            ]),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteCalendar(BuildContext context, CalendarDef cal) async {
  final store = StoreScope.read(context);
  if (store.calendars.length <= 1) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('カレンダーは1つ以上必要です')));
    return;
  }
  final moveTo = store.calendars.firstWhere((c) => c.id != cal.id);
  final n = store.events.where((e) => e.calendarId == cal.id).length;
  final ok = await showFlConfirm(
    context,
    title: '「${cal.name}」を削除しますか？',
    message: n == 0
        ? 'このカレンダーには予定がありません。'
        : 'このカレンダーの予定$n件は「${moveTo.name}」に移ります。',
    confirmLabel: '削除',
  );
  if (ok) store.deleteCalendar(cal.id, moveTo: moveTo.id);
}

/// カレンダーの追加（[cal] が null）または名前・色の変更
Future<void> showCalendarEditor(BuildContext context, {CalendarDef? cal}) {
  return showFlDialog<void>(
    context,
    maxWidth: 420,
    child: _CalendarEditor(cal: cal),
  );
}

class _CalendarEditor extends StatefulWidget {
  const _CalendarEditor({this.cal});

  final CalendarDef? cal;

  @override
  State<_CalendarEditor> createState() => _CalendarEditorState();
}

class _CalendarEditorState extends State<_CalendarEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.cal?.name ?? '');
  late int _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    _color = widget.cal?.colorValue ?? _unusedColor();
  }

  /// まだ使われていない色を初期値にする
  int _unusedColor() {
    final store = StoreScope.read(context);
    final used = store.calendars.map((c) => c.colorValue).toSet();
    return kCalendarColors.firstWhere((c) => !used.contains(c),
        orElse: () => kCalendarColors.first);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '名前を入力してください');
      return;
    }
    final store = StoreScope.read(context);
    if (widget.cal == null) {
      store.addCalendar(name, _color);
    } else {
      store.updateCalendar(widget.cal!.id, name: name, color: _color);
    }
    Navigator.of(context).pop();
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
            Text(widget.cal == null ? '新しいカレンダー' : 'カレンダーを編集',
                style: FlText.subtitle1),
            SizedBox(height: 16),
            FlField(
              label: '名前',
              child: FlTextField(
                controller: _name,
                autofocus: widget.cal == null,
                hint: '例: 部活、病院、試験',
                onSubmitted: (_) => _save(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: FlText.caption1.copyWith(color: Fl.danger)),
              ),
            Text('色', style: FlText.body1Strong),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kCalendarColors)
                  InkWell(
                    customBorder: CircleBorder(),
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(c),
                        border: c == _color
                            ? Border.all(color: Fl.fg1, width: 2)
                            : null,
                      ),
                      child: c == _color
                          ? Icon(FluentIcons.checkmark_12_filled,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton(onPressed: _save, child: Text('保存')),
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

/// サイドバー下部の操作（取り込み・空き時間など）
class _SideAction extends StatelessWidget {
  const _SideAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Fl.fg2),
            SizedBox(width: 12),
            Expanded(child: Text(label, style: FlText.body1)),
          ],
        ),
      ),
    );
  }
}
