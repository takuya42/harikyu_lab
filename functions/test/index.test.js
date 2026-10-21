const { test } = require('node:test');
const assert = require('node:assert/strict');
const functions = require('../index');

test('Webhook and both existing account deletion Functions remain exported', () => {
  assert.equal(typeof functions.revenueCatWebhook, 'function');
  assert.equal(typeof functions.deleteCurrentUserAccount, 'function');
  assert.equal(typeof functions.cleanupUserFirestoreData, 'function');
  assert.deepEqual(functions.revenueCatWebhook.__endpoint.secretEnvironmentVariables.map(s => s.key),
    ['REVENUECAT_WEBHOOK_AUTHORIZATION', 'DEVELOPER_FCM_TOKEN']);
});

test('existing account deletion still rejects unauthenticated requests', async () => {
  await assert.rejects(functions.deleteCurrentUserAccount.run({ data: {}, auth: null }),
    error => error.code === 'unauthenticated');
});
