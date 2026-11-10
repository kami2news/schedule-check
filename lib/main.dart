import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'store.dart';
import 'ui/calendar_page.dart';
import 'ui/controller.dart';
import 'ui/edit_pages.dart';
import 'ui/fluent.dart';
import 'ui/fluent_extras.dart';
import 'ui/import_page.dart';
import 'ui/layout.dart';
import 'ui/sidebar.dart';
import 'ui/todo_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  runApp(ScheduleApp(store: store));
}

class ScheduleApp extends StatefulWidget {
  const ScheduleApp({super.key, required this.store});

  final AppStore store;

  @override
  State<ScheduleApp> createState() => _ScheduleAppState();
}

/// ライト／ダークの切り替えを受け持つ。
/// 色トークン（Fl）はグローバルなので、切り替え時は画面全体を再構築する。
class _ScheduleAppState extends State<ScheduleApp> with WidgetsBindingObserver {
  FlThemeMode get _mode => FlThemeMode.values.firstWhere(
        (m) => m.name == widget.store.themeMode,
        orElse: () => FlThemeMode.system,
      );

  Brightness get _brightness => switch (_mode) {
        FlThemeMode.light => Brightness.light,
        FlThemeMode.dark => Brightness.dark,
        FlThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
      };

  @override
  void initState() {
    super.initState();
    Fl.use(_brightness);
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_apply);
  }

  @override
  void dispose() {
    widget.store.removeListener(_apply);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _apply();

  void _apply() {
    final b = _brightness;
    if (b == Fl.palette.brightness || !mounted) return;
    Fl.use(b);
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: MaterialApp(
        title: 'スケジュール確認',
        debugShowCheckedModeBanner: false,
        theme: buildFluentTheme(),
        themeAnimationDuration: Duration.zero,
        locale: Locale('ja'),
        supportedLocales: [Locale('ja'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HomeShell(),
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

  static const _navItems = [
    FlNavItem('カレンダー', FluentIcons.calendar_ltr_24_regular,
        FluentIcons.calendar_ltr_24_filled),
    FlNavItem('To Do', FluentIcons.task_list_ltr_24_regular,
        FluentIcons.task_list_ltr_24_filled),
    FlNavItem('取り込み', FluentIcons.clipboard_paste_24_regular,
        FluentIcons.clipboard_paste_24_filled),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cal != null) return;
    final store = StoreScope.read(context);
    // 前回の表示形式を復元。初回は広めの画面なら週、スマホ幅なら日から始める
    final saved = CalView.values
        .where((v) => v.name == store.uiValue('view'))
        .firstOrNull;
    _cal = CalendarController(
      view: saved ??
          (MediaQuery.sizeOf(context).width >= kDialogBreakpoint
              ? CalView.week
              : CalView.day),
    );
    var lastView = _cal!.view;
    _cal!.addListener(() {
      if (_cal!.view != lastView) {
        lastView = _cal!.view;
        store.setUiValue('view', lastView.name);
      }
    });
    _tab = (int.tryParse(store.uiValue('tab') ?? '') ?? 0).clamp(0, 2);
  }

  @override
  void dispose() {
    _cal?.dispose();
    super.dispose();
  }

  void _openImport() {
    showFlDialogOrPage(
      context,
      title: 'メールなどから取り込む',
      builder: (_) => ImportPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cal = _cal!;

    if (isWide(context)) {
      return Scaffold(
        backgroundColor: Fl.bg3,
        body: Column(
          children: [
            FlTopBar(title: 'スケジュール確認', trailing: FlThemeButton(onDark: true)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 264,
                      child: CalendarSidebar(
                          controller: cal, onImport: _openImport),
                    ),
                    Expanded(
                      child: FlPane(child: CalendarPage(controller: cal)),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 340,
                      child: FlPane(color: Fl.bg2, child: TodoPanel()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Fl.bg1,
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            CalendarPage(controller: cal, compact: true),
            ColoredBox(color: Fl.bg2, child: TodoPanel(trailing: FlThemeButton())),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('取り込み', style: FlText.subtitle1),
                ),
                Expanded(child: ImportPage()),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              tooltip: '予定を追加',
              elevation: 4,
              backgroundColor: Fl.brand,
              foregroundColor: Colors.white,
              shape: CircleBorder(),
              onPressed: () => openEventEditor(context, date: cal.selected),
              child: Icon(FluentIcons.add_24_regular),
            )
          : null,
      bottomNavigationBar: FlBottomNav(
        items: _navItems,
        index: _tab,
        onChanged: (i) {
          setState(() => _tab = i);
          StoreScope.read(context).setUiValue('tab', '$i');
        },
      ),
    );
  }
}
