import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:schedule_check/main.dart';
import 'package:schedule_check/ui/edit_pages.dart';
import 'package:schedule_check/ui/time_grid.dart';
import 'package:schedule_check/models.dart';
import 'package:schedule_check/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('授業ごとの ToDo: 授業のある回の数だけ自動で入る（休講の回は消え、消したものは作り直さない）', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final mon = DateTime(2026, 11, 30); // 月曜
    store.upsertEvent(Event(
      id: 'chem',
      title: '環境化学',
      calendarId: 'lecture',
      date: mon,
      startMin: 9 * 60,
      endMin: 10 * 60 + 30,
      repeat: const Recurrence(),
      repeatUntil: DateTime(2026, 12, 21),
      todos: [
        ClassTodo(id: 'prep', title: '予習', due: ClassTodoDue.before),
        ClassTodo(id: 'hw', title: '課題', due: ClassTodoDue.next),
      ],
    ));
    store.ensureClassTasks(mon);
    List<TaskItem> of(String t) =>
        store.tasks.where((x) => x.title == t).toList()..sort((a, b) => a.due!.compareTo(b.due!));
    // 11/30・12/7・12/14・12/21 の 4 回
    expect(of('予習').map((t) => t.due).toList(), [
      DateTime(2026, 11, 29),
      DateTime(2026, 12, 6),
      DateTime(2026, 12, 13),
      DateTime(2026, 12, 20),
    ]);
    expect(of('予習').every((t) => t.dueMin == null && t.eventId == 'chem'), isTrue);
    // 課題は次の授業の開始まで（最後の回は 1 週間後）
    expect(of('課題').map((t) => (t.due, t.dueMin)).toList(), [
      (DateTime(2026, 12, 7), 9 * 60),
      (DateTime(2026, 12, 14), 9 * 60),
      (DateTime(2026, 12, 21), 9 * 60),
      (DateTime(2026, 12, 28), 9 * 60),
    ]);
    expect(of('課題').first.eventDate, mon);

    // 何度呼んでも増えない。消した ToDo は作り直さない
    store.ensureClassTasks(mon);
    expect(store.tasks.length, 8);
    store.deleteTask(of('予習').first.id);
    store.ensureClassTasks(mon);
    expect(of('予習').length, 3);

    // 12/14 が休講 → その回のまだ済んでいない ToDo は消える（済んだものは残す）
    final hw14 = of('課題').firstWhere((t) => t.eventDate == DateTime(2026, 12, 14));
    hw14.done = true;
    store.upsertTask(hw14);
    final e = store.events.single;
    e.exdates.add(DateTime(2026, 12, 14));
    store.upsertEvent(e);
    expect(of('予習').map((t) => t.eventDate).toList(),
        [DateTime(2026, 12, 7), DateTime(2026, 12, 21)]);
    expect(of('課題').any((t) => t.id == hw14.id), isTrue);

    // ひな形をやめると、これからの回のまだ済んでいない ToDo も消える
    final e2 = Event.fromJson(store.events.single.toJson())..todos.removeWhere((t) => t.id == 'prep');
    store.upsertEvent(e2);
    expect(of('予習').where((t) => !t.due!.isBefore(DateTime.now())), isEmpty);

    // 保存して読み戻せる
    expect(Event.fromJson(store.events.single.toJson()).todos.single.title, '課題');
  });

  testWidgets('予定の編集で回ごとの ToDo を追加すると、To Do に入る', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    final today = dateOnly(DateTime.now());
    store.upsertEvent(Event(
        id: 'w', title: '統計学', calendarId: 'lecture', date: today,
        startMin: 13 * 60, endMin: 14 * 60, repeat: const Recurrence(),
        repeatUntil: addDays(today, 14)));
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScheduleApp(store: store));
    await tester.pumpAndSettle();
    openEventEditor(tester.element(find.byType(TimeGrid).first), event: store.events.single);
    await tester.pumpAndSettle();
    final field = find.descendant(of: find.byKey(ValueKey('class-todo')), matching: find.byType(TextField));
    await tester.scrollUntilVisible(field, 200,
        scrollable: find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable)).first);
    await tester.enterText(field, 'レポート提出');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    expect(find.text('レポート提出'), findsOneWidget);
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    // 今日・1週間後・2週間後の 3 回
    expect(store.tasks.where((t) => t.title == 'レポート提出').length, 3);
  });
}
