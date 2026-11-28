import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../sharing.dart';
import '../sync/sharing_service.dart';
import 'fluent.dart';
import 'fluent_extras.dart';

/// 設定の「予定の共有」。リンクで共有（表示のみ・AI に渡す用）と、メールで招待（表示のみ／編集可）
class SharingSection extends StatefulWidget {
  const SharingSection({super.key, required this.sharing, required this.myEmail});

  final SharingService sharing;
  final String myEmail;

  @override
  State<SharingSection> createState() => _SharingSectionState();
}

class _SharingSectionState extends State<SharingSection> {
  final _email = TextEditingController();
  bool _canEdit = false;
  String? _inviteError;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$whatをコピーしました')));
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('保存できませんでした。通信状態を確かめて、もう一度試してください（$e）')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final e = _email.text.trim().toLowerCase();
    String? err;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      err = 'メールアドレスの形になっていません';
    } else if (e == widget.myEmail.toLowerCase()) {
      err = '自分のメールアドレスは招待できません';
    }
    setState(() => _inviteError = err);
    if (err != null) return;
    await _run(() => widget.sharing.invite(e, canEdit: _canEdit));
    _email.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sharing,
      builder: (context, _) {
        final s = widget.sharing;
        final token = s.linkToken;
        String role(bool edit) => edit ? '編集可' : '表示のみ';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.error != null) ...[
              Row(children: [
                FlIcon(FluentIcons.error_circle_16_filled, size: 16, color: Fl.danger),
                SizedBox(width: 6),
                Expanded(
                    child: Text(s.error!,
                        style: FlText.caption1.copyWith(color: Fl.danger))),
              ]),
              SizedBox(height: 8),
            ],

            // ---- リンクで共有 ----
            Text('リンクで共有（表示のみ・AI に渡す用）', style: FlText.body1Strong),
            SizedBox(height: 4),
            Text(
                '自分の予定（7日前〜90日先）と未完了のタスクを、リンクを知っている人が見られるようにします。'
                'メモと会議のリンクは含めません。予定を変えると数秒で中身も変わります。',
                style: FlText.caption1.copyWith(color: Fl.fg2)),
            SizedBox(height: 8),
            if (token == null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(s.createLink),
                  icon: FlIcon(FluentIcons.link_24_regular, size: 16),
                  label: Text('共有リンクを作る'),
                ),
              )
            else ...[
              _LinkRow(
                label: 'AI に渡すリンク',
                note: '予定を文章で返します。ChatGPT や Claude などに「このリンクの予定を読んで」と渡します',
                onCopy: () => _copy(SharingService.aiUrl(token), 'AI に渡すリンク'),
              ),
              _LinkRow(
                label: '閲覧用のリンク',
                note: '人が見る用のページ（ログイン不要）',
                onCopy: () => _copy(SharingService.viewUrl(token), '閲覧用のリンク'),
              ),
              SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 4, children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await showFlConfirm(context,
                              title: 'リンクを作り直す',
                              message: '今のリンクは見られなくなります。渡した相手には新しいリンクを渡し直してください。',
                              confirmLabel: '作り直す');
                          if (ok) await _run(s.createLink);
                        },
                  child: Text('リンクを作り直す'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Fl.danger),
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await showFlConfirm(context,
                              title: 'リンクでの共有を終える',
                              message: 'リンクを知っている人も、AI も、予定を見られなくなります。',
                              confirmLabel: '共有を終える');
                          if (ok) await _run(s.deleteLink);
                        },
                  child: Text('リンクでの共有を終える'),
                ),
              ]),
            ],
            SizedBox(height: 16),

            // ---- メールで招待 ----
            Text('メールで招待（表示のみ／編集可）', style: FlText.body1Strong),
            SizedBox(height: 4),
            Text(
                '招待した人が同じメールアドレスでこのアプリにログインすると、その人の「共有されたカレンダー」に'
                'あなたの予定が出ます。「編集可」の人は予定を追加・変更・削除できます（タスクと設定は共有しません）。'
                '招待のメールは送られないので、アプリのアドレスを伝えてください。',
                style: FlText.caption1.copyWith(color: Fl.fg2)),
            SizedBox(height: 8),
            for (final m in s.members)
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    FlIcon(FluentIcons.person_24_regular, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(m.email,
                            overflow: TextOverflow.ellipsis, style: FlText.body1)),
                    SizedBox(
                      width: 128,
                      child: FlDropdown<bool>(
                        items: const [false, true],
                        value: m.canEdit,
                        labelOf: role,
                        onChanged: (v) => _run(() => s.setCanEdit(m.email, v)),
                      ),
                    ),
                    IconButton(
                      tooltip: '${m.email} の招待を外す',
                      icon: FlIcon(FluentIcons.dismiss_24_regular, size: 16),
                      onPressed: _busy ? null : () => _run(() => s.removeMember(m.email)),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FlTextField(
                    key: ValueKey('share-email'),
                    controller: _email,
                    hint: '相手のメールアドレス',
                    onSubmitted: (_) => _invite(),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 128,
                  child: FlDropdown<bool>(
                    items: const [false, true],
                    value: _canEdit,
                    labelOf: role,
                    onChanged: (v) => setState(() => _canEdit = v),
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _invite,
                  child: Text('招待'),
                ),
              ],
            ),
            if (_inviteError != null) ...[
              SizedBox(height: 4),
              Text(_inviteError!, style: FlText.caption1.copyWith(color: Fl.danger)),
            ],
          ],
        );
      },
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.note, required this.onCopy});

  final String label;
  final String note;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: FlText.body1),
                Text(note, style: FlText.caption1.copyWith(color: Fl.fg3)),
              ],
            ),
          ),
          SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onCopy,
            icon: FlIcon(FluentIcons.copy_24_regular, size: 16),
            label: Text('コピー'),
          ),
        ],
      ),
    );
  }
}

