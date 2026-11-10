import 'package:flutter/widgets.dart';

/// これ以上の幅なら「サイドバー + カレンダー + To Do」の3ペイン表示
const double kWideBreakpoint = 1100;

/// これ以上の幅なら編集画面をダイアログで開く
const double kDialogBreakpoint = 700;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

bool useDialog(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDialogBreakpoint;
