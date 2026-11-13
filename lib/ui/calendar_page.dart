import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'finder_pages.dart';
import 'fluent.dart';
import 'mini_month.dart';
import 'settings_page.dart';
import 'sidebar.dart';
import 'month_view.dart';
import 'time_grid.dart';

/// カレンダー本体（ヘッダー + 日/週/月ビュー）
///
/// [compact] が true のときは狭い画面向けに、タイトルをタップすると
/// ミニカレンダーを開閉できるようにする。
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.controller, this.compact = false});

  final CalendarController controller;
  final bool compact;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool _showMini = false;

  /// Outlook と同じ「週 ▾」形式の表示切り替えメニュー。日表示は 1〜7 日を選べる
  Widget _viewMenu(CalendarController c) {
    Widget item(String label, bool on) => Row(
          children: [
            SizedBox(
              width: 20,
              child: on ? Icon(FluentIcons.checkmark_24_regular, size: 16) : null,
            ),
            SizedBox(width: 8),
            Text(label),
          ],
        );
    final current = c.view == CalView.day ? 'd${c.dayCount}' : c.view.name;
    return PopupMenuButton<String>(
      tooltip: '表示形式',
      position: PopupMenuPosition.under,
      initialValue: current,
      onSelected: (v) {
        if (v.startsWith('d')) {
          c.setDayCount(int.parse(v.substring(1)));
        } else {
          c.setView(CalView.values.byName(v));
        }
      },
      itemBuilder: (context) => [
        for (var n = 1; n <= 7; n++)
          PopupMenuItem<String>(
            value: 'd$n',
            height: 36,
            child: item(n == 1 ? '日' : '$n日', current == 'd$n'),
          ),
        PopupMenuDivider(height: 8),
        for (final v in [CalView.week, CalView.month])
          PopupMenuItem<String>(
            value: v.name,
            height: 36,
            child: item(v.label, current == v.name),
          ),
      ],
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Fl.bg1,
          border: Border.all(color: Fl.stroke1),
          borderRadius: BorderRadius.circular(Fl.r4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.viewLabel, style: FlText.body1Strong),
            SizedBox(width: 6),
            Icon(FluentIcons.chevron_down_24_regular, size: 14),
          ],
        ),
      ),
    );
  }

  /// 狭い画面では年を省いた短い見出しにする（今年以外は年も付ける）
  String _compactTitle(CalendarController c) {
    final s = c.selected;
    final y = s.year == DateTime.now().year ? '' : '${s.year}/';
    switch (c.view) {
      case CalView.day:
        if (c.dayCount > 1) {
          final b = addDays(s, c.dayCount - 1);
          // 狭い画面に収まるよう短く（同じ月なら「11/13〜15」）
          return s.month == b.month
              ? '$y${s.month}/${s.day}〜${b.day}'
              : '$y${s.month}/${s.day}〜${b.month}/${b.day}';
        }
        return '$y${s.month}/${s.day}（${weekdayNames[s.weekday - 1]}）';
      case CalView.week:
        final a = startOfWeek(s);
        final b = addDays(a, 6);
        return '$y${a.month}/${a.day}〜${b.month}/${b.day}';
      case CalView.month:
        return '${s.year}年${s.month}月';
    }
  }

  Widget _header(BuildContext context, CalendarController c) {
    final compact = widget.compact;
    final todayButton = compact
        ? OutlinedButton(onPressed: c.goToday, child: Text('今日'))
        : OutlinedButton.icon(
            onPressed: c.goToday,
            icon: Icon(FluentIcons.calendar_ltr_24_regular, size: 16),
            label: Text('今日'),
          );

    final arrows = [
      IconButton(
        tooltip: '前へ',
        icon: Icon(FluentIcons.chevron_left_24_regular),
        onPressed: () => c.step(-1),
      ),
      IconButton(
        tooltip: '次へ',
        icon: Icon(FluentIcons.chevron_right_24_regular),
        onPressed: () => c.step(1),
      ),
    ];

    final titleStyle = compact ? FlText.subtitle2 : FlText.subtitle1;
    final titleText = compact ? _compactTitle(c) : c.title;
    final Widget title = compact
        ? InkWell(
            borderRadius: BorderRadius.circular(Fl.r4),
            onTap: () => setState(() => _showMini = !_showMini),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(titleText,
                        style: titleStyle, overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    _showMini
                        ? FluentIcons.chevron_up_24_regular
                        : FluentIcons.chevron_down_24_regular,
                    size: 16,
                  ),
                ],
              ),
            ),
          )
        : Text(titleText, style: titleStyle);

    return Padding(
      padding: compact
          ? EdgeInsets.fromLTRB(12, 8, 12, 8)
          : EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          if (!compact) ...[
            todayButton,
            SizedBox(width: 4),
            ...arrows,
            SizedBox(width: 8),
          ],
          Expanded(child: Align(alignment: Alignment.centerLeft, child: title)),
          if (compact) ...[
            todayButton,
            SizedBox(width: 2),
            ...arrows,
          ],
          SizedBox(width: 8),
          _viewMenu(c),
          if (compact)
            PopupMenuButton<String>(
              tooltip: 'その他',
              position: PopupMenuPosition.under,
              icon: Icon(FluentIcons.more_vertical_24_regular, size: 20),
              onSelected: (v) {
                switch (v) {
                  case 'search':
                    openSearch(context, c);
                  case 'free':
                    openFreeTime(context);
                  case 'settings':
                    openSettings(context);
                }
              },
              itemBuilder: (_) => [
                for (final (v, icon, label) in [
                  ('search', FluentIcons.search_24_regular, '検索'),
                  ('free', FluentIcons.calendar_search_20_regular, '空き時間を探す'),
                  ('settings', FluentIcons.settings_24_regular, '設定'),
                ])
                  PopupMenuItem<String>(
                    value: v,
                    height: 36,
                    child: Row(children: [
                      Icon(icon, size: 16),
                      SizedBox(width: 10),
                      Text(label),
                    ]),
                  ),
              ],
            ),
          // 主な追加の操作（KM1: 狭い画面では見出し行の右のボタン。FAB は使わない）
          if (compact) ...[
            SizedBox(width: 4),
            IconButton.filled(
              tooltip: '予定を追加',
              icon: Icon(FluentIcons.add_24_regular, size: 20),
              onPressed: () => openEventEditor(context, date: c.selected),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final Widget body;
        switch (c.view) {
          case CalView.day:
            body = TimeGrid(
              key: ValueKey('grid-day'),
              controller: c,
              days: c.dayViewDays,
              continuous: true,
            );
            break;
          case CalView.week:
            final start = startOfWeek(c.selected);
            body = TimeGrid(
              key: ValueKey('grid-week'),
              controller: c,
              days: [for (var i = 0; i < 7; i++) addDays(start, i)],
              // 縦にスクロールすると、そのまま前後の週へ続く
              continuous: true,
              stride: 7,
            );
            break;
          case CalView.month:
            body = MonthView(key: ValueKey('month'), controller: c);
            break;
        }
        return Column(
          children: [
            _header(context, c),
            if (widget.compact)
              AnimatedSize(
                duration: Duration(milliseconds: 150),
                alignment: Alignment.topCenter,
                child: _showMini
                    ? ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.sizeOf(context).height * 0.6),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              MiniMonth(controller: c),
                              Divider(height: 1),
                              SizedBox(height: 4),
                              CalendarList(controller: c),
                              SizedBox(height: 8),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(width: double.infinity),
              ),
            Divider(height: 1),
            // スクロールは連続して流れ、スライドはページごとに切り替わる（各表示の中で処理）
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
