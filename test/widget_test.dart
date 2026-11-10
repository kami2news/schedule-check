import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/parser.dart';

void main() {
  final now = DateTime(2026, 11, 10);

  test('締切行をタスクとして読み取る', () {
    final r = parseText('11/20 レポート提出 23:59', now);
    expect(r.candidates.length, 1);
    final c = r.candidates.first;
    expect(c.type, ImportType.task);
    expect(c.date, DateTime(2026, 11, 20));
    expect(c.startMin, 23 * 60 + 59);
    expect(c.title, 'レポート提出');
  });

  test('シフトの時間帯を読み取る', () {
    final r = parseText('11月15日 10:00-18:00 バイト', now);
    final c = r.candidates.single;
    expect(c.type, ImportType.shift);
    expect(c.date, DateTime(2026, 11, 15));
    expect(c.startMin, 10 * 60);
    expect(c.endMin, 18 * 60);
  });

  test('日本語表記の時刻と年つき日付', () {
    final r = parseText('2026/12/3 13時30分〜15時 ゼミ', now);
    final c = r.candidates.single;
    expect(c.type, ImportType.lecture);
    expect(c.date, DateTime(2026, 12, 3));
    expect(c.startMin, 13 * 60 + 30);
    expect(c.endMin, 15 * 60);
  });

  test('日付のない行は読み飛ばす・過去の月日は来年扱い', () {
    final r = parseText('お疲れさまです\n1/5 初詣', now);
    expect(r.skipped, 1);
    expect(r.candidates.single.date, DateTime(2027, 1, 5));
  });

  test('毎週の予定は同じ曜日にだけ発生する', () {
    final e = Event(
      id: '1',
      title: '地球化学',
      kind: EventKind.lecture,
      date: DateTime(2026, 11, 10), // 火曜
      weekly: true,
    );
    expect(e.occursOn(DateTime(2026, 11, 17)), isTrue);
    expect(e.occursOn(DateTime(2026, 11, 18)), isFalse);
    expect(e.occursOn(DateTime(2026, 11, 3)), isFalse);
  });
}
