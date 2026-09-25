const jwt=require('jsonwebtoken');
const rateLimit=require('express-rate-limit');

function jwtSecret(){
  const secret=String(process.env.JWT_SECRET||'');
  if(secret.length<32)throw new Error('JWT_SECRET must be at least 32 characters');
  return secret;
}

function bearer(req){
  const header=String(req.headers?.authorization||'').trim();
  if(!header.toLowerCase().startsWith('bearer '))return null;
  return header.slice(7).trim()||null;
}

function createAdminGuard(pool){
  return async function adminAuth(req,res,next){
    const token=bearer(req);
    if(!token)return res.status(401).json({error:'UNAUTHORIZED'});
    try{
      const payload=jwt.verify(token,jwtSecret(),{algorithms:['HS256']});
      if(payload.role!=='admin')return res.status(403).json({error:'ADMIN_REQUIRED'});
      const id=String(payload.sub||payload.id||'').trim();
      if(!id)return res.status(401).json({error:'INVALID_TOKEN'});
      const r=await pool.query(
        "SELECT id::text AS id,email,display_name,role,status FROM users WHERE id::text=$1 AND role='admin' AND status='active' LIMIT 1",
        [id]
      );
      if(!r.rows.length)return res.status(403).json({error:'ADMIN_REQUIRED'});
      req.admin=r.rows[0];
      req.user=r.rows[0];
      return next();
    }catch(_){
      return res.status(401).json({error:'INVALID_TOKEN'});
    }
  };
}

function registerAdminAuthRoutes(app,pool){
  jwtSecret();
  const loginLimiter=rateLimit({
    windowMs:15*60*1000,
    limit:10,
    standardHeaders:'draft-7',
    legacyHeaders:false,
    skipSuccessfulRequests:true,
    message:{error:'TOO_MANY_ATTEMPTS'},
  });

  app.post('/api/admin/login',loginLimiter,async(req,res)=>{
    const email=String(req.body?.email||'').trim().toLowerCase();
    const password=String(req.body?.password||'');
    if(!email||!password)return res.status(400).json({error:'EMAIL_PASSWORD_REQUIRED'});
    try{
      const result=await pool.query(
        `SELECT id::text AS id,email,display_name,role,status
           FROM users
          WHERE lower(email)=$1
            AND password_hash=crypt($2,password_hash)
          LIMIT 1`,
        [email,password]
      );
      if(!result.rows.length)return res.status(401).json({error:'INVALID_CREDENTIALS'});
      const user=result.rows[0];
      if(user.status!=='active'||user.role!=='admin'){
        return res.status(403).json({error:'ADMIN_REQUIRED'});
      }
      const token=jwt.sign(
        {sub:user.id,email:user.email,role:user.role},
        jwtSecret(),
        {algorithm:'HS256',expiresIn:'8h'}
      );
      return res.json({
        token,
        user:{
          id:user.id,
          email:user.email,
          display_name:user.display_name,
          role:user.role,
        },
      });
    }catch(e){
      console.error('admin login',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  return createAdminGuard(pool);
}

module.exports={registerAdminAuthRoutes,createAdminGuard};
