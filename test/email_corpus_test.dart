import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/parser.dart';
import 'package:schedule_check/store.dart';

/// よくあるメール・連絡文の形式で、取り込みの読み取りを確かめる。
/// 人名・店名・URL はすべて架空のもの。
void main() {
  final now = DateTime(2026, 11, 10); // 火曜
  List<Candidate> parse(String t) =>
      parseText(t, now, periods: kDefaultPeriods).candidates;
  Candidate one(String t) {
    final cs = parse(t);
    expect(cs.length, 1, reason: '候補の数: ${cs.map((c) => c.title).toList()}');
    return cs.single;
  }

  group('予約（美容室・歯医者・病院）', () {
    test('美容室の予約確認（■見出し＋次の行）', () {
      final c = one('''ご予約ありがとうございます。
■予約日時
2026年11月20日（金）18:30
■サロン名
Hair Salon Sample 横浜店
■メニュー
カット＋カラー
■所要時間の目安
約2時間''');
      expect(c.type, ImportType.event);
      expect(c.title, contains('Hair Salon Sample'));
      expect((c.date, c.startMin), (DateTime(2026, 11, 20), 18 * 60 + 30));
    });

    test('歯医者のリマインド（ご予約日時：〜）', () {
      final c = one('''【ご予約のお知らせ】
みなと歯科クリニックです。
ご予約日時：11月25日(水) 10:00〜10:30
場所：横浜市西区みなとみらい1-2-3''');
      expect((c.date, c.startMin, c.endMin), (DateTime(2026, 11, 25), 10 * 60, 10 * 60 + 30));
      expect(c.place, contains('横浜市西区'));
      expect(c.title, isNot(anyOf('', 'ご予約', '予約')));
    });

    test('病院の受診日', () {
      final c = one('''受診日：2026/11/27 9:30
診療科：皮膚科
受付は予約時間の10分前までにお願いします。''');
      expect((c.date, c.startMin), (DateTime(2026, 11, 27), 9 * 60 + 30));
      expect(c.title, isNotEmpty);
      expect(c.type, ImportType.event);
    });
  });

  group('就活・面談', () {
    test('会社説明会（件名＋日時＋URL）', () {
      final c = one('''件名：【株式会社サンプル】会社説明会のご案内
日時：2026年12月3日（木）14:00～15:30
形式：オンライン（Zoom）
URL：https://example.zoom.us/j/1111111111''');
      expect(c.title, contains('会社説明会'));
      expect((c.date, c.startMin, c.endMin), (DateTime(2026, 12, 3), 14 * 60, 15 * 60 + 30));
      expect(c.url, 'https://example.zoom.us/j/1111111111');
    });

    test('一次面接（文中の名前・所要時間・場所・持ち物）', () {
      final c = one('''一次面接の日程が決定しましたのでご連絡いたします。
日時：12月5日（土）13:00〜（約45分）
場所：本社3階 会議室A
持ち物：筆記用具''');
      expect(c.title, '一次面接');
      expect((c.startMin, c.endMin), (13 * 60, 13 * 60 + 45));
      expect(c.place, '本社3階 会議室A');
      expect(c.note, contains('筆記用具'));
    });
  });

  group('オンライン会議の招待', () {
    test('Zoom の招待文（トピック・時刻 PM）', () {
      final c = one('''サンプル太郎さんがあなたを予約されたZoomミーティングに招待しています。

トピック: ゼミ定例
時刻: 2026年11月18日 04:00 PM 大阪、札幌、東京

Zoomミーティングに参加する
https://example.zoom.us/j/2222222222

ミーティングID: 222 2222 2222
パスコード: abc123''');
      expect(c.title, 'ゼミ定例');
      expect((c.date, c.startMin), (DateTime(2026, 11, 18), 16 * 60));
      expect(c.url, 'https://example.zoom.us/j/2222222222');
      expect(c.note, contains('パスコード'));
    });

    test('Google カレンダーの招待（午後1:00～2:00）', () {
      final c = one('''研究室ミーティング
2026年11月19日(木曜日)⋅午後1:00～2:00
Google Meet に参加: https://meet.google.com/abc-defg-hij''');
      expect(c.title, '研究室ミーティング');
      expect((c.date, c.startMin, c.endMin), (DateTime(2026, 11, 19), 13 * 60, 14 * 60));
      expect(c.url, 'https://meet.google.com/abc-defg-hij');
    });
  });

  group('大学', () {
    test('休講のお知らせ', () {
      final c = one('''【休講】環境化学（月3）
11月16日（月）3限は休講とします。''');
      expect(c.type, ImportType.lecture);
      expect(c.date, DateTime(2026, 11, 16));
      expect(c.title, contains('休講'));
    });

    test('補講（日時：〜 2・3限、教室）', () {
      final c = one('''補講のお知らせ
日時：11月21日（土）2・3限
教室：2号館201''');
      expect(c.type, ImportType.lecture);
      expect((c.startMin, c.endMin), (10 * 60, 11 * 60 + 50));
      expect(c.place, '2号館201');
      expect(c.title, contains('補講'));
    });

    test('レポートの提出期限（時刻つき）', () {
      final c = one('''レポート課題
提出期限：11月30日（月）17:00
提出方法：Moodle''');
      expect(c.type, ImportType.task);
      expect((c.date, c.startMin), (DateTime(2026, 11, 30), 17 * 60));
      expect(c.title, contains('レポート'));
    });
  });

  group('バイト・暮らし', () {
    test('LINE のシフト連絡（複数行・時の省略・休み）', () {
      final cs = parse('''来週のシフトです
11/16(月) 17:00-22:00
11/18(水) 10-15
11/20(金) 休み''');
      final work = cs.where((c) => c.type == ImportType.shift).toList();
      expect(work.length, 2);
      expect((work[0].startMin, work[0].endMin), (17 * 60, 22 * 60));
      expect((work[1].startMin, work[1].endMin), (10 * 60, 15 * 60));
    });

    test('宅配のお届け予定（14時～16時）', () {
      final c = one('''お届け予定日：11月14日（土）
時間帯：14時～16時''');
      expect((c.date, c.startMin, c.endMin), (DateTime(2026, 11, 14), 14 * 60, 16 * 60));
      expect(c.title, isNotEmpty);
    });

    test('飲み会（19時〜、会費）', () {
      final c = one('''忘年会のお知らせ
日時：12月18日（金）19時〜
場所：居酒屋サンプル 横浜駅西口店
会費：4,000円''');
      expect(c.title, '忘年会');
      expect(c.startMin, 19 * 60);
      expect(c.place, '居酒屋サンプル 横浜駅西口店');
    });

    test('新幹線（発・着）', () {
      final c = one('''ご乗車日：2026年12月26日
新横浜 08:12発 → 京都 10:07着
のぞみ 215号 7号車 12番E席''');
      expect((c.date, c.startMin, c.endMin), (DateTime(2026, 12, 26), 8 * 60 + 12, 10 * 60 + 7));
    });

    test('公演（開場・開演）', () {
      final c = one('''公演日時：2026年12月12日(土) 開場17:00 / 開演18:00
会場：サンプルホール''');
      expect(c.date, DateTime(2026, 12, 12));
      expect(c.startMin, anyOf(17 * 60, 18 * 60));
      expect(c.place, 'サンプルホール');
    });
  });

  group('日時の書き方', () {
    test('13時30分〜15時', () {
      final c = one('11/24 13時30分〜15時 打ち合わせ');
      expect((c.startMin, c.endMin), (13 * 60 + 30, 15 * 60));
      expect(c.title, '打ち合わせ');
    });

    test('午前10時から正午まで', () {
      final c = one('11/24 午前10時から正午まで 研究室の大掃除');
      expect((c.startMin, c.endMin), (10 * 60, 12 * 60));
      expect(c.type, ImportType.event);
    });

    test('12月1日(火)〜12月3日(木) の合宿（数日にわたる）', () {
      final c = one('ゼミ合宿 12月1日(火)〜12月3日(木)');
      expect(c.date, DateTime(2026, 12, 1));
      expect(c.startMin, isNull);
      expect(c.endOffset, 2);
      expect(c.title, 'ゼミ合宿');
    });

    test('英語の日付（Nov 20, 2026 3:00 PM）', () {
      final c = one('Meeting: Nov 20, 2026 3:00 PM - 4:00 PM Lab meeting');
      expect((c.date, c.startMin, c.endMin), (DateTime(2026, 11, 20), 15 * 60, 16 * 60));
    });
  });

  group('追加の形式', () {
    test('Teams 会議の招待（英語・日本語混在）', () {
      final c = one('''件名: 共同研究 打ち合わせ
日時: 2026年11月26日(木) 15:00-16:00 (UTC+09:00) 大阪、札幌、東京

Microsoft Teams 会議
コンピューター、モバイル アプリケーション、またはルーム デバイスで参加する
https://teams.microsoft.com/l/meetup-join/sample
会議 ID: 123 456 789 012
パスコード: Ab1Cd2''');
      expect(c.title, contains('共同研究'));
      expect((c.startMin, c.endMin), (15 * 60, 16 * 60));
      expect(c.url, 'https://teams.microsoft.com/l/meetup-join/sample');
      expect(c.note, contains('会議 ID'));
    });

    test('ホテルの予約（チェックイン・チェックアウト）', () {
      final cs = parse('''ご予約内容
宿泊施設：サンプルホテル京都
チェックイン：2026年12月26日（土）15:00
チェックアウト：2026年12月27日（日）10:00''');
      expect(cs.length, greaterThanOrEqualTo(1));
      expect(cs.first.date, DateTime(2026, 12, 26));
      expect(cs.first.startMin, 15 * 60);
      expect(cs.first.title, isNot(anyOf('', 'ご予約内容', 'ご予約')));
    });

    test('映画のチケット', () {
      final c = one('''鑑賞日時：2026/11/22(日) 18:40～20:55
劇場：サンプルシネマ 横浜
作品名：サンプルの冒険
座席：G-12''');
      expect((c.startMin, c.endMin), (18 * 60 + 40, 20 * 60 + 55));
      expect(c.title, contains('サンプルの冒険'));
    });

    test('Webテストの受検期限', () {
      final c = one('''【株式会社サンプル】適性検査受検のお願い
受検期限：2026年11月19日（木）23:59まで
受検URL：https://example.com/test''');
      expect(c.type, ImportType.task);
      expect((c.date, c.startMin), (DateTime(2026, 11, 19), null));
      expect(c.title, contains('適性検査'));
      expect(c.url, 'https://example.com/test');
    });

    test('期末試験の日程（1行に科目・時限・教室）', () {
      final cs = parse('''期末試験日程
1/20(火) 2限 環境化学 5101教室
1/22(木) 4限 地球科学概論 5203教室''');
      expect(cs.length, 2);
      expect(cs.every((c) => c.type == ImportType.lecture), isTrue);
      expect((cs[0].date, cs[0].startMin), (DateTime(2027, 1, 20), 10 * 60));
      expect(cs[0].title, contains('環境化学'));
      expect(cs[1].title, contains('地球科学概論'));
    });

    test('説明会の申込締切と開催日が両方ある', () {
      final cs = parse('''インターンシップ説明会
開催日時：12月10日（木）13:00〜14:30
申込締切：12月3日（木）''');
      final ev = cs.firstWhere((c) => c.type != ImportType.task);
      final task = cs.firstWhere((c) => c.type == ImportType.task);
      expect((ev.date, ev.startMin, ev.endMin), (DateTime(2026, 12, 10), 13 * 60, 14 * 60 + 30));
      expect(ev.title, contains('インターンシップ説明会'));
      expect(task.date, DateTime(2026, 12, 3));
      expect(task.title, contains('申込'));
    });

    test('ゴミ出し・回覧（明日）', () {
      final c = one('明日 8:30までに粗大ごみを出す');
      expect(c.type, ImportType.task);
      expect((c.date, c.startMin), (DateTime(2026, 11, 11), 8 * 60 + 30));
    });

    test('部活の連絡（集合時刻・場所）', () {
      final c = one('''11/29(日) 練習試合
集合：9:00 ○○大学 正門前
解散予定 16:00''');
      expect(c.title, '練習試合');
      expect((c.startMin, c.endMin), (9 * 60, 16 * 60));
      expect(c.place, contains('正門前'));
    });
  });

  // 2026-11-13 の動作検証レポート（A01〜A08）の入力
  group('検証レポートの指摘', () {
    test('A01: 23:59 締切は終日のタスク（仕様）。終日にしたことを補足で示す', () {
      for (final t in ['12/11 QAレポート提出 23:59', '12/10 23:59 QAレポート提出']) {
        final c = one(t);
        expect(c.type, ImportType.task);
        expect(c.startMin, isNull);
        expect(c.hint, contains('23:59 締切'));
      }
      // 23:59 以外の時刻は残す
      expect(one('12/11 17:00 QAレポート提出').startMin, 17 * 60);
    });

    test('A02: 逆転した時刻は注意を付け、チェックを外す', () {
      final c = one('2026/11/22 14:00-13:00 QA逆転');
      expect(c.warning, contains('14:00-13:00'));
      expect(c.selected, isFalse);
      // 夜→朝は日またぎとして正しく読む（注意なし）
      final n = one('2026/11/21 23:00-01:00 QA夜勤');
      expect((n.endMin, n.endOffset, n.warning), (60, 1, null));
    });

    test('A03: 全角の日付・時刻も半角と同じに読む', () {
      final c = one('１１月２８日 １０：００〜１１：００ QA全角');
      expect((c.date, c.startMin, c.endMin), (DateTime(2026, 11, 28), 10 * 60, 11 * 60));
      expect(c.title, 'QA全角');
    });

    test('A04: 読めない時刻は終日にせず、注意を付けてタイトルから外す', () {
      final cs = parse('11/24 25:00-26:00 QA不正時\n11/25 12:60-13:70 QA不正分');
      expect(cs.length, 2);
      for (final c in cs) {
        expect(c.warning, contains('読み取れませんでした'));
        expect(c.selected, isFalse);
        expect(c.title.contains(':'), isFalse);
      }
      expect(cs[0].title, 'QA不正時');
    });

    test('A05: ありえない日付は前の予定のメモに入れず、読めなかった行として返す', () {
      final r = parseText('''2026/11/21 23:00-01:00 QA夜勤
2026/02/30 10:00-11:00 QA不正日
2026/13/01 10:00-11:00 QA不正月''', now);
      expect(r.candidates.single.note, isEmpty);
      expect(r.unreadable.length, 2);
      expect(r.unreadable.first, contains('QA不正日'));
    });

    test('A06: 同じ文章の中の重複は2件目に注意を付けて外す。時間の重なりも知らせる', () {
      final cs = parse('''12/12 10:00-11:00 QA同一
12/12 10:00-11:00 QA同一
12/12 10:30-11:30 QA重複時間''');
      expect(cs.length, 3);
      expect(cs[0].selected, isTrue);
      expect(cs[1].selected, isFalse);
      expect(cs[1].warning, contains('同じ予定'));
      expect(cs[2].hint, contains('時間が重なって'));
    });

    test('A07: 12/4〜12/6 は3日間の終日予定', () {
      final c = one('12/4〜12/6 QA旅行');
      expect((c.date, c.startMin, c.endOffset), (DateTime(2026, 12, 4), null, 2));
      expect(c.title, 'QA旅行');
    });

    test('A08: 1行に2件あれば2つの候補に分ける', () {
      final cs = parse('12/2 10:00-11:00 QA複数A、12/3 13:00-14:00 QA複数B');
      expect(cs.map((c) => (c.date, c.startMin, c.title)).toList(), [
        (DateTime(2026, 12, 2), 10 * 60, 'QA複数A'),
        (DateTime(2026, 12, 3), 13 * 60, 'QA複数B'),
      ]);
    });
  });
}
