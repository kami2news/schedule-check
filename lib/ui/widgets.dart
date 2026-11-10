import 'package:flutter/material.dart';

import '../models.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(text,
          style: TextStyle(color: Theme.of(context).colorScheme.outline)),
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
  if (diff < 0) return (text: '$base  ${-diff}日超過', color: Colors.red);
  if (diff == 0) return (text: '$base  今日まで', color: Colors.deepOrange);
  if (diff == 1) return (text: '$base  明日まで', color: Colors.orange);
  return (text: '$base  あと$diff日', color: null);
}
