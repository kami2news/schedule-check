# スケジュール確認アプリ (schedule-check)

バイトのシフト・授業（時間割）・締切をまとめて確認する Flutter アプリです。
UI は **Outlook カレンダー + Microsoft To Do** をイメージしています。データは端末（ブラウザ）内に保存されます。

## 画面

- **広い画面（幅 1100px 以上）**: 左サイドバー（新しい予定・ミニカレンダー・表示するカレンダー）＋ 中央カレンダー ＋ 右 To Do の3ペイン
- **狭い画面（スマホ）**: 下のタブで カレンダー / To Do / 取り込み を切り替え

### カレンダー

- 日 / 週 / 月 表示（週は日曜始まり。`lib/models.dart` の `kWeekStartsOnSunday` で変更可）
- 時間グリッド上に予定をブロック表示。重なる予定は横に並ぶ。現在時刻の赤線
- 空き枠をタップするとその時刻で新規作成、予定をタップで編集
- 終日の予定とタスクの期限は上の「終日」行に表示
- 種類（シフト / 授業 / 予定）ごとの色分けと表示のオン・オフ
- 毎週くり返し（時間割・固定シフト）、場所、メモ

### To Do

- リスト: マイデイ（今日が期限・期限切れ）/ 重要 / 期限あり / すべて
- 上部の入力欄からすばやく追加（期限も指定可）
- 丸いチェックで完了、星で「重要」、完了済みは折りたたみ
- 期限がある項目はカレンダーにも表示

### 取り込み

メールや連絡文を貼り付けると、日付つきの行を予定/タスクの候補にして、確認・修正してから登録します。

- 日付: `11/15`、`11月15日`、`2026/11/15`、`今日` `明日` `明後日`
- 時刻: `10:00`、`10時30分`、範囲 `10:00-18:00` / `10時から18時`
- 「締切・提出・期限・まで」→ タスク、「シフト・バイト」→ シフト、「授業・ゼミ・実験」→ 授業
- 年のない日付は今年扱い（半年以上前なら来年）。「来週金曜」のような相対表現は未対応

## 開発

```bash
flutter create .        # android/ ios/ web/ などを生成（lib や pubspec は上書きされません）
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

`main` に push すると GitHub Actions が解析・テスト・Web ビルドを行い、GitHub Pages に公開します
（リポジトリの Settings → Pages → Source を GitHub Actions にしておく）。

## 構成

```
lib/
  main.dart            アプリ本体・レスポンシブなシェル
  models.dart          Event / TaskItem と週の計算
  store.dart           保存と更新 (ChangeNotifier)
  parser.dart          文章 → 予定/タスク候補
  ui/
    controller.dart    カレンダーの選択日・表示形式・絞り込み
    calendar_page.dart ヘッダー + 日/週/月
    time_grid.dart     日・週の時間グリッド
    month_view.dart    月表示
    mini_month.dart    ミニカレンダー
    sidebar.dart       左サイドバー
    todo_panel.dart    To Do パネル
    edit_pages.dart    予定・タスクの編集（広い画面ではダイアログ）
    import_page.dart   取り込み
test/                  解析・表示のテスト
```

## デザイン（Fluent 2）

Microsoft の Fluent 2 デザインシステム（Outlook / Microsoft To Do のスタイル）に合わせています。

- 色・角丸・影・タイプランプは Fluent 2 のトークンを `lib/ui/fluent.dart` に定義
- フォント: Segoe UI 互換の [Selawik](https://github.com/microsoft/Selawik)（SIL OFL、`assets/fonts/`）+ 日本語は各OSのフォントにフォールバック
- アイコン: [Fluent System Icons](https://pub.dev/packages/fluentui_system_icons)
- ボタン（高さ32・角丸4）、タブ、スイッチ、入力欄（下辺が強調）、ダイアログ、予定ブロック（左アクセントバー）などを Fluent 風に自作
