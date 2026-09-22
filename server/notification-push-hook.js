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
    const push=app.locals.heycarPush;
    if(!push)return;
    const settings=await getPrivacy(String(qr.owner_id));
    if(!notificationPushEnabled(type,settings))return;

    let plate=String(qr.plate||'').trim();
    if(!plate&&qr.vehicle_id){
      try{
        const result=await app.locals.heycarPool?.query?.('SELECT plate FROM vehicles WHERE id=$1 LIMIT 1',[qr.vehicle_id]);
        plate=String(result?.rows?.[0]?.plate||'').trim();
      }catch(_){}
    }

    const titles={
      message:'Yeni Mesaj',
      call_request:'Arama Talebi',
      damage:'Aracınız Hakkında Bildirim',
      move_vehicle:'Aracınızı Çekebilir misiniz?',
      lights_on:'Farlarınız Açık'
    };
    const body=message||titles[type]||'Aracınız için yeni bir bildirim var';
    const ownerId=String(qr.owner_id);
    const routedRecipient=String(recipientUserId||ownerId);
    const payload={
      type:type==='message'?'message':'vehicle_notification',
      sourceType:type,
      recipientType:'owner',
      notificationId:String(notificationId),
      vehicleId:String(qr.vehicle_id),
      qrToken:String(token),
      plate,
      body,
      message:body,
      sentAt:String(Date.now())
    };

    const ownerSender=push.sendOwner||push.send;
    if(!ownerSender)return;

    const ownerResult=await ownerSender(
      ownerId,
      payload,
      plate||titles[type]||'Cepqar',
      body,
    );

    let driverResult=null;
    if(routedRecipient&&routedRecipient!==ownerId&&push.sendDriver){
      driverResult=await push.sendDriver(
        routedRecipient,
        {...payload,recipientType:'driver'},
        plate||titles[type]||'Cepqar',
        body,
      );
    }

    console.log('QR push delivery',{
      type,
      ownerId,
      owner:ownerResult||null,
      routedRecipient,
      driver:driverResult,
      notificationId:String(notificationId),
    });
  } catch (err) {
    console.error('notification push',err);
  }
}
module.exports = { sendQrNotificationPush };
