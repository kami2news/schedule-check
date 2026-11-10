import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../store.dart';
import '../sync/account.dart';
import '../sync/firebase_sync.dart';
import 'edit_pages.dart';
import 'fluent.dart';
import 'fluent_extras.dart';

/// アカウント画面を開く（広い画面はダイアログ、狭い画面は全画面）
Future<void> openAccountPage(BuildContext context) => showFlDialogOrPage(
      context,
      title: 'アカウント',
      builder: (_) => AccountPage(),
    );

/// 名前の頭文字の丸いアイコン（Fluent の Avatar）
class FlAvatar extends StatelessWidget {
  const FlAvatar({super.key, required this.name, this.size = 28});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final n = (name ?? '').trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: n.isEmpty ? Fl.bg6 : Fl.brandTint,
        border: Border.all(color: Fl.stroke2),
      ),
      child: n.isEmpty
          ? Icon(FluentIcons.person_24_regular,
              size: size * 0.6, color: Fl.fg2)
          : Text(
              n.characters.first.toUpperCase(),
              style: FlText.body1Strong.copyWith(
                  color: Fl.brandFg, fontSize: size * 0.42, height: 1),
            ),
    );
  }
}

/// 上部バーなどに置くアカウントボタン
class FlAccountButton extends StatelessWidget {
  const FlAccountButton({super.key, this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final acc = AccountScope.of(context);
    final u = acc.user;
    return Tooltip(
      message: u == null
          ? 'アカウント（ログインしていません）'
          : 'アカウント: ${u.displayName ?? u.email ?? ''}',
      child: InkWell(
        customBorder: CircleBorder(),
        onTap: () => openAccountPage(context),
        child: Padding(
          padding: EdgeInsets.all(6),
          child: u == null
              ? Icon(FluentIcons.person_circle_24_regular,
                  size: 24, color: onDark ? Colors.white : Fl.fg2)
              : FlAvatar(name: u.displayName ?? u.email, size: 26),
        ),
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action,
      {bool offerMove = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
      if (offerMove && mounted) await _offerGuestMove();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ログイン直後、この端末に残っているデータをアカウントに移すか確認する
  Future<void> _offerGuestMove() async {
    final store = StoreScope.read(context);
    final acc = AccountScope.read(context);
    // ログイン状態の切り替わりを少し待つ
    for (var i = 0; i < 50 && !(acc.signedIn && store.isRemote); i++) {
      await Future<void>.delayed(Duration(milliseconds: 100));
    }
    if (!mounted || !store.isRemote || !store.hasGuestData) return;
    final n = store.guestDataCount;
    final ok = await showFlConfirm(
      context,
      title: 'この端末のデータをアカウントに移しますか？',
      message: 'ログインしていない状態で作った予定${n.events}件・タスク${n.tasks}件があります。'
          '移すと、アカウントに保存されてほかの端末でも見られます。'
          '移さない場合は、ログアウトするとまたこの端末で表示されます。',
      confirmLabel: '移す',
    );
    if (ok) {
      store.moveGuestDataToRemote();
      if (mounted) setState(() => _info = 'この端末のデータをアカウントに移しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    final acc = AccountScope.of(context);
    final children = <Widget>[
      if (_busy)
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LinearProgressIndicator(
            minHeight: 2,
            color: Fl.brandFg,
            backgroundColor: Fl.stroke2,
          ),
        ),
      if (_error != null) _message(_error!, error: true),
      if (_info != null) _message(_info!),
      if (!acc.available)
        _notConfigured()
      else if (acc.signedIn)
        ..._signedIn(acc)
      else
        ..._signedOut(acc),
    ];
    return ListView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: children,
    );
  }

  Widget _message(String text, {bool error = false}) {
    final color = error ? Fl.danger : Fl.success;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Fl.tint(color, Fl.isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(Fl.r4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              error
                  ? FluentIcons.error_circle_16_filled
                  : FluentIcons.checkmark_circle_16_filled,
              size: 16,
              color: color),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: FlText.body1)),
        ],
      ),
    );
  }

  Widget _notConfigured() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Fl.bg2,
        borderRadius: BorderRadius.circular(Fl.r8),
        border: Border.all(color: Fl.stroke2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(FluentIcons.cloud_off_24_regular, size: 20, color: Fl.fg2),
            SizedBox(width: 8),
            Text('オンライン同期は準備中です', style: FlText.body1Strong),
          ]),
          SizedBox(height: 8),
          Text(
            '今はこの端末の中だけに保存しています。'
            'Firebase の設定が終わると、ここから Google・Microsoft・メールアドレスでログインして、'
            'ほかの端末と同期できるようになります。',
            style: FlText.body1.copyWith(color: Fl.fg2),
          ),
        ],
      ),
    );
  }

  List<Widget> _signedOut(AccountService acc) {
    return [
      Text(
        'ログインすると、予定・タスク・マイカレンダーがアカウントに保存され、'
        'ほかの端末と同期されます。ログインしなくても、この端末の中だけで使えます。',
        style: FlText.body1.copyWith(color: Fl.fg2),
      ),
      SizedBox(height: 16),
      _providerButton('Google で続ける', FluentIcons.globe_24_regular,
          () => _run(() => acc.signIn(SignInMethod.google), offerMove: true)),
      SizedBox(height: 8),
      _providerButton(
          'Microsoft で続ける',
          FluentIcons.window_24_regular,
          () =>
              _run(() => acc.signIn(SignInMethod.microsoft), offerMove: true)),
      Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('またはメールアドレス',
                style: FlText.caption1.copyWith(color: Fl.fg3)),
          ),
          Expanded(child: Divider()),
        ]),
      ),
      FlTabList(
        labels: ['ログイン', '新規登録'],
        selected: _register ? 1 : 0,
        onSelected: (i) => setState(() {
          _register = i == 1;
          _error = null;
        }),
      ),
      SizedBox(height: 12),
      if (_register)
        FlField(
          label: '表示名（任意）',
          child: FlTextField(controller: _name, hint: '例: さつき'),
        ),
      FlField(
        label: 'メールアドレス',
        child: FlTextField(
          controller: _email,
          hint: 'name@example.com',
          leading:
              Icon(FluentIcons.mail_24_regular, size: 16, color: Fl.fg3),
        ),
      ),
      FlField(
        label: _register ? 'パスワード（6文字以上）' : 'パスワード',
        child: FlTextField(
          controller: _password,
          obscure: true,
          onSubmitted: (_) => _submitEmail(acc),
          leading: Icon(FluentIcons.lock_closed_24_regular,
              size: 16, color: Fl.fg3),
        ),
      ),
      Row(
        children: [
          FilledButton(
            onPressed: _busy ? null : () => _submitEmail(acc),
            child: Text(_register ? '登録してログイン' : 'ログイン'),
          ),
          Spacer(),
          if (!_register)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_email.text.trim().isEmpty) {
                        setState(() => _error = 'メールアドレスを入力してください');
                        return;
                      }
                      _run(() async {
                        await acc.sendPasswordReset(_email.text);
                        if (mounted) {
                          setState(() => _info =
                              'パスワード再設定のメールを送りました。メールのリンクから新しいパスワードを設定してください');
                        }
                      });
                    },
              child: Text('パスワードを忘れた場合',
                  style: FlText.body1.copyWith(color: Fl.brandFg)),
            ),
        ],
      ),
    ];
  }

  void _submitEmail(AccountService acc) {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'メールアドレスとパスワードを入力してください');
      return;
    }
    _run(
      () => _register
          ? acc.register(
              email: _email.text, password: _password.text, name: _name.text)
          : acc.signIn(SignInMethod.email,
              email: _email.text, password: _password.text),
      offerMove: true,
    );
  }

  Widget _providerButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  List<Widget> _signedIn(AccountService acc) {
    final u = acc.user!;
    if (_name.text.isEmpty) _name.text = u.displayName ?? '';
    final state = acc.syncState;
    final stateIcon = switch (state) {
      SyncState.synced => FluentIcons.cloud_checkmark_24_regular,
      SyncState.offline => FluentIcons.cloud_off_24_regular,
      _ => FluentIcons.arrow_sync_24_regular,
    };
    return [
      Row(
        children: [
          FlAvatar(name: u.displayName ?? u.email, size: 48),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    (u.displayName ?? '').isEmpty
                        ? (u.email ?? '')
                        : u.displayName!,
                    style: FlText.subtitle2),
                if ((u.displayName ?? '').isNotEmpty && u.email != null)
                  Text(u.email!, style: FlText.body1.copyWith(color: Fl.fg2)),
                Text(acc.providerLabel,
                    style: FlText.caption1.copyWith(color: Fl.fg3)),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: 16),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Fl.bg2,
          borderRadius: BorderRadius.circular(Fl.r4),
          border: Border.all(color: Fl.stroke2),
        ),
        child: Row(children: [
          Icon(stateIcon,
              size: 20,
              color: state == SyncState.synced ? Fl.success : Fl.fg2),
          SizedBox(width: 10),
          Expanded(child: Text(state.label, style: FlText.body1)),
        ]),
      ),
      SizedBox(height: 16),
      FlField(
        label: '表示名',
        child: Row(children: [
          Expanded(child: FlTextField(controller: _name)),
          SizedBox(width: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await acc.updateDisplayName(_name.text);
                      if (mounted) setState(() => _info = '表示名を変更しました');
                    }),
            child: Text('変更'),
          ),
        ]),
      ),
      SizedBox(height: 8),
      Row(
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(acc.signOut),
            icon: Icon(FluentIcons.sign_out_24_regular, size: 18),
            label: Text('ログアウト'),
          ),
        ],
      ),
      Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(),
      ),
      Text('アカウントの削除', style: FlText.body1Strong),
      SizedBox(height: 4),
      Text('アカウントと、クラウドに保存した予定・タスク・カレンダーをすべて削除します。元に戻せません。',
          style: FlText.caption1.copyWith(color: Fl.fg3)),
      SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Fl.danger),
          onPressed: _busy
              ? null
              : () async {
                  final ok = await showFlConfirm(
                    context,
                    title: 'アカウントを削除しますか？',
                    message: 'クラウドに保存したデータはすべて消え、元に戻せません。',
                    confirmLabel: '削除',
                  );
                  if (ok) await _run(acc.deleteAccount);
                },
          icon: Icon(FluentIcons.delete_24_regular, size: 18),
          label: Text('アカウントを削除'),
        ),
      ),
    ];
  }
}
