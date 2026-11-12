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
}
