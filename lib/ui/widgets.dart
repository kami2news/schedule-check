import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import 'fluent.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 16, 0, 6),
      child: Text(text,
          style: FlText.body1Strong.copyWith(color: color ?? Fl.fg1)),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: FlText.body1.copyWith(color: Fl.fg3)),
    );
  }
}

/// 期限までの残りを「あと3日」などで表す
({String text, Color? color}) dueInfo(BuildContext context, TaskItem t) {
  if (t.due == null) return (text: '期限なし', color: null);
  final today = dateOnly(DateTime.now());
  final diff = dateOnly(t.due!).difference(today).inDays;
  final time = t.dueMin == null ? '' : ' ${fmtMin(t.dueMin!)}';
  final base = '${fmtDate(t.due!)}$time';
  if (t.done) return (text: base, color: null);
  if (diff < 0) return (text: '$base  ${-diff}日超過', color: Fl.danger);
  if (diff == 0) return (text: '$base  今日まで', color: Fl.warning);
  if (diff == 1) return (text: '$base  明日まで', color: Fl.warning);
  return (text: '$base  あと$diff日', color: null);
}

/// リンクを新しいタブ（アプリでは外部アプリ）で開く。開けなければ通知する。
Future<void> openLink(BuildContext context, String url) async {
  var u = url.trim();
  if (u.isEmpty) return;
  if (!u.startsWith(RegExp(r'https?://', caseSensitive: false))) {
    u = 'https://$u';
  }
  final uri = Uri.tryParse(u);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri,
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger?.showSnackBar(
        SnackBar(content: Text('リンクを開けませんでした')));
  }
}

/// リンクの種類に合わせたアイコン（会議ならビデオ、それ以外はリンク）
IconData linkIcon(String url, {bool small = false}) {
  if (isMeetingLink(url)) {
    return small ? FluentIcons.video_16_regular : FluentIcons.video_24_regular;
  }
  return small ? FluentIcons.link_16_regular : FluentIcons.link_24_regular;
}

/// 「Zoom に参加」「リンクを開く」ボタン
class FlLinkButton extends StatelessWidget {
  const FlLinkButton({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final label = linkLabel(url);
    return FilledButton.icon(
      onPressed: () => openLink(context, url),
      icon: Icon(linkIcon(url), size: 18),
      label: Text(isMeetingLink(url) ? '$labelに参加' : 'リンクを開く'),
    );
  }
}
