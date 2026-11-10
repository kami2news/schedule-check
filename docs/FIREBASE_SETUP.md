# Firebase の設定手順（FlutterFire 方式・Web とスマホアプリ共通）

アプリ側のログイン・同期の実装は済んでいます。Firebase の設定ファイル（`lib/firebase_options.dart`）が仮のあいだは、今まで通り端末内だけで動きます。
以下を行うと、Web（GitHub Pages）と iPhone / Android アプリの両方でログインと同期が有効になります。料金は無料プラン（Spark）の範囲で足ります。

## A. Firebase コンソールでの準備

### 1. プロジェクトを作る
https://console.firebase.google.com →「プロジェクトを作成」。名前は `schedule-check` など。Google アナリティクスはオフで可。
（アプリの登録は B の `flutterfire configure` が自動で行うので、コンソールでは不要）

### 2. ログイン方法を有効にする
構築 → Authentication →「始める」→ Sign-in method
- **メール / パスワード**: 有効にする
- **Google**: 有効にする（サポートメールに自分の Gmail）
- **Microsoft**: 2-1 の Azure 登録をしてから有効にする

#### 2-1. Microsoft ログイン用の Azure 登録
1. https://portal.azure.com →「アプリの登録」→「新規登録」
2. サポートされているアカウントの種類: **任意の組織ディレクトリ内のアカウントと個人の Microsoft アカウント**
3. リダイレクト URI: プラットフォーム「Web」、値は Firebase の Microsoft 設定画面に出る `https://<プロジェクトID>.firebaseapp.com/__/auth/handler`
4. 「アプリケーション（クライアント）ID」と、「証明書とシークレット」で作った **シークレットの値** を Firebase の Microsoft プロバイダに入れて保存

### 3. 承認済みドメインを追加（Web 版用）
Authentication → 設定 → 承認済みドメイン → `kami2news.github.io` を追加

### 4. Firestore を作る
構築 → Firestore Database →「データベースを作成」→ ロケーション `asia-northeast1（東京）`、本番環境モード →「ルール」タブにリポジトリの `firestore.rules` を貼って「公開」

## B. Mac での作業（ターミナル）

### 5. ツールを入れる（初回だけ）
```sh
npm install -g firebase-tools        # Node が無ければ: curl -sL https://firebase.tools | bash
firebase login
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"   # ~/.zshrc にも追記しておく
```

### 6. リポジトリを取得して、スマホ用のフォルダを作る
```sh
git clone https://github.com/kami2news/schedule-check.git
cd schedule-check
flutter create . --platforms android,ios,web --project-name schedule_check --org io.github.kami2news
```
`--org` はアプリの ID（Android: `io.github.kami2news.schedule_check` / iOS: `io.github.kami2news.scheduleCheck`）になります。あとから変えにくいので、変えたい場合はここで決めてください。

### 7. Firebase と接続する
```sh
flutterfire configure --project=<プロジェクトID> --platforms=android,ios,web
```
`lib/firebase_options.dart`（仮のファイルを上書き）・`android/app/google-services.json`・`ios/Runner/GoogleService-Info.plist`・`firebase.json` が作られ、Firebase 側にも Android / iOS / Web のアプリが登録されます。

### 8. Android の Google ログイン用の指紋を登録
```sh
cd android && ./gradlew signingReport && cd ..
```
出てきた `SHA1` と `SHA-256`（Variant: debug）を、Firebase コンソール → プロジェクトの設定 → Android アプリ →「フィンガープリントを追加」に登録し、もう一度 `flutterfire configure`（7 と同じ）を実行。

### 9. push する
```sh
git add -A
git commit -m "Add Firebase configuration and mobile platforms"
git push
```
push 後、iOS のログイン用 URL スキームや Android のリンク設定など、残りのネイティブ側の調整はこちらで行います。

## データの置き場所
- `users/{uid}/events/{予定のid}`
- `users/{uid}/tasks/{タスクのid}`
- `users/{uid}/calendars/{カレンダーのid}`（`order` で並び順）

## 動き
- ログインしていないとき: これまで通り端末内だけに保存
- ログイン中: クラウドに保存し、ほかの端末と同期。オフラインでも使え、つながったときに同期
- 初めてログインしたとき: 端末内のデータをアカウントに移すか確認
- ログアウト: 端末内（ログインしていないとき）のデータに戻る
- アカウント削除: クラウドのデータとアカウントを削除
- ログイン画面: Web はポップアップ、スマホアプリはアプリ内のブラウザ画面
