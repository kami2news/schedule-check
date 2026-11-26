import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/parser.dart';
import 'package:schedule_check/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 取り込みの例のデータベース（test/fixtures/import_corpus.json）を全部読み、
/// 期待と違ったものをまとめて表示する。例を足すときは JSON に 1 件足すだけでよい
void main() {
  test('振り分けのキーワード・覚えた系統で、本人のカレンダーに入れる', () {
    final cals = [
      CalendarDef(id: 'other', name: '予定', colorValue: 0),
      CalendarDef(id: 'shift', name: 'シフト', colorValue: 0),
      CalendarDef(id: 'n', name: 'ノジマ', colorValue: 0, keywords: ['ノジマ']),
      CalendarDef(id: 'u', name: '設営', colorValue: 0, keywords: ['ユニティー']),
      CalendarDef(id: 'j', name: 'キャリア', colorValue: 0, genres: ['就活']),
      CalendarDef(id: 'h', name: '通院', colorValue: 0),
    ];
    Candidate one(String t) =>
        parseText(t, DateTime(2026, 11, 26), calendars: cals).candidates.single;
    expect(one('12/5(土) 10:00-18:00 ノジマ 横浜店').calendarId, 'n');
    expect(one('12/6(日) 9:00-17:00 シフト').calendarId, 'shift');
    final u = parseText('作業日:2026/12/7(月)\n作業時間:8:00-17:00\n現場名:サンプル展示場\n\n株式会社 ユニティー',
            DateTime(2026, 11, 26), calendars: cals)
        .candidates
        .first;
    expect(u.calendarId, 'u');
    // 覚えた系統（「キャリア」に就活を入れる）
    final j = one('一次面接 12/8(火) 14:00〜15:00');
    expect((j.genre, j.calendarId), ('就活', 'j'));
    // 名前が系統に合うカレンダー（「通院」→病院）
    final h = one('12/9(水) 15:30 サンプル皮膚科 受診');
    expect((h.genre, h.calendarId), ('病院', 'h'));
    // 「お届け予定」の「予定」はカレンダー名の手がかりにしない
    expect(one('12/10 お届け予定').genre, '配達');
  });

  test('系統を覚えると、そのカレンダーだけに付く（ほかからは外れる）', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final a = store.addCalendar('就活', 0xFF0F6CBD);
    final b = store.addCalendar('キャリア', 0xFF13A10E);
    expect(store.learnGenre('就活', a.id), isTrue);
    expect(store.learnGenre('就活', a.id), isFalse);
    expect(store.learnGenre('就活', b.id), isTrue);
    expect(a.genres, isEmpty);
    expect(b.genres, ['就活']);
    store.updateCalendar(b.id, keywords: ['ノジマ']);
    expect(CalendarDef.fromJson(b.toJson()).keywords, ['ノジマ']);
    expect(CalendarDef.fromJson(b.toJson()).genres, ['就活']);
  });

  test('昼休みをはさむ時限の範囲は、休みの前後で別の予定にする', () {
    // 90 分授業・昼休み 12:10〜13:00 の時限
    const periods = [(540, 630), (640, 730), (780, 870), (880, 970), (980, 1070), (1080, 1170)];
    List<Candidate> parse(String t) =>
        parseText(t, DateTime(2026, 11, 26), periods: periods).candidates;
    final cs = parse('12/3(木) 2〜4限 生物学実験');
    expect(cs.map((c) => (c.date, c.startMin, c.endMin)).toList(), [
      (DateTime(2026, 12, 3), 10 * 60 + 40, 12 * 60 + 10),
      (DateTime(2026, 12, 3), 13 * 60, 16 * 60 + 10),
    ]);
    expect(cs.every((c) => c.title == '生物学実験'), isTrue);
    // 休みをはさまない範囲は 1 つ
    expect(parse('12/3(木) 3・4限 統計学').single.endMin, 16 * 60 + 10);
    // 続けた日付と組み合わせても日ごとに分ける（次の行の時限も）
    final cs2 = parse('集中講義\n2月9日（火）・10日（水）\n1限～5限');
    expect(cs2.map((c) => (c.date.day, c.startMin)).toList(),
        [(9, 540), (9, 780), (10, 540), (10, 780)]);
    expect(periodBreakNote(periodBlocks(periods, 1, 2)), '昼休み（12:10〜13:00）');
  });

  test('取り込みの例のデータベース', () {
    final db = jsonDecode(File('test/fixtures/import_corpus.json').readAsStringSync())
        as Map<String, dynamic>;
    final now = DateTime.parse(db['now'] as String);
    final cals = [
      for (final j in (db['calendars'] as List).cast<Map<String, dynamic>>())
        CalendarDef.fromJson(j),
    ];
    final failures = <String>[];
    final cases = db['cases'] as List;
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final got = parseText(c['text'] as String, now, periods: kDefaultPeriods, calendars: cals)
          .candidates
          .where((x) => x.warning == null)
          .toList();
      final want = (c['expect'] as List).cast<String>();
      final problems = <String>[];
      if (got.length != want.length) {
        problems.add('候補の数 ${got.length}（期待 ${want.length}）');
      }
      for (var i = 0; i < want.length && i < got.length; i++) {
        final p = _check(want[i], got[i], cals);
        if (p != null) problems.add(p);
      }
      if (problems.isNotEmpty) {
        failures.add('■ ${c['id']}\n  ${problems.join('\n  ')}\n  読み取り: '
            '${got.map(_show).join(' ／ ')}');
      }
    }
    // ignore: avoid_print
    print('取り込みの例: ${cases.length} 件中 ${cases.length - failures.length} 件 OK');
    expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
  });
}

String _type(ImportType t) => const {
      ImportType.event: '予定',
      ImportType.shift: 'シフト',
      ImportType.lecture: '授業',
      ImportType.task: 'タスク',
    }[t]!;

String _time(Candidate c) {
  if (c.startMin == null) return '終日';
  final s = fmtMin(c.startMin!);
  if (c.endMin == null || c.type == ImportType.task) return s;
  return '$s-${c.endOffset > 0 ? '翌' : ''}${fmtMin(c.endMin!)}';
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _show(Candidate c) =>
    '${_date(c.date)} ${_time(c)} ${_type(c.type)} 「${c.title}」${c.place.isEmpty ? '' : ' @${c.place}'} #${c.genre} %${c.calendarId}';

String? _check(String want, Candidate c, List<CalendarDef> cals) {
  final parts = want.split(' ');
  final errs = <String>[];
  if (parts[0] != _date(c.date)) errs.add('日付 ${_date(c.date)}（期待 ${parts[0]}）');
  if (parts[1] != _time(c)) errs.add('時刻 ${_time(c)}（期待 ${parts[1]}）');
  if (parts[2] != _type(c.type)) errs.add('種類 ${_type(c.type)}（期待 ${parts[2]}）');
  for (final p in parts.skip(3)) {
    if (p == '-') continue;
    if (p.startsWith('#')) {
      if (c.genre != p.substring(1)) errs.add('系統 ${c.genre}（期待 ${p.substring(1)}）');
    } else if (p.startsWith('%')) {
      final name = cals.firstWhere((x) => x.id == c.calendarId).name;
      if (name != p.substring(1)) errs.add('カレンダー $name（期待 ${p.substring(1)}）');
    } else if (p.startsWith('@')) {
      if (!c.place.contains(p.substring(1))) errs.add('場所「${c.place}」（期待 $p）');
    } else if (!c.title.contains(p)) {
      errs.add('タイトル「${c.title}」（期待「$p」を含む）');
    }
  }
  return errs.isEmpty ? null : errs.join('、');
}
