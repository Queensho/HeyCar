const {ownerId: authenticatedOwnerId}=require('./owner-auth-service');
const express = require('express');

const TYPES = new Set(['kasko','traffic_insurance','inspection','maintenance']);
const LABELS = {
  kasko: 'Kasko',
  traffic_insurance: 'Trafik sigortası',
  inspection: 'Araç muayenesi',
  maintenance: 'Periyodik bakım',
};

module.exports = function registerReminderRoutes(app, pool) {
  let ready = false;
  async function schema() {
    if (ready) return;
    await pool.query(`
      CREATE TABLE IF NOT EXISTS vehicle_reminders (
        id BIGSERIAL PRIMARY KEY,
        owner_id TEXT NOT NULL,
        vehicle_id TEXT NOT NULL,
        type TEXT NOT NULL,
        due_date DATE NOT NULL,
        enabled BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='vehicle_reminders' AND column_name='reminder_type'
        ) AND NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema='public' AND table_name='vehicle_reminders' AND column_name='type'
        ) THEN
          ALTER TABLE vehicle_reminders RENAME COLUMN reminder_type TO type;
        END IF;
      END $$;
      DO $$
      DECLARE c RECORD;
      BEGIN
        FOR c IN
          SELECT conname FROM pg_constraint
          WHERE conrelid='vehicle_reminders'::regclass AND contype='c'
        LOOP
          EXECUTE format('ALTER TABLE vehicle_reminders DROP CONSTRAINT %I', c.conname);
        END LOOP;
      END $$;
      UPDATE vehicle_reminders SET type='kasko' WHERE type='casco';
      CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicle_reminders_owner_vehicle_type
        ON vehicle_reminders(owner_id,vehicle_id,type);
      CREATE INDEX IF NOT EXISTS idx_vehicle_reminders_due
        ON vehicle_reminders(due_date) WHERE enabled=TRUE;
      CREATE TABLE IF NOT EXISTS vehicle_reminder_delivery_claims (
        reminder_id BIGINT NOT NULL REFERENCES vehicle_reminders(id) ON DELETE CASCADE,
        days_before INTEGER NOT NULL,
        sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY(reminder_id,days_before)
      );
    `);
    ready = true;
  }

  async function ownedVehicle(ownerId, vehicleId) {
    const r = await pool.query(`SELECT id,plate FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1`, [vehicleId, ownerId]);
    return r.rows[0] || null;
  }

  app.get('/api/vehicles/:vehicleId/reminders', async (req,res) => {
    const ownerId=authenticatedOwnerId(req);
    if(!ownerId) return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      await schema();
      const v=await ownedVehicle(ownerId,String(req.params.vehicleId));
      if(!v) return res.status(403).json({error:'FORBIDDEN'});
      const r=await pool.query(`SELECT id,type,due_date,enabled,created_at,updated_at FROM vehicle_reminders WHERE owner_id=$1 AND vehicle_id=$2 ORDER BY due_date`,[ownerId,String(v.id)]);
      return res.json({ok:true,reminders:r.rows});
    }catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/vehicles/:vehicleId/reminders/:type', express.json(), async (req,res) => {
    const ownerId=authenticatedOwnerId(req);
    const vehicleId=String(req.params.vehicleId||'').trim();
    const type=String(req.params.type||'').trim();
    const dueDate=String(req.body?.dueDate||'').trim();
    if(!ownerId) return res.status(401).json({error:'OWNER_REQUIRED'});
    if(!TYPES.has(type) || !/^\d{4}-\d{2}-\d{2}$/.test(dueDate)) return res.status(400).json({error:'INVALID_REQUEST'});
    try{
      await schema();
      const v=await ownedVehicle(ownerId,vehicleId);
      if(!v) return res.status(403).json({error:'FORBIDDEN'});
      const r=await pool.query(`INSERT INTO vehicle_reminders(owner_id,vehicle_id,type,due_date,enabled) VALUES($1,$2,$3,$4,TRUE) ON CONFLICT(owner_id,vehicle_id,type) DO UPDATE SET due_date=EXCLUDED.due_date,enabled=TRUE,updated_at=NOW() RETURNING *`,[ownerId,String(v.id),type,dueDate]);
      await pool.query(`DELETE FROM vehicle_reminder_delivery_claims WHERE reminder_id=$1`,[r.rows[0].id]);
      return res.json({ok:true,reminder:r.rows[0]});
    }catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.delete('/api/vehicles/:vehicleId/reminders/:type', async (req,res) => {
    const ownerId=authenticatedOwnerId(req);
    if(!ownerId) return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      await schema();
      const v=await ownedVehicle(ownerId,String(req.params.vehicleId));
      if(!v) return res.status(403).json({error:'FORBIDDEN'});
      await pool.query(`DELETE FROM vehicle_reminders WHERE owner_id=$1 AND vehicle_id=$2 AND type=$3`,[ownerId,String(v.id),String(req.params.type)]);
      return res.json({ok:true});
    }catch(e){console.error(e);return res.status(500).json({error:'SERVER_ERROR'});}
  });

  async function sendDueReminders() {
    try{
      await schema();
      const r=await pool.query(`SELECT r.id,r.owner_id,r.vehicle_id,r.type,r.due_date,v.plate,(r.due_date-CURRENT_DATE)::int AS days_before FROM vehicle_reminders r JOIN vehicles v ON v.id::text=r.vehicle_id WHERE r.enabled=TRUE AND (r.due_date-CURRENT_DATE)::int IN (30,7,1,0)`);
      for(const x of r.rows){
        const days=Number(x.days_before);
        const claim=await pool.query(`INSERT INTO vehicle_reminder_delivery_claims(reminder_id,days_before) VALUES($1,$2) ON CONFLICT DO NOTHING RETURNING reminder_id`,[x.id,days]);
        if(!claim.rows.length) continue;
        if(!app.locals.heycarPush) continue;
        const label=LABELS[x.type]||'Araç hatırlatması';
        const body=days===0?`${x.plate||'Aracınız'} • ${label} bugün sona eriyor.`:`${x.plate||'Aracınız'} • ${label} için ${days} gün kaldı.`;
        try{
          await app.locals.heycarPush.send(String(x.owner_id),{type:'vehicle_reminder',reminderType:String(x.type),vehicleId:String(x.vehicle_id),daysBefore:String(days),dueDate:String(x.due_date)},`${label} Hatırlatması`,body);
        }catch(e){
          console.error('vehicle reminder push',e);
          await pool.query(`DELETE FROM vehicle_reminder_delivery_claims WHERE reminder_id=$1 AND days_before=$2`,[x.id,days]);
        }
      }
    }catch(e){console.error('vehicle reminder scan',e);}
  }

  setTimeout(sendDueReminders, 15000);
  const timer=setInterval(sendDueReminders, 60*60*1000);
  timer.unref?.();
};
