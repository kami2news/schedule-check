// 送る通知の選び方（テストしやすいよう index.js から分けている）

/**
 * キューの中から (from, now] に鳴らすものを選ぶ。
 * 送り済み（sent に key がある）は除く。
 */
export function dueItems(items, from, now, sent = new Set()) {
  return (items || []).filter(
    (i) =>
      i &&
      typeof i.at === 'number' &&
      i.at > from &&
      i.at <= now &&
      !sent.has(`${i.k}|${i.at}`),
  );
}

/** 前回の確認時刻。止まっていた間の分は、最大 catchUpMs までさかのぼる */
export function windowStart(lastRun, now, catchUpMs = 10 * 60 * 1000) {
  const floor = now - catchUpMs;
  return typeof lastRun === 'number' && lastRun > floor ? lastRun : floor;
}

/** 送る中身（Service Worker の push-sw.js が読む） */
export function payloadOf(item, url) {
  return JSON.stringify({ title: item.t || '通知', body: item.b || '', tag: item.k, url });
}
