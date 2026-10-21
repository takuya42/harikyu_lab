const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createRevenueCatHandler } = require('../revenuecat');

function setup({ renewals = false, failSend = false, failTransaction = false, failUpdate = false,
  secret = 'Bearer test-secret', token = 'developer-only-token' } = {}) {
  const records = new Map();
  const messages = [];
  let queue = Promise.resolve();
  const db = {
    collection(name) {
      assert.equal(name, 'revenuecat_notification_events');
      return { doc(id) {
        assert.match(id, /^[a-f0-9]{64}$/);
        return { id, async update(fields) {
          if (failUpdate) throw new Error('Firestore unavailable');
          records.set(id, { ...records.get(id), ...fields });
        } };
      } };
    },
    runTransaction(fn) {
      const result = queue.then(async () => {
        if (failTransaction) throw new Error('Firestore unavailable');
        return fn({
          async get(ref) { return { exists: records.has(ref.id) }; },
          create(ref, value) {
            assert.equal(records.has(ref.id), false);
            records.set(ref.id, value);
          },
        });
      });
      queue = result.catch(() => {});
      return result;
    },
  };
  const handler = createRevenueCatHandler({
    db,
    messaging: { async send(message) {
      messages.push(message);
      if (failSend) throw new Error('FCM unavailable');
      return 'message-123';
    } },
    authorization: () => secret,
    token: () => token,
    notifyRenewals: () => renewals,
  });
  async function request(type = 'INITIAL_PURCHASE', options = {}) {
    const req = {
      method: options.method ?? 'POST',
      get: () => Object.hasOwn(options, 'authorization') ? options.authorization : 'Bearer test-secret',
      body: Object.hasOwn(options, 'body') ? options.body : {
        event: { id: options.id ?? 'event-1', type },
      },
    };
    const res = { status(code) { this.code = code; return this; },
      send(body) { this.body = body; return this; } };
    await handler(req, res);
    return res;
  }
  return { request, records, messages };
}

for (const type of ['INITIAL_PURCHASE', 'NON_RENEWING_PURCHASE']) {
  test(`${type}: sends the exact purchase notification directly to the developer`, async () => {
    const s = setup();
    assert.equal((await s.request(type)).code, 200);
    assert.deepEqual(s.messages, [{ token: 'developer-only-token', notification: {
      title: '🎉 新しい課金がありました',
      body: 'はりきゅうラボ Proが購入されました！',
    } }]);
    assert.equal([...s.records.values()][0].status, 'sent');
  });
  test(`${type}: duplicate event ID does not send again`, async () => {
    const s = setup();
    await s.request(type);
    assert.equal((await s.request(type)).body, 'Duplicate');
    assert.equal(s.messages.length, 1);
  });
}

test('RENEWAL is disabled by default', async () => {
  const s = setup();
  assert.equal((await s.request('RENEWAL')).body, 'Ignored');
  assert.equal(s.messages.length, 0);
  assert.equal(s.records.size, 0);
});
test('RENEWAL is notified only when enabled', async () => {
  const s = setup({ renewals: true });
  await s.request('RENEWAL');
  assert.equal(s.messages.length, 1);
});
test('other event types never send purchase notifications', async () => {
  const s = setup({ renewals: true });
  for (const type of ['CANCELLATION', 'EXPIRATION', 'BILLING_ISSUE', 'TEST', 'TRANSFER', 'UNKNOWN']) {
    assert.equal((await s.request(type)).body, 'Ignored');
  }
  assert.equal(s.messages.length, 0);
  assert.equal(s.records.size, 0);
});
test('incorrect and missing Authorization are rejected before recording', async () => {
  const s = setup();
  for (const authorization of ['wrong', '', undefined, 'Bearer test-secret ']) {
    assert.equal((await s.request(undefined, { authorization })).code, 401);
  }
  assert.equal(s.records.size, 0);
  assert.equal(s.messages.length, 0);
});
test('missing configured Authorization fails closed', async () => {
  const s = setup({ secret: '' });
  assert.equal((await s.request()).code, 401);
  assert.equal(s.messages.length, 0);
});
test('non-POST requests are rejected', async () => {
  const s = setup();
  assert.equal((await s.request(undefined, { method: 'GET' })).code, 405);
  assert.equal(s.messages.length, 0);
});
test('malformed payloads are rejected', async () => {
  const s = setup();
  for (const body of [null, {}, { event: {} }, { event: { id: ' ', type: 'INITIAL_PURCHASE' } },
    { event: { id: 123, type: 'INITIAL_PURCHASE' } }, { event: { id: 'id' } }]) {
    assert.equal((await s.request(undefined, { body })).code, 400);
  }
  assert.equal(s.messages.length, 0);
});
test('concurrent duplicate requests send once', async () => {
  const s = setup();
  const results = await Promise.all([s.request(), s.request(), s.request()]);
  assert.equal(results.filter(r => r.body === 'Sent').length, 1);
  assert.equal(s.messages.length, 1);
});
test('different event IDs each send', async () => {
  const s = setup();
  await s.request(undefined, { id: 'id-1' });
  await s.request(undefined, { id: 'id-2' });
  assert.equal(s.messages.length, 2);
});
test('FCM failure retains claim and does not resend', async () => {
  const s = setup({ failSend: true });
  assert.equal((await s.request()).code, 500);
  assert.equal([...s.records.values()][0].status, 'delivery_uncertain');
  assert.equal((await s.request()).body, 'Duplicate');
  assert.equal(s.messages.length, 1);
});
test('Firestore transaction failure prevents FCM send', async () => {
  const s = setup({ failTransaction: true });
  assert.equal((await s.request()).code, 500);
  assert.equal(s.messages.length, 0);
});
test('missing developer token does not claim an event', async () => {
  const s = setup({ token: '' });
  assert.equal((await s.request()).code, 500);
  assert.equal(s.records.size, 0);
  assert.equal(s.messages.length, 0);
});
test('post-send Firestore failure does not cause a duplicate notification', async () => {
  const s = setup({ failUpdate: true });
  assert.equal((await s.request()).code, 500);
  assert.equal((await s.request()).body, 'Duplicate');
  assert.equal(s.messages.length, 1);
});
