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
      expect(c.startMin, 23 * 60 + 59);
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
