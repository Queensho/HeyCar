const express=require('express');
const {ownerId:authenticatedOwnerId}=require('./owner-auth-service');

module.exports=function registerVehicleReminderRoutes(app,pool){
  const owner=req=>authenticatedOwnerId(req);
  const meta={
    inspection:{label:'Muayene',days:[30,7,1]},
    traffic_insurance:{label:'Trafik sigortası',days:[15,7,1]},
    kasko:{label:'Kasko',days:[15,7,1]},
    maintenance:{label:'Periyodik bakım',days:[30,7,1]},
  };
  let schemaReady=false;

  async function ensureSchema(){
    if(schemaReady)return;
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
      UPDATE vehicle_reminders SET type='kasko' WHERE type='casco';
      CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicle_reminders_owner_vehicle_type
        ON vehicle_reminders(owner_id,vehicle_id,type);
      CREATE INDEX IF NOT EXISTS idx_vehicle_reminders_due
        ON vehicle_reminders(due_date) WHERE enabled=TRUE;
    `);
    schemaReady=true;
  }

  function normalizeType(raw){
    const value=String(raw||'').trim();
    return value==='casco'?'kasko':value;
  }

  async function premium(ownerId){
    const r=await pool.query('SELECT COALESCE(premium,false) AS premium FROM users WHERE id::text=$1 LIMIT 1',[ownerId]);
    return r.rows[0]?.premium===true;
  }

  async function owned(req,res){
    const o=owner(req),id=String(req.params.vehicleId||'');
    if(!o){res.status(401).json({error:'OWNER_REQUIRED'});return null;}
    const r=await pool.query(
      'SELECT id,plate,make,model FROM vehicles WHERE id::text=$1 AND owner_id::text=$2 LIMIT 1',
      [id,o]
    );
    if(!r.rows.length){res.status(403).json({error:'FORBIDDEN'});return null;}
    return r.rows[0];
  }

  app.get('/api/vehicles/:vehicleId/reminders',async(req,res)=>{
    try{
      await ensureSchema();
      const v=await owned(req,res);if(!v)return;
      const isPremium=await premium(owner(req));
      const r=await pool.query(
        `SELECT type,type AS reminder_type,due_date,enabled,updated_at
           FROM vehicle_reminders
          WHERE vehicle_id=$1
          ORDER BY due_date`,
        [String(v.id)]
      );
      const today=new Date();today.setHours(0,0,0,0);
      const reminders=r.rows.map(x=>{
        const due=new Date(`${String(x.due_date).slice(0,10)}T00:00:00`);
        const daysLeft=Math.ceil((due-today)/86400000);
        const m=meta[x.type]||{label:x.type,days:[7,1]};
        return {...x,label:m.label,daysLeft,critical:daysLeft<=1,notificationMilestones:m.days};
      });
      res.json({ok:true,premium:isPremium,vehicle:v,reminders});
    }catch(e){console.error('vehicle reminders list',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.put('/api/vehicles/:vehicleId/reminders',express.json(),async(req,res)=>{
    try{
      await ensureSchema();
      const v=await owned(req,res);if(!v)return;
      const o=owner(req);
      if(!await premium(o))return res.status(403).json({error:'PREMIUM_REQUIRED'});
      const type=normalizeType(req.body.type);
      const dueDate=String(req.body.dueDate||'').slice(0,10);
      if(!meta[type]||!/^\d{4}-\d{2}-\d{2}$/.test(dueDate))return res.status(400).json({error:'INVALID_REMINDER'});
      await pool.query(
        `INSERT INTO vehicle_reminders(vehicle_id,owner_id,type,due_date,enabled,updated_at)
         VALUES($1,$2,$3,$4,TRUE,NOW())
         ON CONFLICT(owner_id,vehicle_id,type)
         DO UPDATE SET due_date=EXCLUDED.due_date,enabled=TRUE,updated_at=NOW()`,
        [String(v.id),o,type,dueDate]
      );
      res.json({ok:true,type,dueDate});
    }catch(e){console.error('vehicle reminder save',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.delete('/api/vehicles/:vehicleId/reminders/:type',async(req,res)=>{
    try{
      await ensureSchema();
      const v=await owned(req,res);if(!v)return;
      const o=owner(req);
      if(!await premium(o))return res.status(403).json({error:'PREMIUM_REQUIRED'});
      const type=normalizeType(req.params.type);
      if(!meta[type])return res.status(400).json({error:'INVALID_REMINDER'});
      await pool.query(
        'DELETE FROM vehicle_reminders WHERE vehicle_id=$1 AND owner_id=$2 AND type=$3',
        [String(v.id),o,type]
      );
      res.json({ok:true});
    }catch(e){console.error('vehicle reminder delete',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.get('/api/reminders/due',async(req,res)=>{
    try{
      await ensureSchema();
      const o=owner(req);
      if(!o)return res.status(401).json({error:'OWNER_REQUIRED'});
      if(!await premium(o))return res.json({ok:true,due:[]});
      const r=await pool.query(
        `SELECT vr.*,vr.type AS reminder_type,v.plate
           FROM vehicle_reminders vr
           JOIN vehicles v ON v.id::text=vr.vehicle_id
          WHERE vr.owner_id=$1 AND vr.enabled=TRUE`,
        [o]
      );
      const today=new Date();today.setHours(0,0,0,0);
      const due=[];
      for(const x of r.rows){
        const d=new Date(`${String(x.due_date).slice(0,10)}T00:00:00`);
        const daysLeft=Math.ceil((d-today)/86400000);
        const m=meta[x.type]||{label:x.type,days:[7,1]};
        if(daysLeft<=0||m.days.includes(daysLeft))due.push({...x,label:m.label,daysLeft,critical:daysLeft<=1});
      }
      res.json({ok:true,due});
    }catch(e){console.error('vehicle reminders due',e);res.status(500).json({error:'SERVER_ERROR'});}
  });

  app.post('/api/internal/reminders/deliver',express.json(),async(req,res)=>{
    const secret=String(req.headers['x-reminder-secret']||'');
    if(!process.env.REMINDER_JOB_SECRET||secret!==process.env.REMINDER_JOB_SECRET)return res.status(403).json({error:'FORBIDDEN'});
    try{
      await ensureSchema();
      const r=await pool.query(
        `SELECT vr.*,v.plate
           FROM vehicle_reminders vr
           JOIN vehicles v ON v.id::text=vr.vehicle_id
           JOIN users u ON u.id::text=vr.owner_id
          WHERE vr.enabled=TRUE AND COALESCE(u.premium,false)=TRUE`
      );
      const today=new Date();today.setHours(0,0,0,0);
      let delivered=0;
      for(const x of r.rows){
        const d=new Date(`${String(x.due_date).slice(0,10)}T00:00:00`);
        const daysLeft=Math.ceil((d-today)/86400000);
        const m=meta[x.type]||{label:x.type,days:[7,1]};
        if(!(daysLeft<=0||m.days.includes(daysLeft)))continue;
        const milestone=daysLeft<=0?0:daysLeft;
        const inserted=await pool.query(
          `INSERT INTO vehicle_reminder_deliveries(vehicle_id,owner_id,reminder_type,due_date,milestone_days)
           VALUES($1,$2,$3,$4,$5)
           ON CONFLICT DO NOTHING RETURNING id`,
          [x.vehicle_id,x.owner_id,x.type,x.due_date,milestone]
        );
        if(!inserted.rows.length)continue;
        const message=daysLeft<0
          ?`${m.label} süresi ${-daysLeft} gün önce doldu.`
          :daysLeft===0
            ?`${m.label} bugün sona eriyor.`
            :`${m.label} için ${daysLeft} gün kaldı.`;
        await pool.query(
          `INSERT INTO vehicle_notifications(vehicle_id,type,message,status,created_at)
           VALUES($1,'message',$2,'new',NOW())`,
          [x.vehicle_id,`Hatırlatma • ${x.plate}: ${message}`]
        );
        delivered++;
      }
      res.json({ok:true,delivered});
    }catch(e){console.error('vehicle reminder deliver',e);res.status(500).json({error:'SERVER_ERROR'});}
  });
};
