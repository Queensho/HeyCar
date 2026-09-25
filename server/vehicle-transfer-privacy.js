async function tableExists(db,table){
  const r=await db.query('SELECT to_regclass($1) AS t',['public.'+table]);
  return Boolean(r.rows[0]?.t);
}

async function clearPrivateVehicleHistory(db,vehicleId){
  const id=String(vehicleId||'').trim();
  if(!id)return {};

  const removed={};

  // Conversations are owner-private. Delete them before notifications so all
  // messages disappear through ON DELETE CASCADE.
  if(await tableExists(db,'qr_conversations')){
    const r=await db.query('DELETE FROM qr_conversations WHERE vehicle_id::text=$1',[id]);
    removed.conversations=r.rowCount||0;
  }

  if(await tableExists(db,'vehicle_notifications')){
    const r=await db.query('DELETE FROM vehicle_notifications WHERE vehicle_id::text=$1',[id]);
    removed.notifications=r.rowCount||0;
  }

  if(await tableExists(db,'anonymous_calls')){
    const r=await db.query('DELETE FROM anonymous_calls WHERE vehicle_id::text=$1',[id]);
    removed.calls=r.rowCount||0;
  }

  // Any scan token issued before transfer belonged to the old ownership
  // context. Revoke it so the visitor must rescan after the new owner takes over.
  if(await tableExists(db,'qr_scan_sessions')){
    const r=await db.query('DELETE FROM qr_scan_sessions WHERE vehicle_id::text=$1',[id]);
    removed.scanSessions=r.rowCount||0;
  }

  // Parking information belongs to the person who parked the car, not the next
  // owner. QR scan history and maintenance history deliberately remain.
  if(await tableExists(db,'vehicle_park_notes')){
    const r=await db.query('DELETE FROM vehicle_park_notes WHERE vehicle_id::text=$1',[id]);
    removed.parkNotes=r.rowCount||0;
  }

  if(await tableExists(db,'vehicle_parking_locations')){
    const r=await db.query('DELETE FROM vehicle_parking_locations WHERE vehicle_id::text=$1',[id]);
    removed.parkingLocations=r.rowCount||0;
  }

  return removed;
}

module.exports={clearPrivateVehicleHistory};
