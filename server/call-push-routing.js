'use strict';

// Every call notification must match its authoritative backend recipient.
// A driver with no reachable push device may fall back to the owner, but ONLY
// after changing the recipient of that exact, still-ringing call in the DB.
async function reassignRingingCallToOwner(pool, {callId, driverId, ownerId}) {
  if (!callId || !driverId || !ownerId || String(driverId)===String(ownerId)) return false;
  try {
    const result = await pool.query(
      `UPDATE anonymous_calls
         SET recipient_user_id=$3, recipient_type='owner'
         WHERE id=$1
           AND recipient_user_id=$2 AND recipient_type='driver'
           AND owner_id::text=$3
           AND status='ringing' AND expires_at>NOW()
         RETURNING id`,
      [String(callId),String(driverId),String(ownerId)]
    );
    return Number(result.rowCount ?? result.rows?.length ?? 0)===1;
  } catch (e) {
    // Never redirect into an owner's other active call.
    if (e?.code==='23505' && e?.constraint==='uq_anonymous_calls_active_recipient') {
      return false;
    }
    throw e;
  }
}

async function sendCallPush({
  pool, push, recipientId, recipientType, ownerId, data, title, body,
  isOwnerDndActive, logger=console,
}) {
  const target=String(recipientId||'');
  const owner=String(ownerId||'');
  const callId=String(data?.callId||'');
  let ownerResult=null, driverResult=null, routedTo=recipientType;

  if (!push) {
    logger.error('Call push skipped',{reason:'PUSH_SERVICE_MISSING',callId,recipientId:target,recipientType});
    return {owner:ownerResult,driver:driverResult,routedTo};
  }

  if (recipientType==='driver') {
    if (typeof push.sendDriver==='function') {
      try {
        driverResult=await push.sendDriver(target,{...data,recipientType:'driver'},title,body);
      } catch (e) {
        logger.error('Call driver push failed',{callId,error:String(e?.message||e)});
        driverResult={attempted:0,delivered:0};
      }
    } else {
      logger.error('Call push skipped',{reason:'DRIVER_SENDER_MISSING',callId,recipientId:target});
      driverResult={attempted:0,delivered:0};
    }

    // Cancellation notifications and other events must NEVER change a call's
    // recipient or fan out to a different identity.
    if (data?.type==='incoming_call' &&
        Number(driverResult?.delivered||0)===0 &&
        callId && owner && owner!==target &&
        typeof (push.sendOwner||push.send)==='function' &&
        !(await isOwnerDndActive(pool,owner))) {
      // Only switch if this call still rings for the original driver.
      // If the driver already answered or the owner is busy, do not send a
      // misleading notification to the owner.
      const switched=await reassignRingingCallToOwner(pool,{
        callId,driverId:target,ownerId:owner,
      });
      if (switched) {
        routedTo='owner';
        try {
          ownerResult=await (push.sendOwner||push.send)(
            owner,{...data,recipientType:'owner',routedFrom:'driver_fallback'},title,body
          );
        } catch (e) {
          logger.error('Call owner fallback push failed',{callId,error:String(e?.message||e)});
          ownerResult={attempted:0,delivered:0};
        }
        logger.warn('Call push fallback to owner',{
          callId,ownerId:owner,recipientId:target,driver:driverResult,owner:ownerResult,
          databaseRecipient:'owner',
        });
      } else {
        logger.warn('Call push fallback skipped',{
          callId,reason:'CALL_NO_LONGER_RINGING_OR_OWNER_BUSY',
        });
      }
    }
  } else {
    const ownerTarget=target||owner;
    const sendOwner=push.sendOwner||push.send;
    if (!ownerTarget||typeof sendOwner!=='function') {
      logger.error('Call push skipped',{reason:'OWNER_SENDER_MISSING',callId,recipientId:ownerTarget});
      return {owner:ownerResult,driver:driverResult,routedTo};
    }
    if (await isOwnerDndActive(pool,ownerTarget)) {
      logger.info('Call owner push suppressed by DND',{callId,ownerId:ownerTarget});
      return {owner:ownerResult,driver:driverResult,routedTo};
    }
    ownerResult=await sendOwner(ownerTarget,{...data,recipientType:'owner'},title,body);
  }

  logger.log('Call push delivery',{
    callId,ownerId:owner,recipientId:target,recipientType,
    routedTo,owner:ownerResult,driver:driverResult,
  });
  return {owner:ownerResult,driver:driverResult,routedTo};
}

module.exports={reassignRingingCallToOwner,sendCallPush};
