import 'package:material_ui/material_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../models.dart';
import '../store.dart';
import '../sync/account.dart';
import 'account_page.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'fluent_extras.dart';

/// アプリの設定。ログイン中はアカウントに保存され、ほかの端末にも同じ設定が反映される
/// （「この端末だけ」と書いたものを除く）
Future<void> openSettings(BuildContext context) {
  return showFlDialogOrPage(
    context,
    title: '設定',
    builder: (_) => SettingsPage(),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final acc = AccountScope.of(context);
    final periods = store.periods;

    Widget section(String title, {String? note}) => Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FlText.subtitle2),
              if (note != null) ...[
                SizedBox(height: 2),
                Text(note, style: FlText.caption1.copyWith(color: Fl.fg3)),
              ],
            ],
          ),
        );
    Widget divider() => Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(),
        );

    Widget def(String kind, String label, bool allDay) => ReminderField(
          label: label,
          value: store.defaultReminder(kind),
          allDay: allDay,
          showNote: false,
          onChanged: (v) => store.setDefaultReminder(kind, v),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        // ---- 保存先 ----
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Fl.bg2,
            borderRadius: BorderRadius.circular(Fl.r4),
            border: Border.all(color: Fl.stroke2),
          ),
          child: Row(
            children: [
              FlIcon(
                acc.signedIn
                    ? FluentIcons.cloud_checkmark_24_regular
                    : FluentIcons.phone_laptop_24_regular,
                size: 20,
                color: acc.signedIn ? Fl.brandFg : Fl.fg2,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  acc.signedIn
                      ? 'アカウント（${acc.user?.email ?? 'ログイン中'}）に保存しています。ほかの端末でログインしても同じ設定になります。'
                      : 'この端末にだけ保存しています。ログインすると、設定をほかの端末に引き継げます。',
                  style: FlText.body1,
                ),
              ),
              if (!acc.signedIn) ...[
                SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => openAccountPage(context),
                  child: Text('ログイン'),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 8),

        // ---- 表示 ----
        section('表示'),
        FlField(
          label: 'テーマ',
          child: FlDropdown<FlThemeMode>(
            items: FlThemeMode.values,
            value: FlThemeMode.values.firstWhere((m) => m.name == store.themeMode,
                orElse: () => FlThemeMode.system),
            labelOf: (m) => m.label,
            leadingOf: (m) => FlIcon(
                switch (m) {
                  FlThemeMode.system => FluentIcons.desktop_24_regular,
                  FlThemeMode.light => FluentIcons.weather_sunny_24_regular,
                  FlThemeMode.dark => FluentIcons.weather_moon_24_regular,
                },
                size: 16,
                color: Fl.fg2),
            onChanged: (m) => store.setThemeMode(m.name),
          ),
        ),
        FlField(
          label: '週の始まり',
          child: FlDropdown<bool>(
            items: const [true, false],
            value: store.weekStartsSunday,
            labelOf: (v) => v ? '日曜日' : '月曜日',
            onChanged: store.setWeekStartsSunday,
          ),
        ),
        FlSwitchTile(
          title: '土日を色分けする（土曜は青、日曜は赤）',
          value: store.weekendColors,
          onChanged: store.setWeekendColors,
        ),
        divider(),

        // ---- 授業 ----
        section('授業の時限', note: '予定の編集画面の「時限」と、取り込みの「3限」などに使います。'),
        Text(
          periods.isEmpty
              ? '設定されていません'
              : '1限 ${fmtMin(periods.first.$1)}〜${fmtMin(periods.first.$2)} ／ '
                  '${periods.length}限 ${fmtMin(periods.last.$1)}〜${fmtMin(periods.last.$2)}'
                  '（全${periods.length}コマ）',
          style: FlText.body1,
        ),
        SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showPeriodSettings(context),
            icon: FlIcon(FluentIcons.clock_24_regular, size: 18),
            label: Text('時限の時刻を編集'),
          ),
        ),
        divider(),

        // ---- 通知 ----
        section('最初から付ける通知',
            note: '新しく作る予定・締め切り（取り込みを含む）に、最初から入れておく通知です。あとから1件ずつ変えられます。'),
        def('timed', '時刻のある予定', false),
        def('allDay', '終日の予定', true),
        def('deadline', '締め切り（時刻なし）', true),
        divider(),

        // ---- この端末だけ ----
        section('この端末だけの設定', note: '端末ごとに決めるものです。アカウントには保存しません。'),
        if (acc.signedIn)
          PushSection(push: acc.push)
        else ...[
          Text('アプリを閉じていても届く通知', style: FlText.body1Strong),
          SizedBox(height: 4),
          Text(
              'ログインすると使えます。ログインしていない間は、アプリを開いているときだけ画面内でお知らせします。',
              style: FlText.body1.copyWith(color: Fl.fg2)),
        ],
        divider(),

        Text('バージョン $kBuildId', style: FlText.caption1.copyWith(color: Fl.fg3)),
      ],
    );
  }
}
