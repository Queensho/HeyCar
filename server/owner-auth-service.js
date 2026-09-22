const crypto=require('crypto');
const ACCESS_TTL_SECONDS=15*60;
const REFRESH_TTL_DAYS=30;
function secret(){const s=process.env.OWNER_AUTH_SECRET||'';if(s.length<32)throw new Error('OWNER_AUTH_SECRET must be at least 32 characters');return s;}
function b64(v){return Buffer.from(v).toString('base64url');}
function sign(payload){const head=b64(JSON.stringify({alg:'HS256',typ:'JWT'}));const body=b64(JSON.stringify(payload));const sig=crypto.createHmac('sha256',secret()).update(head+'.'+body).digest('base64url');return head+'.'+body+'.'+sig;}
function verify(token){try{const [h,b,s]=String(token||'').split('.');if(!h||!b||!s)return null;const expected=crypto.createHmac('sha256',secret()).update(h+'.'+b).digest();const got=Buffer.from(s,'base64url');if(got.length!==expected.length||!crypto.timingSafeEqual(got,expected))return null;const p=JSON.parse(Buffer.from(b,'base64url').toString());if(p.typ!=='owner'||!p.sub||!p.exp||p.exp<=Math.floor(Date.now()/1000))return null;return p;}catch(_){return null;}}
function accessToken(ownerId){const now=Math.floor(Date.now()/1000);return sign({sub:String(ownerId),typ:'owner',iat:now,exp:now+ACCESS_TTL_SECONDS});}
function hash(v){return crypto.createHash('sha256').update(v).digest('hex');}
async function issueTokens(db,ownerId){const refresh=crypto.randomBytes(48).toString('base64url');await db.query("INSERT INTO owner_auth_sessions(owner_id,refresh_token_hash,expires_at) VALUES($1,$2,now()+interval '30 days')",[ownerId,hash(refresh)]);return{accessToken:accessToken(ownerId),refreshToken:refresh,expiresIn:ACCESS_TTL_SECONDS};}
function bearer(req){const h=String(req.headers.authorization||'');return h.toLowerCase().startsWith('bearer ')?h.slice(7).trim():'';}
function ownerId(req){const p=verify(bearer(req));return p?String(p.sub):'';}
async function rotateRefresh(db,refresh){const h=hash(refresh);const c=await db.connect();try{await c.query('BEGIN');const r=await c.query("SELECT id,owner_id FROM owner_auth_sessions WHERE refresh_token_hash=$1 AND revoked_at IS NULL AND expires_at>now() FOR UPDATE",[h]);if(!r.rows.length){await c.query('ROLLBACK');return null;}await c.query('UPDATE owner_auth_sessions SET revoked_at=now() WHERE id=$1',[r.rows[0].id]);const out=await issueTokens(c,r.rows[0].owner_id);await c.query('COMMIT');return out;}catch(e){await c.query('ROLLBACK').catch(()=>{});throw e;}finally{c.release();}}
async function revokeRefresh(db,refresh){if(!refresh)return;await db.query('UPDATE owner_auth_sessions SET revoked_at=now() WHERE refresh_token_hash=$1',[hash(refresh)]);}
module.exports={issueTokens,rotateRefresh,revokeRefresh,ownerId,verify,ACCESS_TTL_SECONDS,REFRESH_TTL_DAYS};