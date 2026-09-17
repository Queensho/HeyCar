function notificationPushEnabled(type, settings) {
  return (
    (type === 'message' && settings.message_notifications) ||
    (type === 'call_request' && settings.call_notifications) ||
    (type === 'damage' && settings.damage_notifications) ||
    (['move_vehicle', 'lights_on'].includes(type) && settings.system_notifications)
  );
}

function notificationTitle(type) {
  return ({
    message: 'Yeni Mesaj',
    call_request: 'Arama Talebi',
    damage: 'Aracınız Hakkında Bildirim',
    move_vehicle: 'Aracınızı Çekebilir misiniz?',
    lights_on: 'Farlarınız Açık',
  })[type] || 'Cepqar';
}

async function sendQrNotificationPush({ app, qr, type, message, notificationId, token, getPrivacy }) {
  try {
    if (!app.locals.heycarPush) return;
    const settings = await getPrivacy(String(qr.owner_id));
    if (!notificationPushEnabled(type, settings)) return;

    await app.locals.heycarPush.send(
      String(qr.owner_id),
      {
        type: type === 'message' ? 'message' : 'vehicle_notification',
        notificationId: String(notificationId),
        vehicleId: String(qr.vehicle_id),
        qrToken: String(token),
      },
      notificationTitle(type),
      message || 'Aracınız için yeni bir bildirim var',
    );
  } catch (err) {
    console.error('notification push', err);
  }
}

module.exports = { sendQrNotificationPush };
