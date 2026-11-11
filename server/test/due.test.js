import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dueItems, payloadOf, windowStart } from '../due.js';

test('時刻の来たものだけ、送り済みは除く', () => {
  const items = [
    { k: 'a', at: 100, t: 'A', b: '' },
    { k: 'b', at: 200, t: 'B', b: '' },
    { k: 'c', at: 300, t: 'C', b: '' },
  ];
  assert.deepEqual(dueItems(items, 100, 250).map((i) => i.k), ['b']);
  assert.deepEqual(dueItems(items, 0, 300, new Set(['c|300'])).map((i) => i.k), ['a', 'b']);
  assert.deepEqual(dueItems(undefined, 0, 1), []);
});

test('止まっていた分は10分までさかのぼる', () => {
  const now = 10_000_000;
  assert.equal(windowStart(null, now), now - 600_000);
  assert.equal(windowStart(now - 60_000, now), now - 60_000);
  assert.equal(windowStart(now - 3_600_000, now), now - 600_000);
});

test('送る中身', () => {
  const p = JSON.parse(payloadOf({ k: 'e:1', at: 1, t: 'ゼミ', b: '今日 13:00' }, 'https://x/'));
  assert.deepEqual(p, { title: 'ゼミ', body: '今日 13:00', tag: 'e:1', url: 'https://x/' });
});
