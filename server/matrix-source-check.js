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
const adminUi=read('../lib/admin_v3.dart');
if(!adminUi.includes("String _labelCodeOf(Map<String,dynamic> e)")){
  throw new Error('QR_HUMAN_LABEL_CODE_HELPER_MISSING');
}
if(!adminUi.includes("return 'CP-QAR-$serial';")){
  throw new Error('QR_HUMAN_LABEL_CODE_FORMAT_MISSING');
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
  'push-routes.js',
  'async function retireFcmToken(token)',
  'FCM_STALE_TOKEN_RETIREMENT_MISSING'
);
requireText(
  'push-routes.js',
  "['owner_push_tokens','driver_push_tokens','valet_push_tokens']",
  'FCM_STALE_TOKEN_GLOBAL_CLEANUP_MISSING'
);
requireText(
  'push-routes.js',
  "channel_id:'cepqontag_notifications_v11'",
  'ANDROID_PUSH_CHANNEL_VERSION_MISMATCH'
);
requireText(
  'notification-push-hook.js',
  "routedFrom:'driver_fallback'",
  'QR_PUSH_OWNER_FALLBACK_MISSING'
);
requireText(
  'call-routes.js',
  "routedFrom:'driver_fallback'",
  'CALL_PUSH_OWNER_FALLBACK_MISSING'
);

requireText(
  'vehicle-reminder-routes.js',
  'crypto.timingSafeEqual(supplied,target)',
  'REMINDER_JOB_SECRET_NOT_TIMING_SAFE'
);

console.log('MATRIX_SOURCE_INVARIANTS_OK');

requireText(
  'story-routes.js',
  "ACTION_TYPES=new Set(['NONE','IN_APP_PAGE','SERVICE','OPPORTUNITY','EXTERNAL_URL'])",
  'STORY_ACTION_ALLOWLIST_MISSING'
);
requireText(
  'story-routes.js',
  "INTERVAL '30 minutes'",
  'STORY_IMPRESSION_DEDUPE_MISSING'
);
requireText(
  'story-routes.js',
  "s.starts_at<=NOW()",
  'STORY_SCHEDULE_FILTER_MISSING'
);
requireText(
  'story-routes.js',
  "s.target_district IS NULL",
  'STORY_LOCATION_TARGET_FILTER_MISSING'
);

requireText(
  'admin-management-routes.js',
  "story-(?:thumbnail|content)-[a-f0-9-]+",
  'STORY_MEDIA_PUBLIC_ROUTE_MISSING'
);

requireText(
  'app-builder-routes.js',
  "COMPONENT_TYPES=new Set([",
  'APP_BUILDER_COMPONENT_ALLOWLIST_MISSING'
);
requireText(
  'app-builder-routes.js',
  "ACTIONS=new Set([",
  'APP_BUILDER_ACTION_ALLOWLIST_MISSING'
);
requireText(
  'app-builder-routes.js',
  "UNSUPPORTED_SCHEMA_VERSION",
  'APP_BUILDER_SCHEMA_VALIDATION_MISSING'
);
requireText(
  'app-builder-routes.js',
  "app_config.published",
  'APP_BUILDER_PUBLISH_AUDIT_MISSING'
);
requireText(
  'app-builder-routes.js',
  "app_config.rolled_back",
  'APP_BUILDER_ROLLBACK_AUDIT_MISSING'
);
requireText(
  'app-builder-routes.js',
  "if-none-match",
  'APP_BUILDER_ETAG_HINT_MISSING'
);


// Towing read, tracking and cancellation must scope the requested job to the
// authenticated owner. Guard against future IDOR regressions in route SQL.
const towing=read('towing-routes.js');
for(const [route,requiredSql] of [
  ["app.get('/api/owner/towing/requests/:id',", 'WHERE id=$1 AND owner_id=$2 LIMIT 1'],
  ["app.post('/api/owner/towing/requests/:id/cancel',", 'WHERE id=$1 AND owner_id=$2 AND status IN'],
  ["app.get('/api/owner/towing/requests/:id/tracking',", 'WHERE r.id=$1 AND r.owner_id=$2 LIMIT 1'],
]){
  const start=towing.indexOf(route);
  if(start<0)throw new Error('TOWING_OWNER_ROUTE_MISSING: '+route);
  const end=towing.indexOf("\n  app.",start+route.length);
  const body=towing.slice(start,end<0?undefined:end);
  if(!body.includes('authenticatedOwnerId(req)')||!body.includes(requiredSql)){
    throw new Error('TOWING_OWNER_IDOR_GUARD_MISSING: '+route);
  }
}
console.log('MATRIX_TOWING_OWNER_SQL_ISOLATION_OK');


// Public QR communication routes must keep scan-session and visitor-token
// authorization checks. These source invariants complement Matrix HTTP tests.
const notificationSource=read('notification-routes.js');
const callSource=read('call-routes.js');
function routeSection(source,signature){
  const start=source.indexOf(signature);
  if(start<0)throw new Error('PUBLIC_COMMUNICATION_ROUTE_MISSING: '+signature);
  const end=source.indexOf("\n  app.",start+signature.length);
  return source.slice(start,end<0?undefined:end);
}
for(const signature of [
  "app.post('/api/qr/:token/notifications',",
  "app.get('/api/qr/:token/park-note',",
]){
  const section=routeSection(notificationSource,signature);
  if(!section.includes('guardPublicRequest(req, token, qr)')){
    throw new Error('QR_SCAN_SESSION_GUARD_MISSING: '+signature);
  }
}
const publicCallCreate=routeSection(callSource,"app.post('/api/public/calls',");
if(!publicCallCreate.includes('validateScanSession(pool,')||
   !publicCallCreate.includes('enforcePublicRequest(pool,token,req)')||
   !publicCallCreate.includes('CALL_RATE_LIMITED')){
  throw new Error('PUBLIC_CALL_ABUSE_GUARDS_MISSING');
}
for(const signature of [
  "app.get('/api/public/calls/:callId',",
  "app.patch('/api/public/calls/:callId',",
]){
  const section=routeSection(callSource,signature);
  if(!section.includes("req.headers['x-visitor-token']")||
     !section.includes('visitor_token::text=$2')){
    throw new Error('PUBLIC_CALL_VISITOR_ISOLATION_MISSING: '+signature);
  }
}
console.log('MATRIX_QR_COMMUNICATION_SOURCE_GUARDS_OK');
