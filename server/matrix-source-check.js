const fs=require('fs');

function read(name){
  return fs.readFileSync(name,'utf8');
}
function requireText(name,needle,label){
  const text=read(name);
  if(!text.includes(needle))throw new Error(label||(`MISSING: ${name} -> ${needle}`));
}
function rejectText(name,needle,label){
  const text=read(name);
  if(text.includes(needle))throw new Error(label||(`FORBIDDEN: ${name} -> ${needle}`));
}

if(fs.existsSync('reminder-routes.js')){
  throw new Error('LEGACY_REMINDER_ENTRYPOINT_PRESENT');
}

requireText(
  'security-service.js',
  'const key=publicVisitorKey(req);',
  'PUBLIC_RATE_LIMIT_NOT_BOUND_TO_SERVER_VISITOR_KEY'
);
rejectText(
  'security-service.js',
  "req.headers['x-guest-token']",
  'CLIENT_CONTROLLED_VISITOR_KEY_REINTRODUCED'
);
rejectText(
  'security-service.js',
  "cepqar-qr-security",
  'HARDCODED_QR_HASH_SALT_REINTRODUCED'
);
requireText(
  'qr-security-routes.js',
  "const {publicVisitorKey}=require('./security-service');",
  'QR_SCAN_HASH_NOT_SHARED_WITH_SECURITY_SERVICE'
);

requireText(
  'notification-routes.js',
  'const session = await validateScanSession(pool, raw, token);',
  'MESSAGE_SCAN_SESSION_VALIDATION_MISSING'
);
requireText(
  'notification-routes.js',
  'const guard = await guardPublicRequest(req, token, qr);',
  'MESSAGE_ROUTE_NOT_USING_SCAN_GUARD'
);

requireText(
  'active-driver-routes.js',
  'if(!await ownedVehicle(ownerId,req.params.vehicleId))return res.status(404).json({error:\'NOT_FOUND\'});',
  'ACTIVE_DRIVER_DELETE_OWNERSHIP_GUARD_MISSING'
);

const maintenance=read('maintenance-routes.js');
const forUpdateCount=(maintenance.match(/FOR UPDATE/g)||[]).length;
if(forUpdateCount<4){
  throw new Error('MAINTENANCE_ROW_LOCK_REGRESSION');
}

requireText(
  'vehicle-transfer-service.js',
  'clearPrivateVehicleHistory',
  'TRANSFER_PRIVATE_HISTORY_CLEANUP_MISSING'
);
requireText(
  'vehicle-transfer-privacy.js',
  "DELETE FROM qr_conversations",
  'TRANSFER_CONVERSATION_CLEANUP_MISSING'
);
requireText(
  'vehicle-transfer-privacy.js',
  "DELETE FROM vehicle_notifications",
  'TRANSFER_NOTIFICATION_CLEANUP_MISSING'
);

const pushHook=read('notification-push-hook.js');
if(!pushHook.includes("if(recipientType==='driver'){")){
  throw new Error('ACTIVE_RECIPIENT_ROUTING_MISSING');
}
if(!pushHook.includes('driverResult=await push.sendDriver(routedRecipient,payload,notificationTitle,body);')){
  throw new Error('DRIVER_PUSH_BRANCH_MISSING');
}
if(!pushHook.includes("}else{\n      const ownerSender=push.sendOwner||push.send;")){
  throw new Error('OWNER_PUSH_ELSE_BRANCH_MISSING');
}

const admin=read('admin-management-routes.js');
if(!admin.includes("crypto.randomBytes(16)")){
  throw new Error('OPAQUE_QR_TOKEN_RANDOMNESS_MISSING');
}
if(admin.includes("const token = 'CP-QAR-' + String(serialNo)")){
  throw new Error('SEQUENTIAL_QR_TOKEN_REINTRODUCED');
}
if(!admin.includes('serial_no')){
  throw new Error('QR_SERIAL_TRACKING_MISSING');
}

console.log('MATRIX_SOURCE_INVARIANTS_OK');
