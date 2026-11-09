// Legacy rows have no trustworthy auth-role discriminator. Only vehicle-backed,
// exclusive role evidence can make a redemption visible; favorites have no such
// evidence and remain stored, private and available for an audited reconciliation.
function legacyRolePredicate(alias='r', role='$2') {
  const owned=`EXISTS(SELECT 1 FROM vehicles lv WHERE lv.owner_id::text=${alias}.owner_id AND regexp_replace(upper(lv.plate),'[[:space:]]+','','g')=${alias}.plate)`;
  const driven=`EXISTS(SELECT 1 FROM vehicle_drivers ld JOIN vehicles lv ON lv.id::text=ld.vehicle_id::text WHERE ld.driver_user_id::text=${alias}.owner_id AND regexp_replace(upper(lv.plate),'[[:space:]]+','','g')=${alias}.plate)`;
  return `(${alias}.actor_role=${role} OR (${alias}.actor_role='legacy' AND ((${role}='owner' AND ${owned} AND NOT ${driven}) OR (${role}='driver' AND ${driven} AND NOT ${owned}))))`;
}
module.exports={legacyRolePredicate};
