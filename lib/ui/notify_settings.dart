import 'package:material_ui/material_ui.dart';

import '../store.dart';
import '../sync/account.dart';
import 'account_page.dart';
import 'edit_pages.dart';
import 'fluent.dart';

/// 通知の設定（既定の通知と、アプリを閉じていても届く通知）をまとめた画面
Future<void> openNotifySettings(BuildContext context) {
  return showFlDialogOrPage(
    context,
    title: '通知の設定',
    builder: (_) => _NotifySettings(),
  );
}

class _NotifySettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final acc = AccountScope.of(context);

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
        Text('最初から付ける通知', style: FlText.body1Strong),
        SizedBox(height: 4),
        Text('新しく作る予定・締め切り（取り込みを含む）に、最初から入れておく通知です。あとから1件ずつ変えられます。',
            style: FlText.caption1.copyWith(color: Fl.fg3)),
        SizedBox(height: 12),
        def('timed', '時刻のある予定', false),
        def('allDay', '終日の予定', true),
        def('deadline', '締め切り（時刻なし）', true),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(),
        ),
        if (acc.signedIn)
          PushSection(push: acc.push)
        else ...[
          Text('アプリを閉じていても届く通知', style: FlText.body1Strong),
          SizedBox(height: 4),
          Text(
              'ログインすると、アプリを閉じていても通知を受け取れるようになります（右上の人のアイコンからログイン）。'
              'ログインしていない間は、アプリを開いているときだけ画面内でお知らせします。',
              style: FlText.body1.copyWith(color: Fl.fg2)),
        ],
      ],
    );
  }
}