/// 共有リンクの閲覧ページ（?share=… で開いたとき。ログイン不要・表示のみ）
class SharedLinkPage extends StatefulWidget {
  const SharedLinkPage({super.key, required this.token, this.loader});

  final String token;

  /// テスト用に差し替えられる読み込み
  final Future<({String ownerName, String text, List<ShareItem> items, DateTime? updatedAt})?>
      Function(String token)? loader;

  @override
  State<SharedLinkPage> createState() => _SharedLinkPageState();
}

class _SharedLinkPageState extends State<SharedLinkPage> {
  late final _future = (widget.loader ?? loadSharedLink)(widget.token);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Fl.bg2,
      body: SafeArea(
        child: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Center(child: Text('読み込んでいます…', style: FlText.body1));
            }
            final d = snap.data;
            if (snap.hasError || d == null) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'この共有リンクは見られません。共有が終わったか、リンクが作り直された可能性があります。',
                      style: FlText.body1),
                ),
              );
            }
            final today = DateTime.now();
            final items = d.items;
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text('${d.ownerName.isEmpty ? '共有' : d.ownerName}さんの予定',
                    style: FlText.title3),
                SizedBox(height: 4),
                Text(
                    '表示のみ${d.updatedAt == null ? '' : '・${fmtUpdated(d.updatedAt!)} 時点'}',
                    style: FlText.caption1.copyWith(color: Fl.fg3)),
                SizedBox(height: 8),
                // 自分のカレンダーに仮に置いて、重なるかを見る（保存はしない）
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => launchUrl(
                        Uri.base.replace(queryParameters: {'compare': widget.token}),
                        webOnlyWindowName: '_self'),
                    child: Text('自分の予定と比べる'),
                  ),
                ),
                SizedBox(height: 12),
                if (items.isEmpty) Text('予定はありません', style: FlText.body1),
                for (var i = 0; i < items.length; i++) ...[
                  if (i == 0 || items[i].date != items[i - 1].date)
                    Padding(
                      padding: EdgeInsets.only(top: 12, bottom: 4),
                      child: Text(
                        '${fmtLongDate(items[i].date)}${_sameDay(items[i].date, today) ? '（今日）' : ''}',
                        style: FlText.body1Strong.copyWith(
                            color: weekendFg(items[i].date) ?? Fl.fg1),
                      ),
                    ),
                  _ItemRow(item: items[i]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

String fmtUpdated(DateTime t) =>
    '${fmtLongDate(t)} ${fmtMin(t.hour * 60 + t.minute)}';

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final ShareItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Fl.bg1,
        borderRadius: BorderRadius.circular(Fl.r4),
        border: Border(left: BorderSide(color: Color(item.color), width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: FlText.body1Strong),
          Text(
            '${item.timeLabel}・${item.calendar}${item.place.isEmpty ? '' : '・${item.place}'}',
            style: FlText.caption1.copyWith(color: Fl.fg2),
          ),
        ],
      ),
    );
  }
}
