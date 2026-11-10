import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'store.dart';
import 'ui/edit_pages.dart';
import 'ui/import_page.dart';
import 'ui/tasks_page.dart';
import 'ui/today_page.dart';
import 'ui/week_page.dart';

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
          colorSchemeSeed: Colors.teal,
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['今日', '今週', 'タスク', '取り込み'];

  void _onAdd() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          _index == 2 ? const TaskEditPage() : const EventEditPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const [
          TodayPage(),
          WeekPage(),
          TasksPage(),
          ImportPage(),
        ],
      ),
      floatingActionButton: _index == 3
          ? null
          : FloatingActionButton(
              onPressed: _onAdd,
              tooltip: _index == 2 ? 'タスクを追加' : '予定を追加',
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: '今日'),
          NavigationDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week),
              label: '今週'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'タスク'),
          NavigationDestination(
              icon: Icon(Icons.content_paste_outlined),
              selectedIcon: Icon(Icons.content_paste),
              label: '取り込み'),
        ],
      ),
    );
  }
}
