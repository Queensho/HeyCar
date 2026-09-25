const {clearPrivateVehicleHistory}=require('./vehicle-transfer-privacy');

async function finalizeVehicleTransfer(db,{vehicleId,transferId,newOwnerId}){
  const vehicle=String(vehicleId||'').trim();
  const transfer=String(transferId||'').trim();
  const owner=String(newOwnerId||'').trim();
  if(!vehicle||!transfer||!owner)throw new Error('TRANSFER_FINALIZE_INPUT_REQUIRED');

  await db.query('DELETE FROM vehicle_active_drivers WHERE vehicle_id::text=$1',[vehicle]);
  await db.query('DELETE FROM vehicle_drivers WHERE vehicle_id::text=$1',[vehicle]);
  await db.query(
    "UPDATE vehicle_driver_invites SET expires_at=LEAST(expires_at,NOW()) WHERE vehicle_id::text=$1 AND accepted_at IS NULL",
    [vehicle]
  );
  await db.query(
    "UPDATE vehicle_reminders SET enabled=FALSE,updated_at=NOW() WHERE vehicle_id::text=$1 AND enabled=TRUE",
    [vehicle]
  );

  const privateReset=await clearPrivateVehicleHistory(db,vehicle);

  const changed=await db.query(
    'UPDATE vehicles SET owner_id=$1 WHERE id::text=$2 RETURNING id',
    [owner,vehicle]
  );
  if(!changed.rows.length)throw new Error('TRANSFER_VEHICLE_NOT_FOUND');

  const accepted=await db.query(
    "UPDATE vehicle_transfers SET status='accepted',accepted_by=$1,accepted_at=NOW() WHERE id::text=$2 AND status='pending' RETURNING id",
    [owner,transfer]
  );
  if(!accepted.rows.length)throw new Error('TRANSFER_NOT_PENDING');

  return {privateReset};
}

module.exports={finalizeVehicleTransfer};
