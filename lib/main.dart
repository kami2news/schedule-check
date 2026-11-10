import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'store.dart';
import 'ui/calendar_page.dart';
import 'ui/controller.dart';
import 'ui/edit_pages.dart';
import 'ui/import_page.dart';
import 'ui/layout.dart';
import 'ui/sidebar.dart';
import 'ui/todo_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(ScheduleApp(store: store));
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'スケジュール確認',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Outlook のブルー
          colorSchemeSeed: const Color(0xFF0F6CBD),
          useMaterial3: true,
        ),
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    );
  }
}

/// 広い画面: サイドバー + カレンダー + To Do の3ペイン
/// 狭い画面: 下のタブで カレンダー / To Do / 取り込み を切り替え
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  CalendarController? _cal;
  int _tab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 広めの画面は週表示、スマホ幅は日表示から始める
    _cal ??= CalendarController(
      view: MediaQuery.sizeOf(context).width >= kDialogBreakpoint
          ? CalView.week
          : CalView.day,
    );
  }

  @override
  void dispose() {
    _cal?.dispose();
    super.dispose();
  }

  void _openImport() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('メールなどから取り込む')),
        body: const ImportPage(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cal = _cal!;

    if (isWide(context)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('スケジュール確認'),
          scrolledUnderElevation: 0,
        ),
        body: Row(
          children: [
            SizedBox(
              width: 264,
              child: CalendarSidebar(controller: cal, onImport: _openImport),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: CalendarPage(controller: cal)),
            const VerticalDivider(width: 1),
            const SizedBox(width: 340, child: TodoPanel()),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            CalendarPage(controller: cal, compact: true),
            const TodoPanel(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('取り込み',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const Expanded(child: ImportPage()),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              tooltip: '予定を追加',
              onPressed: () => openEventEditor(context, date: cal.selected),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'カレンダー'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'To Do'),
          NavigationDestination(
              icon: Icon(Icons.content_paste_outlined),
              selectedIcon: Icon(Icons.content_paste),
              label: '取り込み'),
        ],
      ),
    );
  }
}
