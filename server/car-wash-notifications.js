const {externalServicesDisabled}=require('./external-services-policy');
const messages={created:'Oto yıkama randevunuz oluşturuldu.',confirmed:'İşletme randevunuzu onayladı.',rejected:'İşletme randevunuzu reddetti.',cancelled:'Randevunuz iptal edildi.',rescheduled:'Randevunuz yeniden planlandı; işletme onayı bekleniyor.',in_progress:'Oto yıkama hizmetiniz başladı.',completed:'Oto yıkama hizmetiniz tamamlandı.',reminder:'Oto yıkama randevunuza bir saatten az kaldı.'};
async function tick(app,pool){
 if(process.env.CAR_WASH_BOOKING_ENABLED!=='true')return;
 await pool.query(`INSERT INTO car_wash_notifications(booking_id,owner_id,revision,event)
  SELECT id,owner_id,revision,'reminder' FROM car_wash_bookings
  WHERE status='confirmed' AND starts_at>now() AND starts_at<=now()+interval '1 hour'
  ON CONFLICT DO NOTHING`);
 if(externalServicesDisabled()||process.env.CAR_WASH_PUSH_ENABLED!=='true'||!app.locals?.heycarPush?.sendOwner)return;
 const rows=(await pool.query(`WITH pending AS (
  SELECT n.id FROM car_wash_notifications n WHERE n.push_attempted_at IS NULL
  ORDER BY n.created_at LIMIT 50 FOR UPDATE SKIP LOCKED
 ) UPDATE car_wash_notifications n SET push_attempted_at=now(),push_result='claimed'
 FROM pending WHERE n.id=pending.id RETURNING n.*`)).rows;
 for(const n of rows){
  let result='unknown';
  try{
   const b=(await pool.query('SELECT status,revision,starts_at FROM car_wash_bookings WHERE id=$1',[n.booking_id])).rows[0];
   const preferences=(await pool.query('SELECT system_notifications FROM owner_privacy_settings WHERE owner_id=$1',[String(n.owner_id)])).rows[0];
   if(externalServicesDisabled()){result='suppressed_staging';}
   else if(preferences?.system_notifications===false){result='suppressed_preference';}
   else if(n.event==='reminder'&&(!b||b.status!=='confirmed'||b.revision!==n.revision||new Date(b.starts_at)<=new Date())){result='superseded';}
   else{
    const out=await app.locals.heycarPush.sendOwner(String(n.owner_id),{type:'car_wash',bookingId:String(n.booking_id),notificationId:String(n.id),event:n.event},'CepQontag • Oto Yıkama',messages[n.event]||'Randevunuz güncellendi.');
    result=Number(out?.delivered||0)>0?'sent':'not_delivered';
   }
  }catch(_){result='unknown';}
  await pool.query('UPDATE car_wash_notifications SET push_result=$2 WHERE id=$1',[n.id,result]);
 }
}
function start(app,pool){
 if(process.env.CAR_WASH_BOOKING_ENABLED!=='true')return null;
 let busy=false;
 const timer=setInterval(async()=>{if(busy)return;busy=true;try{await tick(app,pool);}catch(e){console.warn('car wash notifications',{code:e.code||'UNAVAILABLE'});}finally{busy=false;}},60000);
 timer.unref?.();return ()=>clearInterval(timer);
}
module.exports={messages,tick,start};
