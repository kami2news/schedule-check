import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

String? _last;

/// ページそのもの（html・body）の地の色と theme-color を、画面のいちばん上の色にそろえる。
/// iPhone でホーム画面から開いたとき、時計・電池の帯（ステータスバー）の後ろにはページの地の色が出るため、
/// そろえないと白い帯が残る
void setPageColor(Color c) {
  final hex = '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  if (hex == _last) return;
  _last = hex;
  try {
    web.document.documentElement?.setAttribute('style', 'background-color: $hex');
    web.document.body?.style.backgroundColor = hex;
    var meta = web.document.querySelector('meta[name="theme-color"]');
    if (meta == null) {
      meta = web.document.createElement('meta')..setAttribute('name', 'theme-color');
      web.document.head?.append(meta);
    }
    meta.setAttribute('content', hex);
  } catch (_) {}
}
