import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

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

class _TimeGridState extends State<TimeGrid>
    with SingleTickerProviderStateMixin {
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
    _anim = AnimationController.unbounded(vsync: this)
      ..addListener(() => _pan.value = _anim.value);
  }

  // ---- 横の移動 ----
  // スクロール（トラックパッド・Shift+ホイール）は指の動きのまま連続して流れ、
  // スライド（指・マウスで払う）は1ページ（日表示は1日、週表示は1週）ずつ切り替わる。
  // 前後に1ページぶんの列を余分に並べておき、[_pan]（列の数）だけずらして見せる。

  /// 今ずらしている量（列の数。正なら先の日へ）
  final ValueNotifier<double> _pan = ValueNotifier(0);
  late final AnimationController _anim;
  Timer? _idle;

  /// 前後に余分に並べる列の数（= 1ページ）。0 なら横の移動なし（狭い画面の週表示）
  int _extra = 0;

  /// 1列の幅（最後に描いたときの値）
  double _colW = 100;

  /// 1ページぶん送った: 選択中の日を進め、並びもその分ずらす
  void _commit(int dir) {
    final next = addDays(widget.days.first, dir * _stride);
    _scrolledTo = next;
    _anchor = addDays(_anchor, dir * _stride);
    widget.controller.step(dir);
  }

  /// [d] 列ぶん動かす。1ページを超えたら送る（連続スクロール）
  void _move(double d) {
    if (_extra == 0) return;
    var p = _pan.value + d;
    if (p >= _extra) {
      _commit(1);
      p -= _extra;
    } else if (p <= -_extra) {
      _commit(-1);
      p += _extra;
    }
    _pan.value = p.clamp(-_extra + 0.001, _extra - 0.001);
  }

  /// [dir] のページへ（0 なら元の位置へ）動かして止める
  void _settleTo(int dir) {
    _idle?.cancel();
    final target = (dir * _extra).toDouble();
    // OS の「動きを減らす」設定では、動かさずにすぐ切り替える
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.stop();
      if (dir != 0) _commit(dir);
      _pan.value = 0;
      return;
    }
    _anim.value = _pan.value;
    _anim
        .animateTo(target,
            duration: const Duration(milliseconds: 200), curve: Curves.decelerate)
        .then((_) {
      if (dir != 0) {
        _commit(dir);
        _pan.value = 0;
      }
    });
  }

  /// スライドを離したとき: 少し（2割）でも動かすか、払えば次のページへ
  void _release(double velocity) {
    final p = _pan.value;
    var dir = 0;
    if (velocity.abs() > 300) {
      dir = velocity < 0 ? 1 : -1;
    } else if (p.abs() > 0.2 * _extra) {
      dir = p > 0 ? 1 : -1;
    }
    _settleTo(dir);
  }

  /// トラックパッドの横スクロール・Shift + ホイール: そのまま連続して流す。
  /// 止まったら近いほうのページにそろえる
  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || _extra == 0) return;
    final d = e.scrollDelta;
    final double dx;
    if (d.dx.abs() > d.dy.abs()) {
      dx = d.dx;
    } else if (HardwareKeyboard.instance.isShiftPressed && d.dy != 0) {
      dx = d.dy;
    } else {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      _anim.stop();
      _move(dx / _colW);
      _idle?.cancel();
      _idle = Timer(const Duration(milliseconds: 180), () {
        final p = _pan.value;
        _settleTo(p.abs() >= _extra / 2 ? (p > 0 ? 1 : -1) : 0);
      });
    });
  }

  /// 横にずらせる帯。表示する [_n] 列の前後に [_extra] 列ずつ並べ、[_pan] だけずらして見せる。
  /// [build] には (1列の幅, 並べる日) を渡す
  Widget _panned(
      DateTime first, Widget Function(double colW, List<DateTime> ds) build) {
    return LayoutBuilder(builder: (context, cs) {
      final colW = cs.maxWidth / _n;
      final x = _extra;
      final ds = [for (var k = -x; k < _n + x; k++) addDays(first, k)];
      if (x == 0) return build(colW, ds);
      _colW = colW;
      final w = colW * ds.length;
      // 横だけ制約を外して全列を並べ、はみ出た分は切り取る（高さは中身に合わせる）
      return UnconstrainedBox(
        alignment: Alignment.topLeft,
        constrainedAxis: Axis.vertical,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: w,
          child: ValueListenableBuilder<double>(
            valueListenable: _pan,
            builder: (context, p, child) => Transform.translate(
                offset: Offset(-(x + p) * colW, 0), child: child),
            child: build(colW, ds),
          ),
        ),
      );
    });
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
    _idle?.cancel();
    _anim.dispose();
    _pan.dispose();
    super.dispose();
  }

  /// 0:00〜24:00 の時間の欄（時刻の目盛り・罫線・予定）。[first] から [_n] 日を横に並べる
  /// （横に動かせるときは前後の日も）。
  /// [dayLabel] が true なら、0:00 の位置に日付を出す（前後の日を縦に続けて並べるとき）
  Widget _slab(BuildContext context, DateTime first, DateTime today,
      {bool dayLabel = false}) {
    final store = StoreScope.of(context);
    final c = widget.controller;
    return SizedBox(
      height: _dayH,
      child: Row(
        children: [
          SizedBox(
            width: _gutter,
            child: Stack(
              children: [
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
            child: _panned(first, (colW, days) {
              return SizedBox(
                width: colW * days.length,
                height: _dayH,
                child: Stack(
                  children: [
                    // 日の変わり目（前後の日を続けて並べるときは濃い線）
                    if (dayLabel)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(height: 2, color: Fl.stroke1),
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
                            c.eventsOn(store, days[i]).where((e) => !e.allDay).toList(),
                            days[i] == today,
                            c.tasksOn(store, days[i]).where((t) => t.hasTimeMark).toList(),
                          ),
                        ),
                      ),
                    // 各列の 0:00 に日付を出す
                    if (dayLabel)
                      for (var i = 0; i < days.length; i++)
                        Positioned(
                          top: 4,
                          left: i * colW + 6,
                          child: IgnorePointer(
                            child: Text(
                              fmtDate(days[i]),
                              style: FlText.caption2.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: days[i] == today
                                      ? Fl.brandFg
                                      : (weekendFg(days[i]) ?? Fl.fg2)),
                            ),
                          ),
                        ),
                  ],
                ),
              );
            }),
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

    Widget content(int extra) {
      _extra = extra;
      final events = [for (final d in days) c.eventsOn(store, d)];
      final tasks = [for (final d in days) c.tasksOn(store, d)];
      var maxAll = 0;
      for (var i = 0; i < days.length; i++) {
        final n = events[i].where((e) => e.allDay).length + tasks[i].length;
        if (n > maxAll) maxAll = n;
      }
      return Column(
        children: [
          Row(
            children: [
              SizedBox(width: _gutter),
              Expanded(
                child: _panned(
                  days.first,
                  (colW, ds) => Row(children: [
                    for (final d in ds)
                      SizedBox(width: colW, child: _dayHeader(context, d, d == today)),
                  ]),
                ),
              ),
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
                  Expanded(
                    child: _panned(days.first, (colW, ds) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final d in ds)
                            SizedBox(
                              width: colW,
                              child: Column(
                                children: [
                                  // 前後の日の分は、見えている日の段数までにそろえる（高さが変わらないように）
                                  ...[
                                    for (final e in c
                                        .eventsOn(store, d)
                                        .where((e) => e.allDay))
                                      _allDayEventChip(
                                          context, e, e.sliceOn(d)?.startDay ?? d),
                                    for (final t in c.tasksOn(store, d))
                                      _allDayTaskChip(context, t),
                                  ].take(maxAll),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          Divider(height: 1),
          Expanded(
            child: _isDay
                // 前後の日（週）を縦に続けて並べ、スクロールだけで日をまたげるようにする
                ? ListView.builder(
                    controller: _scroll,
                    itemExtent: _dayH,
                    itemCount: 2 * _span + 1,
                    // 1段下がるごとに stride 日ずつずれる。各列はそのまま自分の翌日へ続く
                    itemBuilder: (context, i) => _slab(
                        context, addDays(_anchor, (i - _span) * _stride), today,
                        dayLabel: true),
                  )
                : SingleChildScrollView(
                    controller: _scroll,
                    child: _slab(context, days.first, today),
                  ),
          ),
        ],
      );
    }

    return LayoutBuilder(builder: (context, cs) {
      final perDay = (cs.maxWidth - _gutter) / days.length;
      if (days.length == 1 || perDay >= _minDayWidth) {
        // 横: スライドは1ページずつ切り替え、トラックパッドの横スクロールは連続して流れる
        return Listener(
          onPointerSignal: _onSignal,
          child: GestureDetector(
            onHorizontalDragStart: (_) {
              _anim.stop();
              _idle?.cancel();
            },
            onHorizontalDragUpdate: (d) => _move(-d.delta.dx / _colW),
            onHorizontalDragEnd: (d) => _release(d.primaryVelocity ?? 0),
            child: content(_stride),
          ),
        );
      }
      // 狭い画面の週表示: 1日あたりの最小幅を確保して横スクロールにする
      // （端を越えて引っ張ると前後の週へ）
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
            child: SizedBox(width: width, child: content(0)),
          ),
        ),
      );
    });
  }
}
