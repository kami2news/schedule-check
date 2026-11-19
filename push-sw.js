// プッシュ通知の受け取り口（Service Worker）。
// Railway のサーバーから届いた通知を、アプリを閉じていても表示する。
'use strict';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let d = {};
  try {
    d = event.data ? event.data.json() : {};
  } catch (_) {
    d = { body: event.data ? event.data.text() : '' };
  }
  event.waitUntil(
    self.registration.showNotification(d.title || 'スケジュール確認', {
      body: d.body || '',
      tag: d.tag || undefined,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: { url: d.url || './' },
    }),
  );
});

// 通知を押したら、開いているアプリを前に出す（なければ開く）
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || './';
  event.waitUntil(
    (async () => {
      const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const c of all) {
        if ('focus' in c) return c.focus();
      }
      return self.clients.openWindow(url);
    })(),
  );
});
