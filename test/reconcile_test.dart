import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/parser.dart';
import 'package:schedule_check/reconcile.dart';

final now = DateTime(2026, 11, 10, 12);

Candidate one(String text) => parseText(text, now).candidates.single;

Event ev(String id, String title, DateTime d, int? s, int? e,
        {bool weekly = false, String cal = 'other', String url = ''}) =>
    Event(
        id: id,
        title: title,
        date: d,
        startMin: s,
        endMin: e,
        weekly: weekly,
        calendarId: cal,
        url: url);

void main() {
  final d16 = DateTime(2026, 11, 16);

  group('予定との照合', () {
    test('同じ予定は「登録済み」。メールにしかないリンクがあれば追加できる', () {
      final events = [ev('1', '面談', d16, 14 * 60, 15 * 60)];
      final c = one('11/16 14:00-15:00 研究室面談 Zoom: https://zoom.us/j/1');
      final m = reconcile(c, events, []);
      expect(m.kind, MatchKind.duplicate);
      expect(m.event!.id, '1');
      expect(m.enrich, isTrue);
      expect(m.defaultSelected, isTrue);

      final plain = reconcile(one('11/16 14:00-15:00 面談'), events, []);
      expect(plain.kind, MatchKind.duplicate);
      expect(plain.enrich, isFalse);
      expect(plain.defaultSelected, isFalse);
    });

    test('同じ日で時間が違えば「変更」', () {
      final events = [ev('1', '研究室面談', d16, 14 * 60, 15 * 60)];
      final m = reconcile(one('11/16 16:00-17:00 研究室面談'), events, []);
      expect(m.kind, MatchKind.update);
      expect(m.defaultSelected, isTrue);
    });

    test('「変更」の連絡なら別の日の同じ予定を見つける', () {
      final events = [ev('1', '研究室面談', d16, 14 * 60, 15 * 60)];
      final m =
          reconcile(one('研究室面談の日程変更：11/18 10:00-11:00'), events, []);
      expect(m.kind, MatchKind.update);
      expect(m.event!.id, '1');
    });

    test('中止の連絡は既存の予定を指す。削除は最初はチェックしない', () {
      final events = [
        ev('1', '環境化学', DateTime(2026, 11, 20), 9 * 60, 10 * 60 + 30,
            cal: 'lecture'),
      ];
      final m = reconcile(one('11/20 環境化学 休講'), events, []);
      expect(m.kind, MatchKind.cancel);
      expect(m.event!.id, '1');
      expect(m.defaultSelected, isFalse);

      // 名前が無い「休講」でも、その日の授業が1つならそれを指す
      final bare = reconcile(one('11月20日（金）は休講です'), events, []);
      expect(bare.kind, MatchKind.cancel);
      expect(bare.event!.id, '1');
    });

    test('毎週の予定は、その回だけに反映できる', () {
      final events = [
        ev('1', '環境化学', DateTime(2026, 10, 2), 9 * 60, 10 * 60 + 30,
            weekly: true, cal: 'lecture'),
      ];
      final m = reconcile(one('11/20 環境化学 休講'), events, []);
      expect(m.kind, MatchKind.cancel);
      expect(m.canApply, isTrue);
      expect(m.isRecurring, isTrue);
      expect(m.occurrence, DateTime(2026, 11, 20));
      expect(m.defaultSelected, isTrue);

      final u = reconcile(one('11/20 13:00-14:30 環境化学'), events, []);
      expect(u.kind, MatchKind.update);
      expect(u.occurrence, DateTime(2026, 11, 20));
    });

    test('似た予定が無く時間が重なれば「重なり」、何も無ければ「新規」', () {
      final events = [ev('1', 'ゼミ', d16, 13 * 60, 15 * 60)];
      final m = reconcile(one('11/16 14:00-16:00 バイト'), events, []);
      expect(m.kind, MatchKind.conflict);
      expect(m.conflicts.single.id, '1');
      expect(reconcile(one('11/16 18:00 夕食会'), events, []).kind,
          MatchKind.fresh);
    });

    test('タスク: 同じ期限は登録済み、変更の連絡なら期限を変える', () {
      final tasks = [
        TaskItem(
            id: 't', title: 'レポート提出', due: DateTime(2026, 11, 20), dueMin: 1439),
      ];
      expect(reconcile(one('11/20 レポート提出 23:59'), [], tasks).kind,
          MatchKind.duplicate);
      final m = reconcile(one('レポート提出の締切変更 11/27 23:59'), [], tasks);
      expect(m.kind, MatchKind.update);
      expect(m.task!.id, 't');
      // 期限が違うだけ（変更の連絡ではない）なら別のタスクとして新規
      expect(reconcile(one('11/27 レポート提出 23:59'), [], tasks).kind,
          MatchKind.fresh);
    });

    test('タイトルの似ている度合い', () {
      expect(titleSimilarity('面談', '研究室面談'), greaterThan(0.5));
      expect(titleSimilarity('【重要】ゼミ発表', 'ゼミ発表'), greaterThan(0.5));
      expect(titleSimilarity('ゼミ', 'バイト'), lessThan(0.5));
    });
  });

  group('勤務連絡（労働条件通知）', () {
    const notice = '労働条件通知メール\n'
        '作業日:2026/11/11(水)\n'
        '作業時間:15:30-21:00(休憩0:00)\n'
        '現場名:地方銀行フードセレクション2026\n'
        '現場住所:東京都江東区有明3-11-1 東京ビッグサイト南1-4\n'
        '作業内容:会場設営・撤去\n'
        '時給、給与支払日、その他の事項についてはアルバイト説明書の定めによります。\n'
        '株式会社ユニティー';

    test('シフトと終了報告のタスクになる', () {
      final cs = parseText(notice, now).candidates;
      expect(cs.length, 2);
      final shift = cs[0];
      expect(shift.type, ImportType.shift);
      expect(shift.title, 'ユニティー 地方銀行フードセレクション2026');
      expect(shift.date, DateTime(2026, 11, 11));
      expect(shift.startMin, 15 * 60 + 30);
      expect(shift.endMin, 21 * 60);
      expect(shift.place, '東京都江東区有明3-11-1 東京ビッグサイト南1-4');
      expect(shift.note, contains('会場設営・撤去'));
      final report = cs[1];
      expect(report.type, ImportType.task);
      expect(report.title, '終了報告（地方銀行フードセレクション2026）');
      expect(report.startMin, 21 * 60);
      // 勤務と終了報告は同じ番号で結びつく
      expect(report.linkGroup, isNotNull);
      expect(shift.linkGroup, report.linkGroup);
      expect(shift.linkEnd, isTrue);
    });

    test('1行にまとまっていても読める', () {
      final cs = parseText(
              '作業日:2026/11/11(水) 作業時間:15:30-21:00(休憩0:00) 現場名:フードセレクション 現場住所:東京ビッグサイト 作業内容:会場設営',
              now)
          .candidates;
      expect(cs.first.title, 'フードセレクション');
      expect(cs.first.place, '東京ビッグサイト');
      expect(cs.first.endMin, 21 * 60);
    });

    test('夜勤は2日に分け、終了報告は翌朝', () {
      final cs = parseText(
              '作業日:2026/11/08(日)\n作業時間:20:30-6:00(休憩1:00)\n現場名:ビッグサイト夜勤\n作業内容:撤去',
              now)
          .candidates;
      expect(cs.length, 3);
      expect(cs[0].date, DateTime(2026, 11, 8));
      expect(cs[0].startMin, 20 * 60 + 30);
      expect(cs[0].endMin, 24 * 60 - 1);
      expect(cs[1].date, DateTime(2026, 11, 9));
      expect(cs[1].startMin, 0);
      expect(cs[1].endMin, 6 * 60);
      expect(cs[2].type, ImportType.task);
      expect(cs[2].date, DateTime(2026, 11, 9));
      expect(cs[2].startMin, 6 * 60);
    });

    test('返信の引用で同じ通知が重なっても1件', () {
      final cs = parseText('$notice\n\n> $notice', now).candidates;
      expect(cs.where((c) => c.type == ImportType.shift).length, 1);
    });
  });
}
