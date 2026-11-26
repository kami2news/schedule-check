import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/parser.dart';
import 'package:schedule_check/store.dart';

/// 取り込みの例のデータベース（test/fixtures/import_corpus.json）を全部読み、
/// 期待と違ったものをまとめて表示する。例を足すときは JSON に 1 件足すだけでよい
void main() {
  test('取り込みの例のデータベース', () {
    final db = jsonDecode(File('test/fixtures/import_corpus.json').readAsStringSync())
        as Map<String, dynamic>;
    final now = DateTime.parse(db['now'] as String);
    final failures = <String>[];
    final cases = db['cases'] as List;
    for (final c in cases.cast<Map<String, dynamic>>()) {
      final got = parseText(c['text'] as String, now, periods: kDefaultPeriods)
          .candidates
          .where((x) => x.warning == null)
          .toList();
      final want = (c['expect'] as List).cast<String>();
      final problems = <String>[];
      if (got.length != want.length) {
        problems.add('候補の数 ${got.length}（期待 ${want.length}）');
      }
      for (var i = 0; i < want.length && i < got.length; i++) {
        final p = _check(want[i], got[i]);
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
    '${_date(c.date)} ${_time(c)} ${_type(c.type)} 「${c.title}」${c.place.isEmpty ? '' : ' @${c.place}'}';

String? _check(String want, Candidate c) {
  final parts = want.split(' ');
  final errs = <String>[];
  if (parts[0] != _date(c.date)) errs.add('日付 ${_date(c.date)}（期待 ${parts[0]}）');
  if (parts[1] != _time(c)) errs.add('時刻 ${_time(c)}（期待 ${parts[1]}）');
  if (parts[2] != _type(c.type)) errs.add('種類 ${_type(c.type)}（期待 ${parts[2]}）');
  for (final p in parts.skip(3)) {
    if (p == '-') continue;
    if (p.startsWith('@')) {
      if (!c.place.contains(p.substring(1))) errs.add('場所「${c.place}」（期待 $p）');
    } else if (!c.title.contains(p)) {
      errs.add('タイトル「${c.title}」（期待「$p」を含む）');
    }
  }
  return errs.isEmpty ? null : errs.join('、');
}
