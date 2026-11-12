import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/finder.dart';
import 'package:schedule_check/models.dart';

Event ev(String id, String title, DateTime d, int? s, int? e,
        {Recurrence? repeat, ShowAs showAs = ShowAs.busy, String place = ''}) =>
    Event(
        id: id,
        title: title,
        date: d,
        startMin: s,
        endMin: e,
        repeat: repeat,
        showAs: showAs,
        place: place);

void main() {
  final now = DateTime(2026, 11, 11, 10, 10); // 水曜 10:10
  final mon16 = DateTime(2026, 11, 16);

  group('検索', () {
    final events = [
      ev('a', '研究室面談', mon16, 14 * 60, 15 * 60, place: '理学部III号館'),
      ev('b', '環境化学', DateTime(2026, 10, 7), 9 * 60, 10 * 60 + 30,
          repeat: const Recurrence()),
      ev('c', '面談（終了）', DateTime(2026, 11, 2), 10 * 60, 11 * 60),
    ];
    final tasks = [TaskItem(id: 't', title: '面談の資料を準備', due: mon16)];

    test('これからの予定 → 過去の予定 → タスクの順', () {
      final r = searchAll('面談', events, tasks, now);
      expect(r.map((h) => h.event?.id ?? h.task!.id).toList(), ['a', 'c', 't']);
    });

    test('場所でも探せ、複数の語はすべて含むものだけ', () {
      expect(searchAll('III号館', events, tasks, now).single.event!.id, 'a');
      expect(searchAll('研究室 理学部', events, tasks, now).single.event!.id, 'a');
      expect(searchAll('研究室 ゼミ', events, tasks, now), isEmpty);
    });

    test('繰り返しの予定は次の回の日付で出る', () {
      final h = searchAll('環境化学', events, tasks, now).single;
      expect(h.date, DateTime(2026, 11, 11));
    });
  });

  group('空き時間', () {
    test('予定のすき間を、最短の長さ以上だけ出す。今日は今の時刻より後', () {
      final events = [
        ev('x', 'ゼミ', DateTime(2026, 11, 11), 13 * 60, 15 * 60),
        ev('y', '移動', DateTime(2026, 11, 11), 16 * 60, 16 * 60 + 30),
      ];
      final s = findFreeSlots(events, now,
          const FreeTimeOptions(days: 1, dayStart: 9 * 60, dayEnd: 19 * 60, minMinutes: 60),
          now: now);
      expect(s.map((x) => (x.start, x.end)).toList(), [
        (10 * 60 + 30, 13 * 60),
        (15 * 60, 16 * 60),
        (16 * 60 + 30, 19 * 60),
      ]);
    });

    test('前後の余裕・土日の除外・「空き時間」の予定は無視', () {
      final events = [
        ev('x', 'バイト', mon16, 12 * 60, 14 * 60),
        ev('f', '自習（空き）', mon16, 15 * 60, 18 * 60, showAs: ShowAs.free),
      ];
      final s = findFreeSlots(events, DateTime(2026, 11, 14),
          const FreeTimeOptions(days: 3, dayStart: 10 * 60, dayEnd: 18 * 60, minMinutes: 60, buffer: 30));
      // 11/14(土)・15(日)は除外。16(月)は 10:00-11:30 と 14:30-18:00
      expect(s.map((x) => x.label).toList(),
          ['11/16(月) 10:00〜11:30', '11/16(月) 14:30〜18:00']);
      expect(formatSlots(s), '・11/16(月) 10:00〜11:30\n・11/16(月) 14:30〜18:00');
    });

    test('数えないカレンダーの予定は無視。終日の予定を気にしない設定もできる', () {
      final memo = Event(
          id: 'm', title: 'メモ', date: mon16, startMin: 10 * 60, endMin: 12 * 60, calendarId: 'memo');
      final allDay = ev('z', '学園祭', mon16, null, null);
      const o = FreeTimeOptions(days: 1, dayStart: 9 * 60, dayEnd: 13 * 60, minMinutes: 60);
      expect(findFreeSlots([memo], mon16, o).map((x) => (x.start, x.end)).toList(),
          [(9 * 60, 10 * 60), (12 * 60, 13 * 60)]);
      expect(
          findFreeSlots([memo], mon16, o, ignoreCalendars: {'memo'})
              .map((x) => (x.start, x.end))
              .toList(),
          [(9 * 60, 13 * 60)]);
      expect(
          findFreeSlots([allDay], mon16,
                  const FreeTimeOptions(days: 1, allDayBusy: false))
              .length,
          1);
    });

    test('日をまたぐ予定は、翌朝の分もふさがる', () {
      final night = Event(
          id: 'n', title: '夜勤', date: DateTime(2026, 11, 15), startMin: 22 * 60, endMin: 11 * 60, endOffset: 1);
      final s = findFreeSlots([night], mon16,
          const FreeTimeOptions(days: 1, dayStart: 9 * 60, dayEnd: 15 * 60, minMinutes: 60));
      expect(s.map((x) => (x.start, x.end)).toList(), [(11 * 60, 15 * 60)]);
    });

    test('終日の予定がある日は空いていない扱い', () {
      final events = [ev('z', '学園祭', mon16, null, null)];
      final s = findFreeSlots(events, mon16, const FreeTimeOptions(days: 1));
      expect(s, isEmpty);
    });
  });
}
