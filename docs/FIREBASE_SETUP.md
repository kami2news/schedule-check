# Firebase の設定手順（オンライン同期・ログイン）

アプリ側の実装は済んでいます。以下を Firebase コンソールで行い、最後の「Web アプリの設定値」を `lib/sync/firebase_config.dart` に入れるとログインと同期が有効になります。設定値が空のあいだは、今まで通り端末内だけで動きます。

料金は無料プラン（Spark）の範囲で足ります。

## 1. プロジェクトを作る
1. https://console.firebase.google.com を開き「プロジェクトを作成」
2. 名前は `schedule-check` など。Google アナリティクスはオフで可

## 2. Web アプリを登録して設定値をもらう
1. プロジェクトの概要 →「アプリを追加」→ Web（`</>`）
2. ニックネーム `schedule-check-web`（Firebase Hosting は不要）
3. 表示される `firebaseConfig`（apiKey, authDomain, projectId, storageBucket, messagingSenderId, appId）を控える
   - これらは公開して問題ない識別子です（データはセキュリティルールで保護）

## 3. ログイン方法を有効にする
構築 → Authentication →「始める」→ Sign-in method

- **メール / パスワード**: 有効にする
- **Google**: 有効にする（サポートメールに自分の Gmail を選ぶ）
- **Microsoft**: 下の 3-1 で Azure の登録をしてから有効にする

### 3-1. Microsoft ログイン用の Azure 登録
1. https://portal.azure.com →「アプリの登録」→「新規登録」
2. サポートされているアカウントの種類: **任意の組織ディレクトリ内のアカウントと個人の Microsoft アカウント**
3. リダイレクト URI: プラットフォーム「Web」、値は Firebase の Microsoft 設定画面に表示される
   `https://<プロジェクトID>.firebaseapp.com/__/auth/handler`
4. 登録後「アプリケーション（クライアント）ID」を控える
5. 「証明書とシークレット」→「新しいクライアント シークレット」→ **値** を控える
6. Firebase の Microsoft プロバイダに ID とシークレットを入れて保存

## 4. 承認済みドメインを追加
Authentication → 設定 → 承認済みドメイン →「ドメインを追加」→ `kami2news.github.io`

## 5. Firestore を作る
1. 構築 → Firestore Database →「データベースを作成」
2. ロケーション: `asia-northeast1（東京）`、本番環境モード
3. 「ルール」タブに、リポジトリの `firestore.rules` の内容を貼り付けて「公開」

## 6. 設定値をアプリに入れる
`lib/sync/firebase_config.dart` の空欄に 2 で控えた値を入れて push すると、GitHub Actions がビルドして公開します。

## データの置き場所
- `users/{uid}/events/{予定のid}`
- `users/{uid}/tasks/{タスクのid}`
- `users/{uid}/calendars/{カレンダーのid}`（`order` で並び順）

## 動き
- ログインしていないとき: これまで通り端末内（ブラウザ）だけに保存
- ログイン中: クラウドに保存し、ほかの端末と同期。オフラインでも使え、つながったときに同期
- 初めてログインしたとき: 端末内のデータをアカウントに移すか確認
- ログアウト: 端末内（ログインしていないとき）のデータに戻る
- アカウント削除: クラウドのデータとアカウントを削除
