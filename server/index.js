// スケジュール確認アプリの通知サーバー（Railway で常時動かす）
//
// しくみ:
//   - アプリはログイン中、これから鳴らす通知の一覧を users/{uid}/pushQueue/main に書く
//   - 通知を受け取る端末は users/{uid}/pushSubs/{id} に購読情報を書く
//   - このサーバーは両方をリアルタイムに見ておき、1分ごとに時刻の来たものを Web プッシュで送る
//
// 環境変数:
//   FIREBASE_SERVICE_ACCOUNT  Firebase の「サービスアカウントの秘密鍵」JSON（中身をそのまま、または base64）
//   APP_URL                   通知を押したときに開く URL（省略時は GitHub Pages）
//   VAPID_SUBJECT             連絡先（mailto:... 省略可）
//   PORT                      状態確認用（Railway が自動で設定）

import http from 'node:http';
import admin from 'firebase-admin';
import webpush from 'web-push';
import { dueItems, payloadOf, windowStart } from './due.js';

const APP_URL = process.env.APP_URL || 'https://kami2news.github.io/schedule-check/';

function serviceAccount() {
  const raw = (process.env.FIREBASE_SERVICE_ACCOUNT || '').trim();
  if (!raw) {
    console.error('FIREBASE_SERVICE_ACCOUNT が設定されていません');
    process.exit(1);
  }
  const text = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
  return JSON.parse(text);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount()) });
const db = admin.firestore();

// ---- VAPID 鍵（初回に作って Firestore の非公開の場所に保存。公開鍵だけアプリに見せる） ----
async function setupVapid() {
  const privRef = db.collection('serverPrivate').doc('vapid');
  let pub = process.env.VAPID_PUBLIC_KEY;
  let priv = process.env.VAPID_PRIVATE_KEY;
  if (!pub || !priv) {
    const snap = await privRef.get();
    if (snap.exists) {
      ({ publicKey: pub, privateKey: priv } = snap.data());
    } else {
      const keys = webpush.generateVAPIDKeys();
      pub = keys.publicKey;
      priv = keys.privateKey;
      await privRef.set({ publicKey: pub, privateKey: priv, createdAt: new Date() });
      console.log('VAPID 鍵を新しく作りました');
    }
  }
  webpush.setVapidDetails(process.env.VAPID_SUBJECT || 'mailto:noreply@example.com', pub, priv);
  await db.collection('public').doc('push').set({ vapidPublicKey: pub, updatedAt: new Date() });
}

// ---- リアルタイムに持っておくデータ ----
const queues = new Map(); // uid -> items
const subs = new Map(); // uid -> Map(docId -> {ref, sub})
const sent = new Map(); // `${k}|${at}` -> 送った時刻（重複防止）
let lastRun = null;
let stats = { sent: 0, failed: 0, removed: 0 };

const uidOf = (ref) => ref.parent.parent.id;

function watch() {
  db.collectionGroup('pushQueue').onSnapshot(
    (snap) => {
      for (const ch of snap.docChanges()) {
        const uid = uidOf(ch.doc.ref);
        if (ch.type === 'removed') queues.delete(uid);
        else queues.set(uid, ch.doc.data().items || []);
      }
    },
    (e) => console.error('pushQueue の監視に失敗:', e.message),
  );

  db.collectionGroup('pushSubs').onSnapshot(
    (snap) => {
      for (const ch of snap.docChanges()) {
        const uid = uidOf(ch.doc.ref);
        const m = subs.get(uid) || new Map();
        if (ch.type === 'removed') m.delete(ch.doc.id);
        else {
          const d = ch.doc.data();
          m.set(ch.doc.id, { ref: ch.doc.ref, sub: { endpoint: d.endpoint, keys: d.keys } });
        }
        if (m.size) subs.set(uid, m);
        else subs.delete(uid);
      }
    },
    (e) => console.error('pushSubs の監視に失敗:', e.message),
  );

  // アプリの「テスト通知」ボタン
  db.collectionGroup('pushTest').onSnapshot(
    (snap) => {
      for (const ch of snap.docChanges()) {
        if (ch.type === 'removed') continue;
        const uid = uidOf(ch.doc.ref);
        const item = { k: `test-${Date.now()}`, t: 'テスト通知', b: '通知の設定ができています' };
        sendToUser(uid, item)
          .catch((e) => console.error('テスト通知に失敗:', e.message))
          .finally(() => ch.doc.ref.delete().catch(() => {}));
      }
    },
    (e) => console.error('pushTest の監視に失敗:', e.message),
  );
}

async function sendToUser(uid, item) {
  const m = subs.get(uid);
  if (!m) return;
  await Promise.all(
    [...m.values()].map(async ({ ref, sub }) => {
      try {
        await webpush.sendNotification(sub, payloadOf(item, APP_URL), { TTL: 3600, urgency: 'high' });
        stats.sent++;
      } catch (e) {
        // 端末側で購読が消えている（アプリ削除・許可の取り消しなど）
        if (e.statusCode === 404 || e.statusCode === 410) {
          await ref.delete().catch(() => {});
          stats.removed++;
        } else {
          stats.failed++;
          console.error(`送信に失敗 (${e.statusCode || ''}):`, e.body || e.message);
        }
      }
    }),
  );
}

async function tick() {
  const now = Date.now();
  const from = windowStart(lastRun, now);
  const sentKeys = new Set(sent.keys());
  for (const uid of subs.keys()) {
    for (const item of dueItems(queues.get(uid), from, now, sentKeys)) {
      sent.set(`${item.k}|${item.at}`, now);
      await sendToUser(uid, item);
    }
  }
  lastRun = now;
  // 1日より古い送信記録は捨てる
  for (const [k, t] of sent) if (now - t > 86400000) sent.delete(k);
  await db.collection('serverPrivate').doc('state').set({ lastRun: now }, { merge: true });
}

function loop() {
  // 毎分 0 秒の少し後に動かす
  const wait = 60000 - (Date.now() % 60000) + 1000;
  setTimeout(async () => {
    try {
      await tick();
    } catch (e) {
      console.error('確認に失敗:', e.message);
    }
    loop();
  }, wait);
}

// 状態確認用（予定の中身は出さない）
http
  .createServer((req, res) => {
    res.writeHead(200, { 'content-type': 'application/json; charset=utf-8' });
    res.end(
      JSON.stringify({
        ok: true,
        users: subs.size,
        queues: queues.size,
        lastRun: lastRun && new Date(lastRun).toISOString(),
        ...stats,
      }),
    );
  })
  .listen(process.env.PORT || 8080);

const state = await db.collection('serverPrivate').doc('state').get();
lastRun = state.exists ? state.data().lastRun : null;
await setupVapid();
watch();
loop();
console.log('通知サーバーを起動しました');
