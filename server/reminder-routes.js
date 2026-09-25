// Compatibility entry point.
// Older VPS bootstraps require('./reminder-routes'), while newer route bundles may
// also register reminders through qr-routes. Keep one canonical implementation
// and make registration idempotent so the same Express app cannot receive the
// reminder endpoints twice.
const registerCanonicalVehicleReminderRoutes=require('./vehicle-reminder-routes');

const registeredApps=new WeakSet();

module.exports=function registerReminderRoutes(app,pool){
  if(!app||typeof app!=='function'){
    throw new Error('REMINDER_APP_REQUIRED');
  }
  if(registeredApps.has(app))return;
  registeredApps.add(app);
  registerCanonicalVehicleReminderRoutes(app,pool);
};
