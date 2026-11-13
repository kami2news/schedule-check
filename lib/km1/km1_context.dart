// KM1 の km1_widgets.dart にある Km1Context の一部（色だけ）。
// km1_icons_b.dart が context.km1 を使うが km1_widgets.dart を読み込んでいないため、
// このアプリでは km1_widgets.dart（部品一式）の代わりにこれを置く。
import 'package:material_ui/material_ui.dart';

import 'km1_theme.dart';

export 'km1_theme.dart';

/// テーマから KM1 の色を取る / KM1 colors from the theme
extension Km1Context on BuildContext {
  Km1Colors get km1 => Theme.of(this).extension<Km1Colors>() ?? Km1Colors.light;
}
