// Editorial placements are separate from business-created nearby campaigns.
module.exports = function registerOfferEditorialRoutes(app,pool,adminGuard){
 const fields='id,placement,title,description,badge,image_url,target_url,is_active,sort_order';
 app.get('/api/offers/editorial',async(req,res)=>{
  try{const r=await pool.query(`SELECT ${fields} FROM offer_editorial WHERE is_active=true ORDER BY sort_order ASC,created_at DESC LIMIT 60`);
   res.json({offers:r.rows});}catch(e){console.error('offer editorial public',e);res.status(503).json({error:'EDITORIAL_UNAVAILABLE'});}
 });
 app.get('/api/admin/manage/offer-editorial',adminGuard,async(req,res)=>{
  try{const r=await pool.query(`SELECT ${fields} FROM offer_editorial ORDER BY placement,sort_order,created_at DESC LIMIT 200`);
   res.json({offers:r.rows});}catch(e){console.error('offer editorial admin',e);res.status(503).json({error:'EDITORIAL_UNAVAILABLE'});}
 });
 app.post('/api/admin/manage/offer-editorial',adminGuard,async(req,res)=>{
  const x=req.body||{};
  if(!['personal','featured'].includes(x.placement)||!String(x.title||'').trim()||String(x.title).length>120)return res.status(400).json({error:'INVALID_OFFER'});
  try{const r=await pool.query(`INSERT INTO offer_editorial(placement,title,description,badge,image_url,target_url,is_active,sort_order)
  VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING ${fields}`,[
   x.placement,String(x.title).trim(),String(x.description||'').slice(0,500),String(x.badge||'').slice(0,60),
   String(x.image_url||'').slice(0,1000),String(x.target_url||'').slice(0,1000),x.is_active===true,
   Number.isInteger(x.sort_order)?x.sort_order:0]);res.status(201).json({offer:r.rows[0]});}
   catch(e){console.error('offer editorial create',e);res.status(500).json({error:'CREATE_FAILED'});}
 });
 app.patch('/api/admin/manage/offer-editorial/:id',adminGuard,async(req,res)=>{
  const x=req.body||{};
  if(x.placement!==undefined&&!['personal','featured'].includes(x.placement))return res.status(400).json({error:'INVALID_PLACEMENT'});
  const allowed=['placement','title','description','badge','image_url','target_url','is_active','sort_order'];
  const keys=allowed.filter(k=>Object.prototype.hasOwnProperty.call(x,k));
  if(!keys.length)return res.status(400).json({error:'NO_CHANGES'});
  if(keys.includes('title')&&(!String(x.title||'').trim()||String(x.title).length>120))return res.status(400).json({error:'INVALID_TITLE'});
  const values=keys.map(k=>k==='is_active'?x[k]===true:k==='sort_order'?(Number.isInteger(x[k])?x[k]:0):String(x[k]||'').slice(0,k==='description'?500:k==='title'?120:k==='badge'?60:1000));
  try{const r=await pool.query(`UPDATE offer_editorial SET ${keys.map((k,i)=>k+'=$'+(i+1)).join(',')},updated_at=now() WHERE id=$${keys.length+1} RETURNING ${fields}`,[...values,req.params.id]);
   if(!r.rows.length)return res.status(404).json({error:'NOT_FOUND'});res.json({offer:r.rows[0]});}
   catch(e){console.error('offer editorial update',e);res.status(500).json({error:'UPDATE_FAILED'});}
 });
 app.delete('/api/admin/manage/offer-editorial/:id',adminGuard,async(req,res)=>{
  try{const r=await pool.query('DELETE FROM offer_editorial WHERE id=$1 RETURNING id',[req.params.id]);if(!r.rows.length)return res.status(404).json({error:'NOT_FOUND'});res.json({ok:true});}
  catch(e){console.error('offer editorial delete',e);res.status(500).json({error:'DELETE_FAILED'});}
 });
};
