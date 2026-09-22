function notificationPushEnabled(type, settings) {
  return (
    (type === 'message' && settings.message_notifications) ||
    (type === 'call_request' && settings.call_notifications) ||
    (type === 'damage' && settings.damage_notifications) ||
    (['move_vehicle', 'lights_on'].includes(type) && settings.system_notifications)
  );
}

async function sendQrNotificationPush({ app, qr, type, message, notificationId, recipientUserId, token, getPrivacy }) {
  try {
    if (!app.locals.heycarPush) return;
    const settings = await getPrivacy(String(qr.owner_id));
    if (!notificationPushEnabled(type, settings)) return;
    let plate = String(qr.plate || '').trim();
    if (!plate && qr.vehicle_id) {
      try {
        const result = await app.locals.heycarPool?.query?.('SELECT plate FROM vehicles WHERE id=$1 LIMIT 1', [qr.vehicle_id]);
        plate = String(result?.rows?.[0]?.plate || '').trim();
      } catch (_) {}
    }
    const titles = {
      message: 'Yeni Mesaj', call_request: 'Arama Talebi', damage: 'Aracınız Hakkında Bildirim',
      move_vehicle: 'Aracınızı Çekebilir misiniz?', lights_on: 'Farlarınız Açık'
    };
    const body = message || titles[type] || 'Aracınız için yeni bir bildirim var';
    const ownerId = String(qr.owner_id);
    const recipient = String(recipientUserId || ownerId);
    const isDriver = recipient !== ownerId;
    const sender = isDriver ? app.locals.heycarPush.sendDriver : app.locals.heycarPush.sendOwner || app.locals.heycarPush.send;
    if (!sender) return;
    await sender(
      recipient,
      { type: type === 'message' ? 'message' : 'vehicle_notification', recipientType: isDriver ? 'driver' : 'owner', notificationId: String(notificationId), vehicleId: String(qr.vehicle_id), qrToken: String(token), plate, body, message: body },
      plate || titles[type] || 'Cepqar', body,
    );
  } catch (err) { console.error('notification push', err); }
}
module.exports = { sendQrNotificationPush };
