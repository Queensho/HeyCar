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
    const r=await pool.query('SELECT (COALESCE(premium,false)=TRUE AND (premium_expires_at IS NULL OR premium_expires_at>NOW())) AS premium FROM users WHERE id::text=$1 LIMIT 1',[ownerId]);
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

    const client=await pool.connect();
    let runId=null;
    let locked=false;
    try{
      await ensureSchema();
      const schema=await client.query("SELECT to_regclass('public.vehicle_reminder_job_runs') AS jobs,to_regclass('public.vehicle_reminder_deliveries') AS deliveries");
      if(!schema.rows[0]?.jobs||!schema.rows[0]?.deliveries)return res.status(503).json({error:'REMINDER_JOB_MIGRATION_REQUIRED'});

      const lock=await client.query('SELECT pg_try_advisory_lock($1) AS locked',[73194015]);
      locked=lock.rows[0]?.locked===true;
      if(!locked)return res.status(409).json({error:'REMINDER_JOB_ALREADY_RUNNING'});

      const source=String(req.body?.source||'systemd').trim().slice(0,40)||'systemd';
      const started=await client.query(
        `INSERT INTO vehicle_reminder_job_runs(source,status)
         VALUES($1,'running') RETURNING id,started_at`,
        [source]
      );
      runId=started.rows[0].id;

      const r=await client.query(
        `SELECT vr.*,v.plate,
                (vr.due_date - ((NOW() AT TIME ZONE 'Europe/Istanbul')::date))::int AS days_left
           FROM vehicle_reminders vr
           JOIN vehicles v ON v.id::text=vr.vehicle_id
           JOIN users u ON u.id::text=vr.owner_id
          WHERE vr.enabled=TRUE
            AND COALESCE(u.premium,false)=TRUE
            AND (u.premium_expires_at IS NULL OR u.premium_expires_at>NOW())`
      );

      let eligible=0,createdCount=0,duplicateSkips=0,pushAttempted=0,pushDelivered=0;
      for(const x of r.rows){
        const daysLeft=Number(x.days_left);
        const m=meta[x.type]||{label:x.type,days:[7,1]};
        if(!(daysLeft<=0||m.days.includes(daysLeft)))continue;
        eligible++;
        const milestone=daysLeft<=0?0:daysLeft;
        const message=daysLeft<0
          ?`${m.label} süresi ${-daysLeft} gün önce doldu.`
          :daysLeft===0
            ?`${m.label} bugün sona eriyor.`
            :`${m.label} için ${daysLeft} gün kaldı.`;
        const fullMessage=`Hatırlatma • ${x.plate}: ${message}`;

        const created=await client.query(
          `WITH delivery AS (
             INSERT INTO vehicle_reminder_deliveries(vehicle_id,owner_id,reminder_type,due_date,milestone_days)
             VALUES($1,$2,$3,$4,$5)
             ON CONFLICT(vehicle_id,reminder_type,due_date,milestone_days) DO NOTHING
             RETURNING id
           ),
           notification AS (
             INSERT INTO vehicle_notifications(vehicle_id,type,message,status,created_at)
             SELECT $6::uuid,'message',$7,'new',NOW() FROM delivery
             RETURNING id
           ),
           linked AS (
             UPDATE vehicle_reminder_deliveries d
                SET notification_id=n.id
               FROM delivery dl CROSS JOIN notification n
              WHERE d.id=dl.id
             RETURNING d.id,n.id AS notification_id
           )
           SELECT id,notification_id FROM linked`,
          [x.vehicle_id,x.owner_id,x.type,x.due_date,milestone,x.vehicle_id,fullMessage]
        );

        if(!created.rows.length){
          duplicateSkips++;
          continue;
        }

        createdCount++;
        const deliveryId=created.rows[0].id;
        const notificationId=created.rows[0].notification_id;
        const push=app.locals.heycarPush;
        if(push&&typeof push.sendOwner==='function'){
          try{
            const out=await push.sendOwner(
              String(x.owner_id),
              {
                type:'vehicle_reminder',
                sourceType:'vehicle_reminder',
                vehicleId:String(x.vehicle_id),
                reminderType:String(x.type),
                dueDate:String(x.due_date).slice(0,10),
                milestoneDays:String(milestone),
                notificationId:String(notificationId),
              },
              'Araç Hatırlatma',
              fullMessage
            );
            const attempted=Number(out?.attempted||0);
            const delivered=Number(out?.delivered||0);
            pushAttempted+=attempted;
            pushDelivered+=delivered;
            await client.query(
              `UPDATE vehicle_reminder_deliveries
                  SET push_attempted=$2,push_delivered=$3,push_attempted_at=NOW(),
                      push_error=CASE WHEN $2>0 AND $3=0 THEN 'FCM_DELIVERY_FAILED' ELSE NULL END
                WHERE id=$1`,
              [deliveryId,attempted,delivered]
            );
          }catch(pushError){
            await client.query(
              `UPDATE vehicle_reminder_deliveries
                  SET push_attempted_at=NOW(),push_error=$2
                WHERE id=$1`,
              [deliveryId,String(pushError?.message||pushError).slice(0,800)]
            );
            console.error('vehicle reminder push',pushError);
          }
        }
      }

      const finished=await client.query(
        `UPDATE vehicle_reminder_job_runs
            SET status='success',finished_at=NOW(),eligible_count=$2,
                created_notifications=$3,duplicate_skips=$4,
                push_attempted=$5,push_delivered=$6,error=NULL
          WHERE id=$1
          RETURNING *`,
        [runId,eligible,createdCount,duplicateSkips,pushAttempted,pushDelivered]
      );
      return res.json({
        ok:true,
        run:finished.rows[0],
        delivered:createdCount,
        duplicateSkips,
        push:{attempted:pushAttempted,delivered:pushDelivered},
      });
    }catch(e){
      if(runId){
        try{
          await client.query(
            `UPDATE vehicle_reminder_job_runs
                SET status='failed',finished_at=NOW(),error=$2
              WHERE id=$1`,
            [runId,String(e?.message||e).slice(0,1200)]
          );
        }catch(_){}
      }
      console.error('vehicle reminder deliver',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }finally{
      if(locked){
        try{await client.query('SELECT pg_advisory_unlock($1)',[73194015]);}catch(_){}
      }
      client.release();
    }
  });
};
