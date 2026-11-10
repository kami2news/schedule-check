# デザイン標準（Fluent 2 準拠 + アレンジ）

このアプリの標準デザインは **Microsoft Fluent 2**（https://fluent2.microsoft.design）をベースにする。
独自のアレンジを加えたときは、このファイルの「アレンジ記録」を更新すること。
実装上の正は `lib/ui/fluent.dart`（トークン・テーマ・共通部品）と `lib/ui/fluent_extras.dart`。

## ベース（Fluent 2 のまま使うもの）

| 項目 | 値 |
|---|---|
| ブランド色 | `#0F6CBD`（hover `#115EA3` / pressed `#0C3B5E` / 淡色 `#EBF3FC`） |
| 文字色 | fg1 `#242424` / fg2 `#424242` / fg3 `#616161` |
| 背景 | bg1 `#FFFFFF` / bg2 `#FAFAFA` / bg3 `#F5F5F5`（キャンバス） |
| 罫線 | stroke1 `#D1D1D1` / stroke2 `#E0E0E0` |
| 状態色 | danger `#B10E1C` / warning `#BC4B09` / success `#0E700E` |
| 角丸 | 2 / 4（コントロール） / 8（パネル・ダイアログ） |
| 影 | shadow2・4・8・16・64（key + ambient の2層） |
| 文字 | caption2 10/14、caption1 12/16、body1 14/20、subtitle2 16/22、subtitle1 20/28、title3 24/32。強調は Semibold(600) |
| コントロール | 高さ32px、リップルなし、hover/pressed は背景色の変化で示す |
| 入力欄 | 外枠1px + 下辺を強調、フォーカスで下辺がブランド色2px |
| ダイアログ | 角丸8、shadow64、暗幕40%、主ボタンを左に置く |
| アイコン | Fluent System Icons（通常は regular、選択中は filled） |

## アレンジ記録

- フォント: Segoe UI は再配布できないため、互換の Selawik（Light/Regular/Semibold/Bold、SIL OFL）を同梱。日本語は OS のフォントにフォールバック。
- 予定の色: シフト `#CA5010` / 授業 `#4F6BED` / 予定 `#038387`。ブロックは色の14%の淡い塗り + 左4pxのアクセントバー。
- タスクカード: To Do に合わせ、白カード + shadow2 を bg2 の上に置く。重要マークは黄色ではなくブランド色の星。
- 時刻の選択: Material の時計ではなく、Outlook 風の15分刻みリスト。
- 日付の選択: Material の日付ピッカーを Fluent の色・角丸4で上書きしたもの（完全な Fluent 部品ではない）。
- 画面遷移: 短いフェード + 上方向スライド。
- 週の始まりは日曜。時間グリッドは1時間56px、30分の補助線あり。
