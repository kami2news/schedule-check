import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'notify/reminder_service.dart';
import 'reminders.dart';
import 'store.dart';
import 'sync/account.dart';
import 'ui/account_page.dart';
import 'ui/calendar_page.dart';
import 'ui/controller.dart';
import 'ui/edit_pages.dart';
import 'ui/event_peek.dart';
import 'ui/finder_pages.dart';
import 'ui/fluent.dart';
import 'ui/fluent_extras.dart';
import 'ui/import_page.dart';
import 'ui/layout.dart';
import 'ui/sidebar.dart';
import 'ui/todo_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.load();
  final account = AccountService(store);
  // 先に画面を出す。Firebase の準備は裏で行い、つながらなくても端末内のデータで使える
  runApp(ScheduleApp(store: store, account: account));
  unawaited(account.init());
}

class ScheduleApp extends StatefulWidget {
  const ScheduleApp({super.key, required this.store, this.account});

  final AppStore store;

  /// 省略時（テストなど）は Firebase を使わないアカウント
  final AccountService? account;

  @override
  State<ScheduleApp> createState() => _ScheduleAppState();
}

/// ライト／ダークの切り替えを受け持つ。
/// 色トークン（Fl）はグローバルなので、切り替え時は画面全体を再構築する。
class _ScheduleAppState extends State<ScheduleApp> with WidgetsBindingObserver {
  late final AccountService _account =
      widget.account ?? AccountService(widget.store);

  final _navKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final ReminderService _reminders =
      ReminderService(widget.store, onFire: _showReminder);

  /// 通知の時刻になったら、画面内にも知らせる（「表示」で中身を開く）
  void _showReminder(ReminderItem r, bool systemShown) {
    _messengerKey.currentState?.showSnackBar(SnackBar(
      duration: Duration(seconds: 12),
      content: Row(children: [
        Icon(FluentIcons.alert_24_regular, size: 18, color: Fl.brandFg),
        SizedBox(width: 10),
        Expanded(
          child: Text('${r.title}\n${r.body}', maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ]),
      action: SnackBarAction(
        label: '表示',
        textColor: Fl.brandFg,
        onPressed: () {
          final ctx = _navKey.currentContext;
          if (ctx == null) return;
          if (r.event != null) {
            openEventPeek(ctx, r.event!, r.date ?? r.event!.firstDate);
          } else if (r.task != null) {
            openTaskEditor(ctx, task: r.task);
          }
        },
      ),
    ));
  }

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
    // 画面内の表示（SnackBar）が出せるようになってから通知の確認を始める
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reminders.start();
    });
  }

  @override
  void dispose() {
    _reminders.dispose();
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
      child: AccountScope(
        account: _account,
        child: MaterialApp(
        navigatorKey: _navKey,
        scaffoldMessengerKey: _messengerKey,
        title: 'スケジュール確認',
        debugShowCheckedModeBanner: false,
        theme: buildFluentTheme(),
        themeAnimationDuration: Duration.zero,
        locale: Locale('ja'),
        supportedLocales: [Locale('ja'), Locale('en')],
        // Material・Cupertino・Widgets の日本語化をまとめて指定
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeShell(),
      ),
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
    _cal!.dayCount = (int.tryParse(store.uiValue('dayCount') ?? '') ?? 1).clamp(1, 7);
    var lastView = _cal!.view;
    var lastCount = _cal!.dayCount;
    _cal!.addListener(() {
      if (_cal!.view != lastView) {
        lastView = _cal!.view;
        store.setUiValue('view', lastView.name);
      }
      if (_cal!.dayCount != lastCount) {
        lastCount = _cal!.dayCount;
        store.setUiValue('dayCount', '$lastCount');
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
            FlTopBar(
              title: 'スケジュール確認',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                // Outlook と同じく、上部バーに検索欄
                _TopSearchBox(onTap: () => openSearch(context, cal)),
                SizedBox(width: 8),
                FlAccountButton(onDark: true),
                FlThemeButton(onDark: true),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 264,
                      child: Column(children: [
                        Expanded(
                          child: CalendarSidebar(
                              controller: cal, onImport: _openImport),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: _VersionText()),
                        ),
                      ]),
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
        child: Stack(children: [
          Positioned.fill(child: IndexedStack(
          index: _tab,
          children: [
            CalendarPage(controller: cal, compact: true),
            ColoredBox(color: Fl.bg2, child: TodoPanel(trailing: Row(mainAxisSize: MainAxisSize.min, children: [FlAccountButton(), FlThemeButton()]))),
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
        )),
          // 版の番号（左下にうっすら。押せないので操作のじゃまをしない）
          Positioned(left: 6, bottom: 2, child: IgnorePointer(child: _VersionText())),
        ]),
      ),
      // KM1 では FAB（浮いた丸いボタン）を使わない。予定の追加はカレンダーの見出し行の右、
      // タスクの追加は To Do の入力欄（「詳しく入力」）から
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

/// 上部バーの検索欄（押すと検索画面を開く）
class _TopSearchBox extends StatelessWidget {
  const _TopSearchBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Fl.r4),
      child: Container(
        width: 280,
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: Fl.isDark ? 0.08 : 0.92),
          borderRadius: BorderRadius.circular(Fl.r4),
        ),
        child: Row(children: [
          Icon(FluentIcons.search_24_regular,
              size: 16, color: Fl.isDark ? Fl.fg2 : Fl.brand),
          SizedBox(width: 8),
          Text('検索',
              style: FlText.body1.copyWith(color: Fl.isDark ? Fl.fg3 : Fl.fg2)),
        ]),
      ),
    );
  }
}

/// 版の番号（うっすら表示）。不具合の報告で「どの版か」を伝えるため
class _VersionText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'ver $kBuildId',
      style: FlText.caption2.copyWith(color: Fl.fg3.withValues(alpha: 0.7)),
    );
  }
}
