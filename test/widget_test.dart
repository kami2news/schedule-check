import 'package:flutter_test/flutter_test.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/parser.dart';
import 'package:schedule_check/store.dart';

void main() {
  final now = DateTime(2026, 11, 10);

  test('締切行をタスクとして読み取る', () {
    final r = parseText('11/20 レポート提出 23:59', now);
    expect(r.candidates.length, 1);
    final c = r.candidates.first;
    expect(c.type, ImportType.task);
    expect(c.date, DateTime(2026, 11, 20));
    expect(c.startMin, isNull); // 23:59 締め切りは終日扱い
    expect(c.title, 'レポート提出');
  });

  test('締め切りの時刻: 0:00 は前日の終日、それ以外の時刻は残す', () {
    final a = parseText('提出期限：11月21日 0:00', now).candidates.single;
    expect(a.type, ImportType.task);
    expect((a.date, a.startMin), (DateTime(2026, 11, 20), null));
    final b = parseText('11/20 17:00までにレポートを提出', now).candidates.single;
    expect((b.date, b.startMin), (DateTime(2026, 11, 20), 17 * 60));
    final c = parseText('11/20 レポート提出', now).candidates.single;
    expect((c.date, c.startMin), (DateTime(2026, 11, 20), null));
  });

  group('取り込み: 時限・正午・24:00・来週の曜日', () {
    // now は 2026/11/10（火）
    const periods = [
      (9 * 60, 10 * 60 + 30),
      (10 * 60 + 40, 12 * 60 + 10),
      (13 * 60, 14 * 60 + 30),
      (14 * 60 + 40, 16 * 60 + 10),
    ];
    Candidate one(String t) => parseText(t, now, periods: periods).candidates.single;

    test('「3限」「3・4限」を時限の時刻にする（授業として）', () {
      final a = one('11/20 3限 環境化学 補講');
      expect((a.startMin, a.endMin), (13 * 60, 14 * 60 + 30));
      expect(a.type, ImportType.lecture);
      expect(a.title.contains('限'), isFalse);
      final b = one('11/24 ３・４限 地球科学実験');
      expect((b.startMin, b.endMin), (13 * 60, 16 * 60 + 10));
      // 時刻が書いてあればそちらを使う
      final c = one('11/25 13:10〜14:40 3限 統計学');
      expect((c.startMin, c.endMin), (13 * 60 + 10, 14 * 60 + 40));
      // 2桁の時限と、初期値（50分授業・休み10分）
      final d = parseText('11/26 10限 特別講義', now, periods: kDefaultPeriods)
          .candidates
          .single;
      expect((d.startMin, d.endMin), (18 * 60, 18 * 60 + 50));
      final e = parseText('11/27 1・2限 環境化学', now, periods: kDefaultPeriods)
          .candidates
          .single;
      expect((e.startMin, e.endMin), (9 * 60, 10 * 60 + 50));
      // 時限の設定を渡さないときは時刻なし
      expect(parseText('11/20 3限 環境化学', now).candidates.single.startMin, isNull);
    });

    test('正午・午後・午前', () {
      final a = one('11/20 正午までにレポートを提出');
      expect((a.type, a.startMin), (ImportType.task, 12 * 60));
      final b = one('11/21 午後3時から面談');
      expect(b.startMin, 15 * 60);
      final c = one('11/22 午前9:30〜午後0:30 研究室見学');
      expect((c.startMin, c.endMin), (9 * 60 + 30, 12 * 60 + 30));
    });

    test('夜から朝までの時間帯は、翌日に終わる予定にする', () {
      final a = one('11/21 22:00〜5:00 夜間作業');
      expect((a.startMin, a.endMin, a.endOffset), (22 * 60, 5 * 60, 1));
      // 夜→朝でない逆転（書き間違いなど）は、終了時刻なし
      final b = one('11/22 9:00〜5:00 作業');
      expect((b.startMin, b.endMin, b.endOffset), (9 * 60, null, 0));
    });

    test('24:00 の締め切りはその日の終日、予定の終わりは 23:59', () {
      final a = one('提出期限：11月20日 24:00');
      expect((a.date, a.startMin), (DateTime(2026, 11, 20), null));
      final b = one('11/21 22:00〜24:00 夜間作業');
      expect((b.startMin, b.endMin), (22 * 60, 23 * 60 + 59));
    });

    test('今週・来週・再来週の曜日', () {
      expect(one('来週金曜 14:00 面談').date, DateTime(2026, 11, 20));
      expect(one('今週の木曜日 18:00 ミーティング').date, DateTime(2026, 11, 12));
      expect(one('再来週月曜までにレポート提出').date, DateTime(2026, 11, 23));
      expect(one('来週日曜 10:00 イベント設営').date, DateTime(2026, 11, 15));
    });
  });

  group('取り込み: Moodle のタイムライン', () {
    const one = '''2026年 11月 15日(日曜日)
23:59
[第6週課題](https://moodle.toho-u.ac.jp/mod/assign/view.php?id=197527)
「課題」の提出期限 · 2026理-環境統計基礎-大木真人-月3・4-秋''';

    test('課題の提出期限をタスクにする（科目名つき・リンクつき・23:59 は終日）', () {
      final r = parseText(one, now);
      final c = r.candidates.single;
      expect(c.type, ImportType.task);
      expect(c.title, '第6週課題（環境統計基礎）');
      expect((c.date, c.startMin), (DateTime(2026, 11, 15), null));
      expect(c.url, 'https://moodle.toho-u.ac.jp/mod/assign/view.php?id=197527');
      expect(c.note, contains('2026理-環境統計基礎'));
    });

    test('同じ日に何件も続く形・日付が変わる形・時刻つきの締め切り', () {
      final r = parseText('''2026年 11月 15日(日曜日)
23:59
第6週課題 https://moodle.toho-u.ac.jp/mod/assign/view.php?id=1
「課題」の提出期限 · 2026理-環境統計基礎-大木真人-月3・4-秋

17:00
小テスト3
小テスト終了 · 2026理-地球化学-山田-火2-秋

2026年 11月 17日(火曜日)
00:00
レポート1
「課題」の提出期限 · 2026理-気象学-佐藤-水1-秋''', now);
      final cs = r.candidates;
      expect(cs.map((c) => c.title).toList(),
          ['第6週課題（環境統計基礎）', '小テスト3（地球化学）', 'レポート1（気象学）']);
      expect(cs.every((c) => c.type == ImportType.task), isTrue);
      expect((cs[1].date, cs[1].startMin), (DateTime(2026, 11, 15), 17 * 60));
      // 0:00 締め切りは前日の終日
      expect((cs[2].date, cs[2].startMin), (DateTime(2026, 11, 16), null));
    });

    test('ふつうの文章の Markdown リンクも、文字と URL に分けて読む', () {
      final c = parseText('11/20 14:00 [研究室面談](https://zoom.us/j/123)', now)
          .candidates
          .single;
      expect(c.title, '研究室面談');
      expect(c.url, 'https://zoom.us/j/123');
    });
  });

  test('締め切りのそろえ方と、時間の欄に印を出すか', () {
    final d = DateTime(2026, 12, 1);
    expect(normalizeDeadline(d, 0), (DateTime(2026, 11, 30), null));
    expect(normalizeDeadline(d, 24 * 60), (d, null));
    expect(normalizeDeadline(d, 23 * 60 + 59), (d, null));
    expect(normalizeDeadline(d, 12 * 60), (d, 12 * 60));
    expect(normalizeDeadline(d, null), (d, null));
    expect(TaskItem(id: 'a', title: 'x', due: d, dueMin: 12 * 60).hasTimeMark, isTrue);
    expect(TaskItem(id: 'b', title: 'x', due: d, dueMin: 23 * 60 + 59).hasTimeMark, isFalse);
    expect(TaskItem(id: 'c', title: 'x', due: d).hasTimeMark, isFalse);
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
      calendarId: 'lecture',
      date: DateTime(2026, 11, 10), // 火曜
      weekly: true,
    );
    expect(e.occursOn(DateTime(2026, 11, 17)), isTrue);
    expect(e.occursOn(DateTime(2026, 11, 18)), isFalse);
    expect(e.occursOn(DateTime(2026, 11, 3)), isFalse);
  });

  test('同じ行のZoomリンクを取り出し、タイトルや日付に混ぜない', () {
    final r = parseText(
        '11/18 14:00-15:00 面談 Zoom: https://us02web.zoom.us/j/12345678901?pwd=ab12',
        now);
    final c = r.candidates.single;
    expect(c.title, '面談');
    expect(c.date, DateTime(2026, 11, 18));
    expect(c.startMin, 14 * 60);
    expect(c.url, 'https://us02web.zoom.us/j/12345678901?pwd=ab12');
  });

  test('続く行のリンク・場所・ID はその予定に付き、空行で区切られる', () {
    const text = 'お疲れさまです。\n'
        '11/20 10:00-11:00 ゼミ\n'
        'Teams: https://teams.microsoft.com/l/meetup-join/abc\n'
        '場所：理学部III号館 302\n'
        'ミーティングID: 123 456 789\n'
        'パスコード: xyz\n'
        'よろしくお願いします。\n'
        '\n'
        '以上です';
    final r = parseText(text, now);
    final c = r.candidates.single;
    expect(c.title, 'ゼミ');
    expect(c.url, 'https://teams.microsoft.com/l/meetup-join/abc');
    expect(c.place, '理学部III号館 302');
    expect(c.note, 'ミーティングID: 123 456 789\nパスコード: xyz');
    expect(r.skipped, 2); // 挨拶と「以上です」
  });

  test('リンクの種類を判定する', () {
    expect(linkLabel('https://zoom.us/j/1'), 'Zoom');
    expect(linkLabel('https://meet.google.com/abc'), 'Google Meet');
    expect(isMeetingLink('https://example.com'), isFalse);
  });

  test('リンクとメモは保存して読み戻せる', () {
    final e = Event(
        id: '1',
        title: 'x',
        calendarId: 'other',
        date: DateTime(2026, 11, 1),
        url: 'https://zoom.us/j/1',
        note: 'ID 1');
    final back = Event.fromJson(e.toJson());
    expect(back.url, 'https://zoom.us/j/1');
    expect(back.note, 'ID 1');
    final t = TaskItem(id: '2', title: 'y', url: 'https://example.com');
    expect(TaskItem.fromJson(t.toJson()).url, 'https://example.com');
    // 以前のデータ（url なし）も読める
    final old = e.toJson()..remove('url');
    expect(Event.fromJson(old).url, '');
  });

  group('タイトルの付け方', () {
    String titleOf(String text) => parseText(text, now).candidates.single.title;

    test('ラベルと曜日だけの行は、続く「内容」行をタイトルにする', () {
      final r = parseText('【日時】11月18日（水）14:00～15:00\n内容：研究室面談', now);
      final c = r.candidates.single;
      expect(c.title, '研究室面談');
      expect(c.startMin, 14 * 60);
      expect(c.endMin, 15 * 60);
    });

    test('文末の丁寧表現や助詞を落とす', () {
      final c = parseText('11/20（金）23:59までにレポートを提出してください', now)
          .candidates
          .single;
      expect(c.title, 'レポートを提出');
      expect(c.type, ImportType.task);
      expect(c.startMin, isNull);
      expect(titleOf('12月1日（月）は休講です'), '休講');
      expect(titleOf('11/19 13:00からゼミを行います'), 'ゼミ');
    });

    test('前の見出し行・件名を使う', () {
      final c =
          parseText('■ 研究室見学会\n日程：11月25日(水) 13:00〜', now).candidates.single;
      expect(c.title, '研究室見学会');
      expect(c.startMin, 13 * 60);
      expect(titleOf('件名: 【重要】研究室面談のご案内 / 11/18 14:00'), '研究室面談');
    });

    test('かっこ書きや「3時間」は残す', () {
      final c = parseText('11/26 10時〜 ゼミ発表（第3回）', now).candidates.single;
      expect(c.title, 'ゼミ発表（第3回）');
      expect(c.startMin, 10 * 60);
      final d = parseText('11/30 実験（3時間）', now).candidates.single;
      expect(d.title, '実験（3時間）');
      expect(d.startMin, isNull);
    });

    test('ラベルしかない締切は、そのラベルを使う', () {
      final c = parseText('提出期限：11月20日 23:59', now).candidates.single;
      expect(c.title, '提出期限');
      expect(c.type, ImportType.task);
    });

    test('日付の行にタイトルがなく、次の行に時刻とタイトルがある', () {
      final c = parseText('11/21（土）\n10:00-12:00 オープンキャンパス補助', now)
          .candidates
          .single;
      expect(c.title, 'オープンキャンパス補助');
      expect(c.startMin, 10 * 60);
      expect(c.endMin, 12 * 60);
    });
  
    test('見出しは別の段落には持ち越さず、「内容：」行を優先する', () {
      const text = '■ 研究室見学会\n日程：11月25日(水) 13:00〜\n\n'
          '【日時】11月18日（水）14:00～15:00\n内容：研究室面談\n'
          'Zoom: https://zoom.us/j/123';
      final cs = parseText(text, now).candidates;
      expect(cs.map((c) => c.title).toList(), ['研究室見学会', '研究室面談']);
      expect(cs[1].url, 'https://zoom.us/j/123');
      expect(cs[1].note, '');
      final h = parseText('■ 見学会\n日程：11/25 13:00\n内容：研究室面談', now)
          .candidates
          .single;
      expect(h.title, '研究室面談');
    });
});

  group('マイカレンダーと表示方法', () {
    test('以前のデータ（kind）はカレンダー id として読める', () {
      final e = Event.fromJson({
        'id': '1',
        'title': '古い予定',
        'kind': 'shift',
        'date': '2026-11-10T00:00:00.000',
      });
      expect(e.calendarId, 'shift');
      expect(e.showAs, ShowAs.busy);
      final back = Event.fromJson(
          (e..showAs = ShowAs.tentative).toJson());
      expect(back.calendarId, 'shift');
      expect(back.showAs, ShowAs.tentative);
    });

    test('行にカレンダー名があればそのカレンダーにする', () {
      final cals = defaultCalendars()
        ..add(CalendarDef(id: 'club', name: '部活', colorValue: 0xFF13A10E))
        ..add(CalendarDef(id: 'hosp', name: '病院', colorValue: 0xFF038387));
      final r = parseText('11/20 16:00-18:00 部活 練習\n11/21 10:00 病院 定期検診',
          now, calendars: cals);
      expect(r.candidates.map((c) => c.calendarId).toList(), ['club', 'hosp']);
      final s = parseText('11/22 10:00-18:00 バイト', now, calendars: cals);
      expect(s.candidates.single.calendarId, 'shift');
    });

    test('「(仮)」「未定」は仮の予定にして、タイトルから(仮)を外す', () {
      final c = parseText('11/25 14:00 面談（仮）', now).candidates.single;
      expect(c.showAs, ShowAs.tentative);
      expect(c.title, '面談');
      expect(parseText('11/26 有給', now).candidates.single.showAs, ShowAs.away);
    });
  });

  test('リンクの形式チェック', () {
    expect(normalizeUrl('https://zoom.us/j/123'), 'https://zoom.us/j/123');
    expect(normalizeUrl('zoom.us/j/123'), 'https://zoom.us/j/123');
    expect(normalizeUrl('not-a-url'), isNull);
    expect(normalizeUrl('https://'), isNull);
    expect(normalizeUrl('javascript:alert(1)'), isNull);
    expect(normalizeUrl('ftp://example.com'), isNull);
    expect(normalizeUrl('https://exa mple.com'), isNull);
  });
}
