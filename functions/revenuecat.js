const { createHash, timingSafeEqual } = require('node:crypto');

const notification = {
  title: '🎉 新しい課金がありました',
  body: 'はりきゅうラボ Proが購入されました！',
};

function authorized(actual, expected) {
  if (!expected || typeof actual !== 'string') return false;
  const hash = (value) => createHash('sha256').update(value).digest();
  return timingSafeEqual(hash(actual), hash(expected));
}

function createRevenueCatHandler({ db, messaging, authorization, token, notifyRenewals }) {
  return async (req, res) => {
    if (req.method !== 'POST') return res.status(405).send('Method not allowed');
    if (!authorized(req.get('authorization'), authorization())) {
      return res.status(401).send('Unauthorized');
    }
    const event = req.body?.event;
    if (!event || typeof event.id !== 'string' || !event.id.trim() ||
        typeof event.type !== 'string') {
      return res.status(400).send('Invalid event');
    }
    const purchase = ['INITIAL_PURCHASE', 'NON_RENEWING_PURCHASE'].includes(event.type);
    if (!purchase && !(event.type === 'RENEWAL' && notifyRenewals())) {
      return res.status(200).send('Ignored');
    }

    try {
      const deviceToken = token();
      if (!deviceToken) throw new Error('Missing developer device configuration');
      // Hash the ID so arbitrary RevenueCat IDs cannot become Firestore paths.
      const id = createHash('sha256').update(event.id).digest('hex');
      const ref = db.collection('revenuecat_notification_events').doc(id);
      const claimed = await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(ref);
        if (existing.exists) return false;
        transaction.create(ref, {
          event_id: event.id,
          type: event.type,
          status: 'sending',
          created_at: new Date(),
        });
        return true;
      });
      if (!claimed) return res.status(200).send('Duplicate');

      // Never send within the transaction: Firestore can rerun its callback.
      // Retain the claim even on an ambiguous FCM failure to prevent duplicates.
      try {
        const messageId = await messaging.send({ token: deviceToken, notification });
        await ref.update({ status: 'sent', message_id: messageId });
      } catch {
        await ref.update({ status: 'delivery_uncertain' });
        throw new Error('Notification delivery requires inspection');
      }
      return res.status(200).send('Sent');
    } catch {
      // Do not log Authorization, tokens, or webhook payloads.
      console.error('RevenueCat notification processing failed');
      return res.status(500).send('Notification processing failed');
    }
  };
}

module.exports = { createRevenueCatHandler };
