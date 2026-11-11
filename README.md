# スケジュール確認アプリ (schedule-check)

バイトのシフト・授業（時間割）・締め切りをまとめて確認する Flutter アプリです。
見た目は Microsoft Fluent 2（Outlook カレンダー + Microsoft To Do）に合わせています。

- 公開先: https://kami2news.github.io/schedule-check/ （`main` に push すると自動で更新）
- ログインなしでも使えます（端末内に保存）。ログインすると端末間で同期します。

## できること

| 機能 | 内容 |
|---|---|
| カレンダー | 日・週・月表示、マイカレンダー（名前と色）、表示方法（予定あり・仮・空き時間など）、ライト／ダーク |
| 予定 | 繰り返し（毎日・平日・毎週・隔週・毎月）、「この回のみ／この回以降／すべて」の変更、時限での入力、Zoom などのリンク、メモ |
| プレビュー | 予定を押すと小さなカードで内容・参加リンク・地図・関連タスクを表示 |
| To Do | マイデイ／重要／期限あり／すべて。予定にひも付くタスク（持ち物・終了報告など） |
| 締め切り | 基本は終日。0:00 締め切りは前日の終日、時刻つきはカレンダーのその時刻に印 |
| 取り込み | メールなどの文章を貼ると予定・締め切りの候補に。登録済みの予定と照合（重複・変更・中止・時間の重なり） |
| 検索 | 予定・タスク・場所・メモ |
| 空き時間 | 条件に合う空き時間を探し、候補日を文章でコピー |
| 通知 | 開いている間は画面内とブラウザ通知。閉じていても届く通知は Railway のサーバー経由（Web プッシュ） |
| 同期 | Firebase（Google またはメールアドレスでログイン） |

## 構成

```
lib/
  main.dart              アプリ本体・画面の切り替え
  models.dart            予定・タスク・カレンダー・繰り返し
  store.dart             保存と更新
  parser.dart            文章 → 予定・締め切りの候補
  reconcile.dart         取り込み候補と登録済みの予定の照合
  finder.dart            検索・空き時間
  reminders.dart         通知の時刻の計算
  notify/                開いている間の通知
  push/                  閉じていても届く通知（Web プッシュ）のアプリ側
  sync/                  アカウントと Firebase 同期
  ui/                    画面（Fluent 2 の部品は fluent.dart / fluent_extras.dart）
server/                  通知を送るサーバー（Node.js、Railway 用）
web/                     push.js / push-sw.js（通知の受け取り口）
test/                    テスト
docs/
  FIREBASE_SETUP.md      Firebase の設定
  PUSH_SETUP.md          閉じていても届く通知の設定（Railway）
DESIGN.md                デザインの標準（Fluent 2 とアレンジの記録）
firestore.rules          Firestore のルール
```

## 開発

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run -d chrome

cd server && npm ci && npm test   # 通知サーバー
```

`main` に push すると GitHub Actions が解析・テスト・Web ビルドを行い、GitHub Pages に公開します。
ビルド結果は確認用に `preview-build` ブランチにも置かれます。画面のメニュー（右上の太陽／月のアイコン）に版の番号が出ます。

## デザイン

標準は Microsoft Fluent 2 です。トークンと、このアプリでのアレンジは [DESIGN.md](DESIGN.md) にまとめています。
フォントは Segoe UI 互換の [Selawik](https://github.com/microsoft/Selawik)（SIL OFL）、アイコンは [Fluent System Icons](https://pub.dev/packages/fluentui_system_icons) です。
