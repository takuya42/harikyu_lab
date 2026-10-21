const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { defineSecret, defineBoolean } = require('firebase-functions/params');
const { createRevenueCatHandler } = require('./revenuecat');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

const revenueCatAuthorization = defineSecret('REVENUECAT_WEBHOOK_AUTHORIZATION');
const developerFcmToken = defineSecret('DEVELOPER_FCM_TOKEN');
const notifyRenewals = defineBoolean('REVENUECAT_NOTIFY_RENEWALS', { default: false });

exports.revenueCatWebhook = onRequest({
  secrets: [revenueCatAuthorization, developerFcmToken],
}, createRevenueCatHandler({
  db,
  messaging: admin.messaging(),
  authorization: () => revenueCatAuthorization.value(),
  token: () => developerFcmToken.value(),
  notifyRenewals: () => notifyRenewals.value(),
}));

async function deleteUserFirestoreData(uid) {
  if (!uid) {
    throw new HttpsError('invalid-argument', 'ユーザーIDが不正です。');
  }

  const userRef = db.collection('users').doc(uid);
  await db.recursiveDelete(userRef);
}

exports.deleteCurrentUserAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'ログインが必要です。');
  }

  try {
    await deleteUserFirestoreData(uid);
  } catch (error) {
    console.error('Failed to delete Firestore user data', { uid, error });
    throw new HttpsError(
      'internal',
      'ユーザーデータの削除に失敗しました。時間をおいてもう一度お試しください。',
    );
  }

  try {
    await auth.deleteUser(uid);
  } catch (error) {
    console.error('Failed to delete Auth user after Firestore cleanup', {
      uid,
      error,
    });
    throw new HttpsError(
      'internal',
      '認証アカウントの削除に失敗しました。時間をおいてもう一度お試しください。',
    );
  }

  return { success: true };
});

exports.cleanupUserFirestoreData = functions.auth.user().onDelete(async (user) => {
  const uid = user && user.uid;
  if (!uid) return;

  try {
    await deleteUserFirestoreData(uid);
  } catch (error) {
    console.error('Failed to cleanup Firestore data on auth delete', {
      uid,
      error,
    });
    throw error;
  }
});
