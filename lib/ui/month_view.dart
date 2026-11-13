import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'fluent_extras.dart';

/// Outlook 風の月表示。
///
/// 週の段を上下に続けて並べ、ホイール・トラックパッドのスクロールでは週ごとに連続して流れる。
/// スライド（指・マウスで払う）は1か月ずつ切り替わる（上・左へ払うと次の月）。
class MonthView extends StatefulWidget {
  const MonthView({super.key, required this.controller});

  final CalendarController controller;

  @override
  State<MonthView> createState() => _MonthViewState();
}

/// 前後に並べておく週の数（約10年ぶん）
const int _span = 520;

class _MonthViewState extends State<MonthView> {
  /// スクロール位置 0 が「基準の週 - _span 週」
  late DateTime _anchor;
  ScrollController? _scroll;

  /// 1段（1週）の高さ。画面にちょうど6週が入る
  double _rowH = 0;

  /// 表示中の月（その月の1日）
  late DateTime _shown;

  double _dragX = 0;
  late DateTime _dragFrom;

  CalendarController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _shown = _monthOf(c.selected);
    _anchor = startOfWeek(_shown);
  }

  DateTime _monthOf(DateTime d) => DateTime(d.year, d.month, 1);

  int _rowOf(DateTime month) =>
      (startOfWeek(month).difference(_anchor).inHours / 24).round() ~/ 7 + _span;

  DateTime _weekAt(int i) => addDays(_anchor, (i - _span) * 7);

  /// 画面の真ん中の週で、表示中の月を決める（月の最初の週を一番上にすると、その月になる）
  void _onScroll() {
    final sc = _scroll;
    if (sc == null || !sc.hasClients || _rowH <= 0) return;
    final pos = sc.position;
    final center = pos.pixels + pos.viewportDimension / 2;
    final mid = addDays(_weekAt((center / _rowH).floor()), 3);
    final m = _monthOf(mid);
    if (m == _shown) return;
    setState(() => _shown = m);
    // 選んでいた日付の「日」はそのままにして、月だけ移す
    final last = DateTime(m.year, m.month + 1, 0).day;
    c.select(DateTime(m.year, m.month, math.min(c.selected.day, last)));
  }

  /// [month] の最初の週を一番上に出す
  void _goTo(DateTime month, {bool animate = true}) {
    final sc = _scroll;
    if (sc == null || !sc.hasClients) return;
    var row = _rowOf(month);
    if (row < 1 || row > 2 * _span - 6) {
      // 範囲の外: その月を基準に並べ直す
      setState(() => _anchor = startOfWeek(month));
      row = _span;
      animate = false;
    }
    final target = row * _rowH;
    if (animate) {
      sc.animateTo(target,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      sc.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(MonthView old) {
    super.didUpdateWidget(old);
    // 矢印・今日・ミニカレンダーなどで月が変わった: その月へ（隣の月なら動かして）
    final m = _monthOf(c.selected);
    if (m == _shown) return;
    final months = (m.year - _shown.year) * 12 + m.month - _shown.month;
    _shown = m;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _goTo(m, animate: months.abs() == 1));
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  /// スライドを離したとき: 少しでも動かすか払えば、隣の月へ切り替える
  void _release(double moved, double velocity) {
    var dir = 0;
    if (velocity.abs() > 300) {
      dir = velocity < 0 ? 1 : -1;
    } else if (moved.abs() > 40) {
      dir = moved < 0 ? 1 : -1;
    }
    final target = DateTime(_dragFrom.year, _dragFrom.month + dir, 1);
    _goTo(target);
  }

  /// トラックパッドの横スクロールも、縦と同じく週ごとに流す
  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final d = e.scrollDelta;
    if (d.dx.abs() <= d.dy.abs()) return; // 縦はリストがそのままスクロールする
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      final sc = _scroll;
      if (sc == null || !sc.hasClients) return;
      final p = sc.position;
      sc.jumpTo((p.pixels + d.dx).clamp(p.minScrollExtent, p.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sel = c.selected;
    final today = dateOnly(DateTime.now());
    final week0 = startOfWeek(today);

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    weekdayNames[addDays(week0, i).weekday - 1],
                    textAlign: TextAlign.center,
                    style: FlText.caption1.copyWith(
                        color: weekendFg(addDays(week0, i)) ?? Fl.fg3),
                  ),
                ),
              ),
          ],
        ),
        Divider(height: 1),
        Expanded(
          child: LayoutBuilder(builder: (context, cs) {
            final h = cs.maxHeight / 6;
            if (_scroll == null) {
              _rowH = h;
              _scroll = ScrollController(initialScrollOffset: _rowOf(_shown) * h)
                ..addListener(_onScroll);
            } else if ((h - _rowH).abs() > 0.5) {
              // 画面の高さが変わった: 同じ週の位置を保つ
              final sc = _scroll!;
              final rows = sc.hasClients ? sc.offset / _rowH : _rowOf(_shown).toDouble();
              _rowH = h;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (sc.hasClients) sc.jumpTo(rows * h);
              });
            }
            return Listener(
              onPointerSignal: _onSignal,
              child: GestureDetector(
                onVerticalDragStart: (_) => _dragFrom = _shown,
                // 指に合わせて動かし、離したら月の頭にそろえる
                onVerticalDragUpdate: (d) {
                  final sc = _scroll!;
                  final p = sc.position;
                  sc.jumpTo((p.pixels - d.delta.dy)
                      .clamp(p.minScrollExtent, p.maxScrollExtent));
                },
                onVerticalDragEnd: (d) {
                  final sc = _scroll!;
                  final start = _rowOf(_dragFrom) * _rowH;
                  _release(start - sc.offset, d.primaryVelocity ?? 0);
                },
                onHorizontalDragStart: (_) {
                  _dragFrom = _shown;
                  _dragX = 0;
                },
                onHorizontalDragUpdate: (d) => _dragX += d.delta.dx,
                onHorizontalDragEnd: (d) => _release(_dragX, d.primaryVelocity ?? 0),
                // ドラッグでは動かさない（スライドは上の GestureDetector で月ごとに切り替える）。
                // ホイール・トラックパッドの縦スクロールはそのまま連続して流れる
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(dragDevices: {}, scrollbars: false),
                  child: ListView.builder(
                    controller: _scroll,
                    itemExtent: _rowH,
                    itemCount: 2 * _span + 1,
                    itemBuilder: (context, i) {
                      final start = _weekAt(i);
                      return Row(
                        children: [
                          for (var k = 0; k < 7; k++)
                            Expanded(
                              child: _cell(
                                  context, store, addDays(start, k), sel, today),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, AppStore store, DateTime day,
      DateTime sel, DateTime today) {
    final inMonth = day.year == _shown.year && day.month == _shown.month;
    final isToday = day == today;
    final isSel = day == sel;
    final events = c.eventsOn(store, day);
    final tasks = c.tasksOn(store, day);
    final total = events.length + tasks.length;

    return InkWell(
      onTap: () {
        c.select(day);
        c.setView(CalView.day);
      },
      onLongPress: () => openEventEditor(context, date: day),
      child: Container(
        decoration: BoxDecoration(
          color: isSel ? Fl.brandTint.withValues(alpha: 0.6) : null,
          border: Border(
            right: BorderSide(color: Fl.stroke2),
            bottom: BorderSide(color: Fl.stroke2),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, cs) {
            final maxChips =
                math.max(0, math.min(6, ((cs.maxHeight - 28) / 18).floor()));
            final shown = total <= maxChips
                ? total
                : (maxChips > 0 ? maxChips - 1 : 0);
            final hidden = total - shown;

            final chips = <Widget>[];
            var n = 0;
            for (final e in events) {
              if (n++ >= shown) break;
              chips.add(_eventChip(e, store.colorOf(e), !inMonth));
            }
            for (final t in tasks) {
              if (n++ >= shown) break;
              chips.add(_taskChip(t, !inMonth));
            }

            // 月の1日だけ「11月1日」のように月も表示する（Outlook と同じ）
            final label = day.day == 1 ? '${day.month}月1日' : '${day.day}';

            return Padding(
              padding: EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: EdgeInsets.symmetric(
                        horizontal: label.length > 2 ? 6 : 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? Fl.brand : null,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      label,
                      style: FlText.caption1Strong.copyWith(
                        color: isToday
                            ? Colors.white
                            : _dim(weekendFg(day) ?? Fl.fg1, !inMonth),
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  ...chips,
                  if (hidden > 0)
                    Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text('+$hidden',
                          style: FlText.caption2.copyWith(color: Fl.fg3)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _eventChip(Event e, Color color, bool faded) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: SizedBox(
          height: 16,
          width: double.infinity,
          child: FlAccentBox(
            accent: color,
            showAs: e.showAs,
            bar: 3,
            padding: EdgeInsets.fromLTRB(3, 0, 2, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FlText.caption2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskChip(TaskItem t, bool faded) {
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: SizedBox(
          height: 16,
          width: double.infinity,
          child: Row(
            children: [
              Icon(
                t.done
                    ? FluentIcons.checkmark_circle_16_filled
                    : FluentIcons.circle_16_regular,
                size: 12,
                color: t.done ? Fl.brandFg : Fl.fg3,
              ),
              SizedBox(width: 3),
              Expanded(
                child: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlText.caption2.copyWith(
                    decoration: t.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表示中の月以外の日は薄くする
Color _dim(Color c, bool dim) => dim ? c.withValues(alpha: 0.45) : c;
