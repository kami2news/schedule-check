import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import 'controller.dart';
import 'edit_pages.dart';
import 'event_peek.dart';
import 'fluent.dart';
import 'fluent_extras.dart';
import 'widgets.dart';

const double _hourH = 56;
const double _gutter = 48;

/// 週表示で1日の列に最低限必要な幅（これより狭い画面では横スクロール）
const double _minDayWidth = 92;

class _Placed {
  _Placed(this.event, this.slice, this.col);

  final Event event;

  /// この日にかかっている部分（日をまたぐ予定は、日ごとに切って表示する）
  final EventSlice slice;
  final int col;
  int cols = 1;

  int get start => slice.start;

  /// 表示上の終了（短い予定も30分ぶんの高さを確保）
  int get end => math.min(math.max(slice.end, slice.start + 30), 24 * 60);
}

/// 重なる予定を横に並べるための列割り当て
List<_Placed> _layoutDay(List<Event> events, DateTime day) {
  final sorted = [
    for (final e in events)
      if (e.sliceOn(day) case final s?) (e, s)
  ]..sort((a, b) => a.$2.start.compareTo(b.$2.start));
  final placed = <_Placed>[];
  var cluster = <_Placed>[];
  var colEnds = <int>[];
  var clusterEnd = -1;

  void flush() {
    for (final p in cluster) {
      p.cols = colEnds.length;
    }
    placed.addAll(cluster);
    cluster = <_Placed>[];
    colEnds = <int>[];
    clusterEnd = -1;
  }

  for (final (e, slice) in sorted) {
    final p = _Placed(e, slice, 0);
    final s = p.start;
    final end = p.end;
    if (cluster.isNotEmpty && s >= clusterEnd) flush();
    var col = colEnds.indexWhere((x) => x <= s);
    if (col < 0) {
      colEnds.add(end);
      col = colEnds.length - 1;
    } else {
      colEnds[col] = end;
    }
    cluster.add(_Placed(e, slice, col));
    if (end > clusterEnd) clusterEnd = end;
  }
  flush();
  return placed;
}

/// Outlook 風の時間グリッド（日・週表示）
class TimeGrid extends StatefulWidget {
  const TimeGrid(
      {super.key,
      required this.controller,
      required this.days,
      this.continuous = false,
      this.stride = 1});

  final CalendarController controller;
  final List<DateTime> days;

  /// 上下にスクロールすると、そのまま前後の日（週）へ続く
  final bool continuous;

  /// 縦に1段進むごとにずれる日数（日表示は1、週表示は7）
  final int stride;

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

/// 日表示で、前後に続けて並べておく日数（この範囲ならスクロールだけで日をまたげる）
const int _span = 365;

/// 1日ぶんの高さ
const double _dayH = 24 * _hourH;

class _TimeGridState extends State<TimeGrid> {
  late final ScrollController _scroll;
  final ScrollController _hScroll = ScrollController();
  bool _hJumped = false;
  int _hDays = 0;

  /// 日表示のときの基準日（スクロール位置 0 が「基準日 - _span 日」の 0:00）
  late DateTime _anchor;

  /// スクロールで選んだ日（外から日付が変わったのか、スクロールで変わったのかを見分ける）
  DateTime? _scrolledTo;

  bool get _isDay => widget.continuous;

  /// 1段に並べる日数（日表示の「3日」なら 3）
  int get _n => widget.days.length;

  int get _stride => widget.stride;

  @override
  void initState() {
    super.initState();
    _anchor = widget.days.first;
    _scroll = ScrollController(
      initialScrollOffset: (_isDay ? _span * _dayH : 0) + 7 * _hourH - 12,
    );
    if (_isDay) _scroll.addListener(_onDayScroll);
  }

