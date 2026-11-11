// アプリ（Dart）から呼ぶ、プッシュ通知の登録まわり。window.schedulePush に置く
(function () {
  'use strict';

  function keyToBytes(s) {
    const pad = '='.repeat((4 - (s.length % 4)) % 4);
    const raw = atob((s + pad).replace(/-/g, '+').replace(/_/g, '/'));
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  }

  function sameKey(sub, key) {
    try {
      const a = new Uint8Array(sub.options.applicationServerKey);
      const b = keyToBytes(key);
      return a.length === b.length && a.every((x, i) => x === b[i]);
    } catch (_) {
      return true; // 比べられないときはそのまま使う
    }
  }

  const supported = () =>
    'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;

  async function registration() {
    return (await navigator.serviceWorker.getRegistration('./')) || null;
  }

  window.schedulePush = {
    supported,
    isIOS: () => /iPhone|iPad|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1),
    standalone: () =>
      window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true,
    permission: () => ('Notification' in window ? Notification.permission : 'unsupported'),

    // 許可を求めて購読し、購読情報（JSON 文字列）を返す。押した操作の中で呼ぶこと（iPhone の条件）
    async subscribe(key) {
      if (!supported()) throw new Error('unsupported');
      const p = await Notification.requestPermission();
      if (p !== 'granted') throw new Error('permission:' + p);
      await navigator.serviceWorker.register('push-sw.js', { scope: './' });
      const reg = await navigator.serviceWorker.ready;
      let sub = await reg.pushManager.getSubscription();
      if (sub && !sameKey(sub, key)) {
        await sub.unsubscribe();
        sub = null;
      }
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: keyToBytes(key),
        });
      }
      return JSON.stringify(sub);
    },

    // この端末の購読（なければ空文字）
    async current() {
      if (!supported()) return '';
      const reg = await registration();
      const sub = reg && (await reg.pushManager.getSubscription());
      return sub ? JSON.stringify(sub) : '';
    },

    async unsubscribe() {
      if (!supported()) return false;
      const reg = await registration();
      const sub = reg && (await reg.pushManager.getSubscription());
      return sub ? sub.unsubscribe() : false;
    },
  };
})();
