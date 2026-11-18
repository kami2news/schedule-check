import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/sharing.dart';
import 'package:schedule_check/store.dart';
import 'package:schedule_check/ui/sharing_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sink implements SharedSink {
  final puts = <(String, Event)>[];
  final removes = <(String, String)>[];
  @override
  void putSharedEvent(String owner, Event e) => puts.add((owner, e));
  @override
  void removeSharedEvent(String owner, String id) => removes.add((owner, id));
}

SharedSource _src({required bool canEdit}) => SharedSource(
      owner: 'u2',
      ownerName: '佐藤',
      canEdit: canEdit,
      calendars: [CalendarDef(id: 'shift', name: 'シフト', colorValue: 0xFFCA5010)],
      events: [
        Event(
            id: 'a',
            title: 'バイト',
            calendarId: 'shift',
            date: DateTime(2026, 11, 20),
            startMin: 17 * 60,
            endMin: 22 * 60),
      ],
    );

void main() {
  test('共有の id は相手と元の id に戻せる', () {
    final id = sharedId('u2', 'abc~1');
    expect(id, 'share~u2~abc~1');
    expect(parseSharedId(id), (owner: 'u2', raw: 'abc~1'));
    expect(parseSharedId('abc'), isNull);
  });

  test('共有された予定は自分の予定と並び、カレンダー名に相手の名前が付く', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.applyShared(_src(canEdit: false));
    final day = store.eventsOn(DateTime(2026, 11, 20));
    expect(day.single.title, 'バイト');
    expect(day.single.id, 'share~u2~a');
    expect(store.calendarOf(day.single.calendarId).name, 'シフト（佐藤）');
    expect(store.eventById('share~u2~a')?.title, 'バイト');
  });

  test('表示のみの共有は変更できない。編集可なら相手のデータに元の id で書く', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final sink = _Sink();
    store.sharedSink = sink;

    store.applyShared(_src(canEdit: false));
    final e = store.eventsOn(DateTime(2026, 11, 20)).single;
    expect(store.canEditEvent(e), isFalse);
    store.upsertEvent(rewrapEvent(e, id: e.id, calendarId: e.calendarId));
    store.deleteEvent(e.id);
    expect(sink.puts, isEmpty);
    expect(sink.removes, isEmpty);
    expect(store.events, isEmpty); // 自分の予定には混ざらない

    store.applyShared(_src(canEdit: true));
    final e2 = store.eventsOn(DateTime(2026, 11, 20)).single;
    expect(store.canEditEvent(e2), isTrue);
    store.upsertEvent(e2);
    expect(sink.puts.single.$1, 'u2');
    expect(sink.puts.single.$2.id, 'a');
    expect(sink.puts.single.$2.calendarId, 'shift');
    // 新しい予定を相手のカレンダーに作る
    store.upsertEvent(Event(
        id: 'n1',
        title: '追加',
        calendarId: sharedId('u2', 'shift'),
        date: DateTime(2026, 11, 21)));
    expect(sink.puts.last.$2.id, 'n1');
    expect(store.eventsOn(DateTime(2026, 11, 21)).single.id, 'share~u2~n1');
    store.deleteEvent('share~u2~a');
    expect(sink.removes.single, ('u2', 'a'));
    expect(store.events, isEmpty);
  });

  test('AI 向けの文章: 繰り返しは回ごと、日をまたぐ予定は始まる日だけ、メモ・リンクは出さない', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    store.upsertEvent(Event(
        id: 'w',
        title: '環境化学',
        calendarId: 'lecture',
        date: DateTime(2026, 11, 16),
        startMin: 9 * 60,
        endMin: 10 * 60 + 30,
        place: '理学部',
        note: '秘密のメモ',
        url: 'https://zoom.us/j/1',
        repeat: const Recurrence()));
    store.upsertEvent(Event(
        id: 'n',
        title: '夜勤',
        calendarId: 'shift',
        date: DateTime(2026, 11, 18),
        startMin: 22 * 60,
        endMin: 5 * 60,
        endOffset: 1));
    store.upsertTask(TaskItem(id: 't', title: 'レポート', due: DateTime(2026, 11, 20), dueMin: 23 * 60 + 59));
    final from = DateTime(2026, 11, 16), to = DateTime(2026, 11, 24);
    final items = buildShareItems(
        from: from, to: to, eventsOn: store.eventsOn, calendarOf: store.calendarOf);
    expect(items.where((i) => i.title == '環境化学').length, 2); // 11/16 と 11/23
    expect(items.where((i) => i.title == '夜勤').single.date, DateTime(2026, 11, 18));
    final text = buildShareText(
        ownerName: '神谷',
        now: DateTime(2026, 11, 19, 8, 40),
        from: from,
        to: to,
        items: items,
        tasks: store.tasks);
    expect(text, contains('# 神谷さんの予定'));
    expect(text, contains('### 2026/11/18（水）'));
    expect(text, contains('- 22:00〜翌5:00 夜勤（シフト）'));
    expect(text, contains('- 9:00〜10:30 環境化学（授業） ＠理学部'));
    expect(text, contains('- レポート（期限 2026/11/20（金） 23:59）'));
    expect(text, isNot(contains('秘密のメモ')));
    expect(text, isNot(contains('zoom.us')));
    // 閲覧ページ用の一覧は保存して読み戻せる
    final back = ShareItem.fromJson(items.first.toJson());
    expect((back.date, back.title, back.start), (items.first.date, items.first.title, items.first.start));
  });

  testWidgets('共有リンクの閲覧ページ', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SharedLinkPage(
        token: 'x',
        loader: (_) async => (
          ownerName: '神谷',
          text: '',
          updatedAt: DateTime(2026, 11, 19, 8, 40),
          items: [
            ShareItem(
                date: DateTime(2026, 11, 20),
                title: 'ゼミ',
                calendar: '授業',
                color: 0xFF4F6BED,
                start: 13 * 60,
                end: 14 * 60,
                place: '理学部'),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('神谷さんの予定'), findsOneWidget);
    expect(find.text('2026/11/20（金）'), findsOneWidget);
    expect(find.text('ゼミ'), findsOneWidget);
    expect(find.text('13:00〜14:00・授業・理学部'), findsOneWidget);
  });

  testWidgets('共有リンクが見られないとき', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SharedLinkPage(token: 'x', loader: (_) async => null)));
    await tester.pumpAndSettle();
    expect(find.textContaining('この共有リンクは見られません'), findsOneWidget);
  });
}
