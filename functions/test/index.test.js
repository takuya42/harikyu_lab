const { test } = require('node:test');
const assert = require('node:assert/strict');
const functions = require('../index');

test('both existing account deletion Functions remain exported', () => {
  assert.equal(typeof functions.deleteCurrentUserAccount, 'function');
  assert.equal(typeof functions.cleanupUserFirestoreData, 'function');
});

test('existing account deletion still rejects unauthenticated requests', async () => {
  await assert.rejects(functions.deleteCurrentUserAccount.run({ data: {}, auth: null }),
    error => error.code === 'unauthenticated');
});