  /// 日表示: 画面の真ん中がどの日にあるかで、選択中の日を切り替える
  /// （下へ引っ張って次の日が半分を超えたら、次の日になる）
  void _onDayScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final center = pos.pixels + pos.viewportDimension / 2;
    final idx = (center / _dayH).floor();
    final rowStart = addDays(_anchor, (idx - _span) * _stride);
    final cur = widget.days.first;
    if (rowStart != cur && rowStart != _scrolledTo) {
      _scrolledTo = rowStart;
      // 週表示では、選んでいた曜日のまま前後の週へ
      final shift = (rowStart.difference(cur).inHours / 24).round();
      widget.controller.select(addDays(widget.controller.selected, shift));
    }
  }

  @override
  void didUpdateWidget(TimeGrid old) {
    super.didUpdateWidget(old);
    if (!_isDay) return;
    final day = widget.days.first;
    final countChanged = old.days.length != _n;
    if (!countChanged && (day == old.days.first || day == _scrolledTo)) return;
    // 矢印・今日・ミニカレンダー・日数の変更などで日が変わった: その日の同じ時刻へ移る
    final diff = (day.difference(_anchor).inHours / 24).round();
    var idx = diff ~/ _stride + _span;
    if (countChanged || diff % _stride != 0 || idx < 1 || idx > 2 * _span - 1) {
      // 範囲の外に出たときや日数を変えたときは、その日を基準に並べ直す
      _anchor = day;
      idx = _span;
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final tod = _scroll.offset % _dayH;
      _scrolledTo = day;
      _scroll.jumpTo(idx * _dayH + tod);
    });
  }

  // ---- 狭い画面の週表示（横スクロール）: 端を越えて引っ張ったら前後の週へ ----
  double _edgePull = 0;
  bool _edgeDone = false;

  bool _onHorizontalEdge(ScrollNotification n) {
    if (n.metrics.axis != Axis.horizontal) return false;
    if (n is ScrollStartNotification) {
      _edgePull = 0;
      _edgeDone = false;
    } else if (n is OverscrollNotification) {
      _edgePull += n.overscroll; // 端で止まる動き（Android・PC）
    } else if (n is ScrollUpdateNotification) {
      // 端を越えて伸びる動き（iPhone）
      final m = n.metrics;
      if (m.pixels < m.minScrollExtent) _edgePull = m.pixels - m.minScrollExtent;
      if (m.pixels > m.maxScrollExtent) _edgePull = m.pixels - m.maxScrollExtent;
    }
    if (!_edgeDone && _edgePull.abs() > 72) {
      _edgeDone = true;
      final dir = _edgePull > 0 ? 1 : -1;
      _hJumped = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.controller.step(dir));
    }
    return false;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onDayScroll);
    _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  /// 0:00〜24:00 の時間の欄（時刻の目盛り・罫線・予定）。[days] を横に並べる。
  /// [dayLabel] が true なら、0:00 の位置に日付を出す（日表示で日をまたいで並べるとき）
  Widget _slab(BuildContext context, List<DateTime> days, List<List<Event>> events,
      List<List<TaskItem>> tasks, DateTime today, {bool dayLabel = false}) {
    return SizedBox(
      height: _dayH,
      child: Row(
        children: [
          SizedBox(
            width: _gutter,
            child: Stack(
              children: [
                if (dayLabel && days.length == 1)
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 6,
                    child: Text(
                      '${days.first.month}/${days.first.day}\n(${weekdayNames[days.first.weekday - 1]})',
                      textAlign: TextAlign.right,
                      style: FlText.caption2.copyWith(fontWeight: FontWeight.w600,
                          color: days.first == today
                              ? Fl.brandFg
                              : (weekendFg(days.first) ?? Fl.fg2)),
                    ),
                  ),
                for (var h = 1; h < 24; h++)
                  Positioned(
                    top: h * _hourH - 8,
                    left: 0,
                    right: 6,
                    child: Text(
                      '$h:00',
                      textAlign: TextAlign.right,
                      style: FlText.caption2.copyWith(color: Fl.fg3),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cs) {
                final colW = cs.maxWidth / days.length;
                return Stack(
                  children: [
                    // 日の変わり目（日表示で続けて並べるときは濃い線）
                    if (dayLabel)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(height: 2, color: Fl.stroke1),
                      ),
                    // 複数日を続けて並べるときは、各列の 0:00 に日付を出す
                    if (dayLabel && days.length > 1)
                      for (var i = 0; i < days.length; i++)
                        Positioned(
                          top: 4,
                          left: i * colW + 6,
                          child: Text(
                            '${days[i].month}/${days[i].day}(${weekdayNames[days[i].weekday - 1]})',
                            style: FlText.caption2.copyWith(
                                fontWeight: FontWeight.w600,
                                color: days[i] == today
                                    ? Fl.brandFg
                                    : (weekendFg(days[i]) ?? Fl.fg2)),
                          ),
                        ),
                    for (var h = 1; h < 24; h++)
                      Positioned(
                        top: h * _hourH,
                        left: 0,
                        right: 0,
                        child: Container(height: 1, color: Fl.stroke2),
                      ),
                    // 30分の補助線（より淡く）
                    for (var h = 0; h < 24; h++)
                      Positioned(
                        top: h * _hourH + _hourH / 2,
                        left: 0,
                        right: 0,
                        child: Container(height: 1, color: Fl.stroke3),
                      ),
                    for (var i = 0; i < days.length; i++)
                      Positioned(
                        left: i * colW,
                        width: colW,
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: Fl.stroke2)),
                          ),
                          child: _dayColumn(
                            context,
                            days[i],
                            colW,
                            events[i].where((e) => !e.allDay).toList(),
                            days[i] == today,
                            tasks[i].where((t) => t.hasTimeMark).toList(),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeader(BuildContext context, DateTime d, bool isToday) {
    final c = widget.controller;
    return InkWell(
      onTap: () {
        c.select(d);
        if (c.view != CalView.day) c.setView(CalView.day);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdayNames[d.weekday - 1],
              style: (isToday ? FlText.caption1Strong : FlText.caption1)
                  .copyWith(color: isToday ? Fl.brandFg : (weekendFg(d) ?? Fl.fg3)),
            ),
            SizedBox(height: 2),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? Fl.brand : null,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${d.day}',
                style: FlText.subtitle2
                    .copyWith(color: isToday ? Colors.white : (weekendFg(d) ?? Fl.fg1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDayEventChip(BuildContext context, Event e, DateTime day) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: GestureDetector(
        onTap: () => openEventPeek(context, e, day),
        child: SizedBox(
          width: double.infinity,
          child: FlAccentBox(
            accent: StoreScope.read(context).colorOf(e),
            showAs: e.showAs,
            child: Text(e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FlText.caption1),
          ),
        ),
      ),
    );
  }

  Widget _allDayTaskChip(BuildContext context, TaskItem t) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: GestureDetector(
        onTap: () => openTaskEditor(context, task: t),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Fl.bg1,
            border: Border.all(color: Fl.stroke1),
            borderRadius: BorderRadius.circular(Fl.r4),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => StoreScope.read(context).toggleTask(t.id),
                child: Icon(
                  t.done
                      ? FluentIcons.checkmark_circle_16_filled
                      : FluentIcons.circle_16_regular,
                  size: 14,
                  color: t.done ? Fl.brandFg : Fl.fg3,
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  // 時刻つきの締め切りは時刻も添える（時間の欄にも印が出る）
                  t.hasTimeMark ? '${fmtMin(t.dueMin!)} ${t.title}' : t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlText.caption1.copyWith(
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

  /// 予定の枠の高さ。次の日へ続く予定は 24:00 まで隙間なく伸ばす
  double _blockH(_Placed p) {
    final full = (p.end - p.start) / 60 * _hourH;
    return math.max(p.slice.isEnd ? full - 2 : full, 20.0);
  }

  Widget _block(BuildContext context, Event e, DateTime day, double h, double w,
      {BorderRadius? radius}) {
    // 細い列では1文字ずつ折り返さないよう、タイトル1行だけを省略表示にする
    final narrow = w < 40;
    final lines = narrow ? 1 : math.max(1, ((h - 4) / 16).floor());
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: () => openEventPeek(context, e, day),
      child: FlAccentBox(
        accent: StoreScope.read(context).colorOf(e),
        showAs: e.showAs,
        radius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                if (e.url.isNotEmpty)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(linkIcon(e.url, small: true),
                          size: 12,
                          color: StoreScope.read(context).colorOf(e)),
                    ),
                  ),
                TextSpan(text: e.title),
              ]),
              maxLines: lines > 1 ? lines - 1 : 1,
              softWrap: !narrow,
              overflow: TextOverflow.ellipsis,
              style: FlText.caption1Strong,
            ),
            // 時刻・場所は折り返さず1行で省略する
            if (lines > 1)
              Text(
                '${e.timeLabel}${e.place.isEmpty ? '' : '  ${e.place}'}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: FlText.caption1.copyWith(color: Fl.fg2),
              ),
          ],
        ),
      ),
    ));
  }

  /// 札（高さ約17px）が重ならないよう、前の札にかかる分だけ下にずらす。(タスク, 札をずらす量)
  List<(TaskItem, double)> _layoutMarks(List<TaskItem> marks) {
    final sorted = [...marks]..sort((a, b) => a.dueMin!.compareTo(b.dueMin!));
    final out = <(TaskItem, double)>[];
    var prevBottom = double.negativeInfinity;
    for (final t in sorted) {
      final top = t.dueMin! / 60 * _hourH + 2;
      final labelTop = math.max(top, prevBottom + 1);
      out.add((t, labelTop - top));
      prevBottom = labelTop + 17;
    }
    return out;
  }

  /// 時刻つきの締め切りの印。その時刻に1分の枠（線）を引き、短い札を付ける
  Widget _deadlineMark(BuildContext context, TaskItem t) {
    final color = t.done ? Fl.fg3 : Fl.warning;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => openTaskEditor(context, task: t),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Fl.bg1,
              border: Border.all(color: color),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(Fl.r4),
                bottomRight: Radius.circular(Fl.r4),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  t.done
                      ? FluentIcons.checkmark_circle_16_filled
                      : FluentIcons.flag_16_regular,
                  size: 11,
                  color: color),
              SizedBox(width: 3),
              Flexible(
                child: Text(
                  '${fmtMin(t.dueMin!)} ${t.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlText.caption2.copyWith(
                    color: t.done ? Fl.fg3 : Fl.fg1,
                    decoration: t.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dayColumn(BuildContext context, DateTime day, double colW,
      List<Event> timed, bool isToday, List<TaskItem> marks) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    return Stack(
      children: [
        if (isToday)
          Positioned.fill(
            child: ColoredBox(color: Fl.brandTint.withValues(alpha: 0.5)),
          ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final raw = (d.localPosition.dy / _hourH * 60 / 30).floor() * 30;
              final m = math.max(0, math.min(raw, 23 * 60 + 30));
              openEventEditor(context, date: day, startMin: m);
            },
            child: SizedBox.expand(),
          ),
        ),
        for (final p in _layoutDay(timed, day))
          Positioned(
            top: p.start / 60 * _hourH,
            left: p.col * (colW / p.cols) + 1,
            width: colW / p.cols - 3,
            height: _blockH(p),
            child: _block(
              context,
              p.event,
              // 続きの日を押しても、その回（開始日）のプレビューを開く
              p.slice.startDay,
              _blockH(p),
              colW / p.cols - 3,
              // 日をまたぐ予定は、つながる側（日の変わり目）を角ばらせて切れ目なく見せる
              radius: BorderRadius.vertical(
                top: Radius.circular(p.slice.isStart ? Fl.r4 : 0),
                bottom: Radius.circular(p.slice.isEnd ? Fl.r4 : 0),
              ),
            ),
          ),
        // 締め切りの印は予定の上に重ねる
        // 近い時刻の締め切りは、線はそれぞれの時刻に引き、札だけ下にずらして重ならないようにする
        // 先に線をすべて引き、その上に札を置く（線が別の札の文字にかからないように）
        for (final t in marks)
          Positioned(
            top: t.dueMin! / 60 * _hourH,
            left: 0,
            width: colW - 2,
            height: math.max(_hourH / 60, 2),
            child: IgnorePointer(
              child: ColoredBox(color: t.done ? Fl.fg3 : Fl.warning),
            ),
          ),
        for (final (t, shift) in _layoutMarks(marks))
          Positioned(
            top: t.dueMin! / 60 * _hourH + 2 + shift,
            left: 0,
            width: colW - 2,
            height: 17,
            child: _deadlineMark(context, t),
          ),
        if (isToday)
          Positioned(
            top: nowMin / 60 * _hourH - 4,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: Fl.dangerLine, shape: BoxShape.circle),
                  ),
                  Expanded(child: Container(height: 2, color: Fl.dangerLine)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = widget.controller;
    final days = widget.days;
    final today = dateOnly(DateTime.now());

    final events = [for (final d in days) c.eventsOn(store, d)];
    final tasks = [for (final d in days) c.tasksOn(store, d)];
    var maxAll = 0;
    for (var i = 0; i < days.length; i++) {
      final n = events[i].where((e) => e.allDay).length + tasks[i].length;
      if (n > maxAll) maxAll = n;
    }

    final content = Column(
      children: [
        Row(
          children: [
            SizedBox(width: _gutter),
            for (final d in days)
              Expanded(child: _dayHeader(context, d, d == today)),
          ],
        ),
        if (maxAll > 0)
          Container(
            padding: EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Fl.stroke2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _gutter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4, right: 6),
                    child: Text('終日',
                        textAlign: TextAlign.right,
                        style: FlText.caption2.copyWith(color: Fl.fg3)),
                  ),
                ),
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Column(
                      children: [
                        for (final e in events[i].where((e) => e.allDay))
                          _allDayEventChip(context, e,
                              e.sliceOn(days[i])?.startDay ?? days[i]),
                        for (final t in tasks[i]) _allDayTaskChip(context, t),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Divider(height: 1),
        Expanded(
          child: _isDay
              // 日表示: 前後の日を縦に続けて並べ、スクロールだけで日をまたげるようにする
              ? ListView.builder(
                  controller: _scroll,
                  itemExtent: _dayH,
                  itemCount: 2 * _span + 1,
                  itemBuilder: (context, i) {
                    // 1段下がるごとに1日ずつずれる。各列はそのまま自分の翌日へ続く
                    final ds = [
                      for (var k = 0; k < _n; k++)
                        addDays(_anchor, (i - _span) * _stride + k)
                    ];
                    return _slab(
                        context,
                        ds,
                        [for (final d in ds) c.eventsOn(store, d)],
                        [for (final d in ds) c.tasksOn(store, d)],
                        today,
                        dayLabel: true);
                  },
                )
              : SingleChildScrollView(
                  controller: _scroll,
                  child: _slab(context, days, events, tasks, today),
                ),
        ),
      ],
    );

    // 狭い画面の週表示: 1日あたりの最小幅を確保して横スクロールにする
    return LayoutBuilder(builder: (context, cs) {
      final perDay = (cs.maxWidth - _gutter) / days.length;
      if (days.length == 1 || perDay >= _minDayWidth) return content;
      // 段の数が変わったら、横スクロールの位置も選択中の日に合わせ直す
      if (_hDays != days.length) {
        _hDays = days.length;
        _hJumped = false;
      }
      final width = _gutter + _minDayWidth * days.length;
      if (!_hJumped) {
        _hJumped = true;
        final i = days.indexOf(c.selected);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_hScroll.hasClients || i < 0) return;
          final target = (i * _minDayWidth - _minDayWidth / 2)
              .clamp(0.0, _hScroll.position.maxScrollExtent);
          _hScroll.jumpTo(target);
        });
      }
      return NotificationListener<ScrollNotification>(
        onNotification: _onHorizontalEdge,
        child: Scrollbar(
          controller: _hScroll,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: width, child: content),
          ),
        ),
      );
    });
  }
}
