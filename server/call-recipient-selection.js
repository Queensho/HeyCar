'use strict';

// Select the call recipient *before* inserting a call. An active vehicle driver
// without any push endpoint cannot be rung and should not reserve a ringing
// call that the owner is not authorized to answer.
async function selectReachableCallRecipient(pool, vehicleId, ownerId, {
  webPushEnabled = false,
  logger = console,
} = {}) {
  const driver = await pool.query(
    `SELECT driver_user_id::text AS driver_user_id
       FROM vehicle_active_drivers
       WHERE vehicle_id::text=$1::text
         AND driver_user_id IS NOT NULL
         AND (active_until IS NULL OR active_until>NOW())
       LIMIT 1`,
    [vehicleId]
  );
  const driverId=String(driver.rows[0]?.driver_user_id||'').trim();
  if(!driverId){
    return {recipientId:String(ownerId),recipientType:'owner',reason:'NO_ACTIVE_DRIVER'};
  }

  // Both direct FCM registrations and WebPush subscriptions can make a
  // driver reachable. WebPush only counts when VAPID is actually configured.
  const availability=await pool.query(
    `SELECT
       EXISTS(
         SELECT 1 FROM driver_push_tokens
         WHERE driver_id::text=$1 AND active=TRUE
       ) AS fcm,
       EXISTS(
         SELECT 1 FROM driver_web_push_subscriptions
         WHERE driver_id::text=$1 AND active=TRUE
       ) AS web`,
    [driverId]
  );
  const registered=availability.rows[0]||{};
  const hasFcm=registered.fcm===true;
  const hasWeb=webPushEnabled && registered.web===true;
  if(hasFcm||hasWeb){
    return {recipientId:driverId,recipientType:'driver',reason:'DRIVER_HAS_PUSH_ENDPOINT'};
  }

  logger.warn('Call route skipped unreachable active driver', {
    driverHasFcm:hasFcm,
    driverHasWeb:hasWeb,
    reason:'NO_ACTIVE_DRIVER_PUSH_ENDPOINT',
  });
  return {recipientId:String(ownerId),recipientType:'owner',reason:'DRIVER_HAS_NO_PUSH_ENDPOINT'};
}

module.exports={selectReachableCallRecipient};
