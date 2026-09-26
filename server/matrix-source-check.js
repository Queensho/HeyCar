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


const migrationFiles=fs.readdirSync('migrations')
  .filter(name=>/^\d{3}_.+\.sql$/.test(name))
  .sort();
const migrationGroups=new Map();
for(const name of migrationFiles){
  const prefix=name.slice(0,3);
  const list=migrationGroups.get(prefix)||[];
  list.push(name);
  migrationGroups.set(prefix,list);
}
const allowedLegacyDuplicateMigrations=new Map([
  ['014',['014_maintenance_shares.sql','014_vehicle_reminders.sql']],
  ['015',['015_vehicle_parking_locations.sql','015_vehicle_reminder_deliveries.sql']],
  ['036',['036_admin_audit_log.sql','036_admin_audit_logs.sql']],
  ['041',['041_fix_vehicle_reminder_ownership.sql','041_support_tickets.sql']],
  ['053',['053_admin_audit_canonical.sql','053_vehicle_relation_fk_hardening.sql']],
]);
for(const [prefix,names] of migrationGroups){
  if(names.length<2)continue;
  const expected=allowedLegacyDuplicateMigrations.get(prefix);
  if(!expected||JSON.stringify(names)!==JSON.stringify(expected)){
    throw new Error(`UNAPPROVED_DUPLICATE_MIGRATION_PREFIX_${prefix}: ${names.join(',')}`);
  }
}

if(fs.existsSync('reminder-routes.js')){
  throw new Error('LEGACY_REMINDER_ENTRYPOINT_PRESENT');
}

requireText(
  'migrate.js',
  'MIGRATION_CHECKSUM_MISMATCH',
  'MIGRATION_CHECKSUM_GUARD_MISSING'
);
requireText(
  'migrate.js',
  'schema_migrations',
  'MIGRATION_TRACKING_TABLE_MISSING'
);


requireText(
  'owner-auth-routes.js',
  "const loginLimiter=rateLimit({",
  'OWNER_LOGIN_RATE_LIMIT_MISSING'
);
requireText(
  'owner-auth-routes.js',
  "return res.status(401).json({ error: 'INVALID_CREDENTIALS' });",
  'OWNER_LOGIN_ENUMERATION_GUARD_MISSING'
);
requireText(
  'driver-routes.js',
  "const loginLimiter=rateLimit({",
  'DRIVER_LOGIN_RATE_LIMIT_MISSING'
);
requireText(
  'qr-routes.js',
  "publicResolveLimiter",
  'PUBLIC_QR_RESOLVE_RATE_LIMIT_MISSING'
);
requireText(
  'notification-routes.js',
  "scanSessionLimiter",
  'QR_SCAN_SESSION_RATE_LIMIT_MISSING'
);
requireText(
  'server.js',
  "'https://queensho.github.io'",
  'SAFE_DEFAULT_CORS_ORIGIN_MISSING'
);
requireText(
  'migrations/056_rotate_unexposed_legacy_qr_tokens.sql',
  "gen_random_bytes(10)",
  'LEGACY_QR_SAFE_ROTATION_MISSING'
);


for(const file of [
  'app-settings-routes.js',
  'support-routes.js',
  'admin-moderation-ops-routes.js',
  'admin-communication-security-routes.js',
  'admin-business-premium-routes.js',
]){
  rejectText(
    file,
    "req.headers?.['x-admin",
    'SPOOFABLE_ADMIN_ACTOR_REINTRODUCED: '+file
  );
}
requireText(
  'admin-management-routes.js',
  'promoMetricLimiter',
  'PROMO_METRIC_RATE_LIMIT_MISSING'
);

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
  'notification-routes.js',
  'RETURNING id, type, message, photo_path, latitude, longitude, status, created_at, recipient_user_id',
  'NOTIFICATION_RECIPIENT_NOT_PERSISTED'
);
requireText(
  'migrations/055_vehicle_notification_recipient_column.sql',
  'vehicle_notifications_recipient_fk',
  'NOTIFICATION_RECIPIENT_MIGRATION_MISSING'
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

rejectText(
  'business-routes.js',
  "cepqar-business-v1",
  'HARDCODED_BUSINESS_PASSWORD_SALT_REINTRODUCED'
);

rejectText(
  'push-routes.js',
  "console.error('FCM send',r.status,detail)",
  'RAW_FCM_ERROR_BODY_LOGGING_REINTRODUCED'
);

requireText(
  'vehicle-reminder-routes.js',
  'crypto.timingSafeEqual(supplied,target)',
  'REMINDER_JOB_SECRET_NOT_TIMING_SAFE'
);

console.log('MATRIX_SOURCE_INVARIANTS_OK');
