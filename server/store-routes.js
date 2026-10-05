const crypto=require('crypto');
const {ownerId}=require('./owner-auth-service');
const {writeAdminAudit}=require('./admin-audit');

function text(v,max=500){return String(v??'').trim().slice(0,max);}
function number(v){const n=Number(v);return Number.isFinite(n)?n:null;}
function integer(v){const n=Number(v);return Number.isInteger(n)?n:null;}
function bool(v,def=false){return typeof v==='boolean'?v:def;}
function features(v){
  if(!Array.isArray(v))return [];
  return v.map(x=>text(x,180)).filter(Boolean).slice(0,20);
}
function productJson(r){
  return {
    id:String(r.id),
    sku:r.sku,
    title:r.title,
    subtitle:r.subtitle||'',
    category:r.category||'Etiketler',
    productType:r.product_type||'vehicle_qr',
    price:r.price==null?null:Number(r.price),
    currency:r.currency||'TRY',
    imageAsset:r.image_asset||null,
    imageUrl:r.image_url||null,
    badge:r.badge||null,
    features:Array.isArray(r.features)?r.features:[],
    active:r.active===true,
    comingSoon:r.coming_soon===true,
    trackStock:r.track_stock===true,
    stockQuantity:r.stock_quantity==null?null:Number(r.stock_quantity),
    sortOrder:Number(r.sort_order||0),
    createdAt:r.created_at,
    updatedAt:r.updated_at,
  };
}
function orderJson(r){
  return {
    id:String(r.id),
    orderNo:r.order_no,
    ownerId:String(r.owner_id),
    ownerName:r.owner_name||null,
    ownerPhone:r.owner_phone||null,
    ownerEmail:r.owner_email||null,
    status:r.status,
    paymentStatus:r.payment_status,
    subtotal:Number(r.subtotal||0),
    shippingFee:Number(r.shipping_fee||0),
    total:Number(r.total||0),
    currency:r.currency||'TRY',
    deliveryName:r.delivery_name,
    deliveryPhone:r.delivery_phone,
    deliveryAddress:r.delivery_address,
    deliveryDistrict:r.delivery_district,
    deliveryCity:r.delivery_city,
    deliveryNote:r.delivery_note||null,
    shippingCompany:r.shipping_company||null,
    trackingNumber:r.tracking_number||null,
    inventoryCommittedAt:r.inventory_committed_at||null,
    paidAt:r.paid_at||null,
    shippedAt:r.shipped_at||null,
    deliveredAt:r.delivered_at||null,
    cancelledAt:r.cancelled_at||null,
    createdAt:r.created_at,
    updatedAt:r.updated_at,
    itemCount:Number(r.item_count||0),
  };
}
async function makeOrderNo(db){
  const day=new Date().toISOString().slice(0,10).replaceAll('-','');
  for(let i=0;i<8;i++){
    const suffix=crypto.randomBytes(3).toString('hex').toUpperCase();
    const value=`CQ-${day}-${suffix}`;
    const r=await db.query('SELECT 1 FROM store_orders WHERE order_no=$1 LIMIT 1',[value]);
    if(!r.rows.length)return value;
  }
  throw new Error('ORDER_NUMBER_EXHAUSTED');
}

module.exports=function registerStoreRoutes(app,pool,adminGuard){
  const guard=typeof adminGuard==='function'
    ? adminGuard
    : (_req,res)=>res.status(500).json({error:'ADMIN_GUARD_NOT_CONFIGURED'});

  app.get('/api/store/products',async(_req,res)=>{
    try{
      const r=await pool.query(
        `SELECT * FROM store_products
          WHERE active=TRUE
          ORDER BY sort_order,title`
      );
      return res.json({ok:true,items:r.rows.map(productJson)});
    }catch(e){
      console.error('store products',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/owner/store/orders',async(req,res)=>{
    const owner=ownerId(req);
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    try{
      const r=await pool.query(
        `SELECT o.*,COUNT(i.id)::int AS item_count
           FROM store_orders o
           LEFT JOIN store_order_items i ON i.order_id=o.id
          WHERE o.owner_id=$1
          GROUP BY o.id
          ORDER BY o.created_at DESC
          LIMIT 100`,
        [owner]
      );
      return res.json({ok:true,items:r.rows.map(orderJson)});
    }catch(e){
      console.error('owner store orders',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.post('/api/owner/store/orders',async(req,res)=>{
    const owner=ownerId(req);
    if(!owner)return res.status(401).json({error:'OWNER_REQUIRED'});
    const body=req.body||{};
    const lines=Array.isArray(body.items)?body.items:[];
    const delivery={
      name:text(body.deliveryName,160),
      phone:text(body.deliveryPhone,60),
      address:text(body.deliveryAddress,800),
      district:text(body.deliveryDistrict,160),
      city:text(body.deliveryCity,160),
      note:text(body.deliveryNote,800)||null,
    };
    if(!lines.length||lines.length>30)return res.status(400).json({error:'ITEMS_REQUIRED'});
    if(delivery.name.length<2||delivery.phone.replace(/\D/g,'').length<10||delivery.address.length<8||!delivery.district||!delivery.city){
      return res.status(400).json({error:'DELIVERY_REQUIRED'});
    }

    const c=await pool.connect();
    try{
      await c.query('BEGIN');
      const normalized=[];
      let subtotal=0;
      for(const raw of lines){
        const productId=text(raw?.productId,80);
        const vehicleId=text(raw?.vehicleId,80);
        const qty=Math.max(1,Math.min(20,integer(raw?.quantity)||1));
        const p=await c.query(
          `SELECT * FROM store_products WHERE id::text=$1 AND active=TRUE FOR SHARE`,
          [productId]
        );
        if(!p.rows.length)throw Object.assign(new Error('PRODUCT_NOT_FOUND'),{status:404});
        const product=p.rows[0];
        if(product.coming_soon||product.price==null)throw Object.assign(new Error('PRODUCT_NOT_FOR_SALE'),{status:409});
        if(product.track_stock&&Number(product.stock_quantity||0)<qty){
          throw Object.assign(new Error('OUT_OF_STOCK'),{status:409});
        }
        if(vehicleId){
          const v=await c.query('SELECT id FROM vehicles WHERE id::text=$1 AND owner_id=$2 LIMIT 1',[vehicleId,owner]);
          if(!v.rows.length)throw Object.assign(new Error('VEHICLE_NOT_OWNED'),{status:403});
        }
        const unit=Number(product.price);
        const total=Number((unit*qty).toFixed(2));
        subtotal=Number((subtotal+total).toFixed(2));
        normalized.push({product,vehicleId:vehicleId||null,qty,unit,total});
      }

      const orderNo=await makeOrderNo(c);
      const order=await c.query(
        `INSERT INTO store_orders(
          order_no,owner_id,status,payment_status,subtotal,shipping_fee,total,currency,
          delivery_name,delivery_phone,delivery_address,delivery_district,delivery_city,delivery_note
        ) VALUES($1,$2,'pending_payment','pending',$3,0,$3,'TRY',$4,$5,$6,$7,$8,$9)
        RETURNING *`,
        [orderNo,owner,subtotal,delivery.name,delivery.phone,delivery.address,delivery.district,delivery.city,delivery.note]
      );
      for(const x of normalized){
        await c.query(
          `INSERT INTO store_order_items(
            order_id,product_id,vehicle_id,sku,title,unit_price,quantity,line_total
          ) VALUES($1,$2,$3,$4,$5,$6,$7,$8)`,
          [order.rows[0].id,x.product.id,x.vehicleId,x.product.sku,x.product.title,x.unit,x.qty,x.total]
        );
      }
      await c.query('COMMIT');
      return res.status(201).json({ok:true,order:orderJson({...order.rows[0],item_count:normalized.reduce((a,x)=>a+x.qty,0)})});
    }catch(e){
      await c.query('ROLLBACK').catch(()=>{});
      console.error('create store order',e);
      return res.status(e.status||500).json({error:e.message||'SERVER_ERROR'});
    }finally{c.release();}
  });

  app.get('/api/admin/manage/store/products',guard,async(_req,res)=>{
    try{
      const r=await pool.query('SELECT * FROM store_products ORDER BY sort_order,title');
      return res.json({ok:true,items:r.rows.map(productJson)});
    }catch(e){
      console.error('admin store products',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.post('/api/admin/manage/store/products',guard,async(req,res)=>{
    const b=req.body||{};
    const sku=text(b.sku,80).toUpperCase();
    const title=text(b.title,180);
    if(!sku||!title)return res.status(400).json({error:'SKU_TITLE_REQUIRED'});
    const price=b.price==null||b.price===''?null:number(b.price);
    const stock=b.stockQuantity==null||b.stockQuantity===''?null:integer(b.stockQuantity);
    if(price!=null&&price<0)return res.status(400).json({error:'INVALID_PRICE'});
    if(stock!=null&&stock<0)return res.status(400).json({error:'INVALID_STOCK'});
    try{
      const r=await pool.query(
        `INSERT INTO store_products(
          sku,title,subtitle,category,product_type,price,currency,image_asset,image_url,badge,
          features,active,coming_soon,track_stock,stock_quantity,sort_order
        ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12,$13,$14,$15,$16)
        RETURNING *`,
        [
          sku,title,text(b.subtitle,500),text(b.category,100)||'Etiketler',text(b.productType,80)||'vehicle_qr',
          price,text(b.currency,3).toUpperCase()||'TRY',text(b.imageAsset,300)||null,text(b.imageUrl,1000)||null,
          text(b.badge,80)||null,JSON.stringify(features(b.features)),bool(b.active,true),bool(b.comingSoon,false),
          bool(b.trackStock,false),stock,integer(b.sortOrder)||0
        ]
      );
      await writeAdminAudit(pool,req,{action:'store_product_created',targetType:'store_product',targetId:r.rows[0].id,targetLabel:title,after:productJson(r.rows[0])});
      return res.status(201).json({ok:true,item:productJson(r.rows[0])});
    }catch(e){
      if(e.code==='23505')return res.status(409).json({error:'SKU_ALREADY_EXISTS'});
      console.error('admin create store product',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.patch('/api/admin/manage/store/products/:id',guard,async(req,res)=>{
    const id=text(req.params.id,80);
    const current=await pool.query('SELECT * FROM store_products WHERE id::text=$1 LIMIT 1',[id]).catch(()=>({rows:[]}));
    if(!current.rows.length)return res.status(404).json({error:'PRODUCT_NOT_FOUND'});
    const before=current.rows[0],b=req.body||{};
    const value=(key,fallback)=>Object.prototype.hasOwnProperty.call(b,key)?b[key]:fallback;
    const priceRaw=value('price',before.price);
    const stockRaw=value('stockQuantity',before.stock_quantity);
    const price=priceRaw==null||priceRaw===''?null:number(priceRaw);
    const stock=stockRaw==null||stockRaw===''?null:integer(stockRaw);
    if(price!=null&&price<0)return res.status(400).json({error:'INVALID_PRICE'});
    if(stock!=null&&stock<0)return res.status(400).json({error:'INVALID_STOCK'});
    try{
      const r=await pool.query(
        `UPDATE store_products SET
          sku=$2,title=$3,subtitle=$4,category=$5,product_type=$6,price=$7,currency=$8,
          image_asset=$9,image_url=$10,badge=$11,features=$12::jsonb,active=$13,coming_soon=$14,
          track_stock=$15,stock_quantity=$16,sort_order=$17,updated_at=NOW()
          WHERE id::text=$1
          RETURNING *`,
        [
          id,text(value('sku',before.sku),80).toUpperCase(),text(value('title',before.title),180),
          text(value('subtitle',before.subtitle),500),text(value('category',before.category),100)||'Etiketler',
          text(value('productType',before.product_type),80)||'vehicle_qr',price,
          text(value('currency',before.currency),3).toUpperCase()||'TRY',
          text(value('imageAsset',before.image_asset),300)||null,text(value('imageUrl',before.image_url),1000)||null,
          text(value('badge',before.badge),80)||null,
          JSON.stringify(Object.prototype.hasOwnProperty.call(b,'features')?features(b.features):(Array.isArray(before.features)?before.features:[])),
          Object.prototype.hasOwnProperty.call(b,'active')?Boolean(b.active):before.active,
          Object.prototype.hasOwnProperty.call(b,'comingSoon')?Boolean(b.comingSoon):before.coming_soon,
          Object.prototype.hasOwnProperty.call(b,'trackStock')?Boolean(b.trackStock):before.track_stock,
          stock,integer(value('sortOrder',before.sort_order))||0
        ]
      );
      if(!r.rows.length)return res.status(404).json({error:'PRODUCT_NOT_FOUND'});
      await writeAdminAudit(pool,req,{action:'store_product_updated',targetType:'store_product',targetId:id,targetLabel:r.rows[0].title,before:productJson(before),after:productJson(r.rows[0])});
      return res.json({ok:true,item:productJson(r.rows[0])});
    }catch(e){
      if(e.code==='23505')return res.status(409).json({error:'SKU_ALREADY_EXISTS'});
      console.error('admin update store product',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/admin/manage/store/orders',guard,async(req,res)=>{
    const status=text(req.query.status,40);
    const params=[];
    let where='';
    if(status&&status!=='all'){params.push(status);where='WHERE o.status=$1';}
    try{
      const r=await pool.query(
        `SELECT o.*,u.display_name AS owner_name,u.phone AS owner_phone,u.email AS owner_email,
                COALESCE(SUM(i.quantity),0)::int AS item_count
           FROM store_orders o
           JOIN users u ON u.id=o.owner_id
           LEFT JOIN store_order_items i ON i.order_id=o.id
           ${where}
          GROUP BY o.id,u.display_name,u.phone,u.email
          ORDER BY o.created_at DESC
          LIMIT 300`,
        params
      );
      return res.json({ok:true,items:r.rows.map(orderJson)});
    }catch(e){
      console.error('admin store orders',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.get('/api/admin/manage/store/orders/:id',guard,async(req,res)=>{
    const id=text(req.params.id,80);
    try{
      const o=await pool.query(
        `SELECT o.*,u.display_name AS owner_name,u.phone AS owner_phone,u.email AS owner_email
           FROM store_orders o JOIN users u ON u.id=o.owner_id
          WHERE o.id::text=$1 LIMIT 1`,
        [id]
      );
      if(!o.rows.length)return res.status(404).json({error:'ORDER_NOT_FOUND'});
      const items=await pool.query(
        `SELECT i.*,p.image_asset,p.image_url,v.plate,v.make,v.model
           FROM store_order_items i
           JOIN store_products p ON p.id=i.product_id
           LEFT JOIN vehicles v ON v.id=i.vehicle_id
          WHERE i.order_id=$1
          ORDER BY i.id`,
        [o.rows[0].id]
      );
      return res.json({ok:true,order:orderJson({...o.rows[0],item_count:items.rows.reduce((a,x)=>a+Number(x.quantity||0),0)}),items:items.rows});
    }catch(e){
      console.error('admin store order detail',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });

  app.patch('/api/admin/manage/store/orders/:id',guard,async(req,res)=>{
    const id=text(req.params.id,80),b=req.body||{};
    const allowed=new Set(['pending_payment','paid','preparing','shipped','delivered','cancelled','refunded']);
    const c=await pool.connect();
    try{
      await c.query('BEGIN');
      const q=await c.query('SELECT * FROM store_orders WHERE id::text=$1 LIMIT 1 FOR UPDATE',[id]);
      if(!q.rows.length){await c.query('ROLLBACK');return res.status(404).json({error:'ORDER_NOT_FOUND'});}
      const before=q.rows[0];
      const nextStatus=Object.prototype.hasOwnProperty.call(b,'status')?text(b.status,40):before.status;
      if(!allowed.has(nextStatus)){await c.query('ROLLBACK');return res.status(400).json({error:'INVALID_STATUS'});}
      const commitInventory=new Set(['paid','preparing','shipped','delivered']).has(nextStatus);
      const releaseInventory=new Set(['cancelled','refunded']).has(nextStatus);

      if(commitInventory&&!before.inventory_committed_at){
        const items=await c.query(
          `SELECT i.product_id,i.quantity,p.track_stock,p.stock_quantity
             FROM store_order_items i
             JOIN store_products p ON p.id=i.product_id
            WHERE i.order_id=$1
            FOR UPDATE OF p`,
          [before.id]
        );
        for(const x of items.rows){
          if(x.track_stock&&Number(x.stock_quantity||0)<Number(x.quantity||0)){
            await c.query('ROLLBACK');
            return res.status(409).json({error:'OUT_OF_STOCK'});
          }
        }
        for(const x of items.rows){
          if(x.track_stock){
            await c.query('UPDATE store_products SET stock_quantity=stock_quantity-$2,updated_at=NOW() WHERE id=$1',[x.product_id,x.quantity]);
          }
        }
      }else if(releaseInventory&&before.inventory_committed_at){
        const items=await c.query(
          `SELECT i.product_id,i.quantity,p.track_stock
             FROM store_order_items i
             JOIN store_products p ON p.id=i.product_id
            WHERE i.order_id=$1
            FOR UPDATE OF p`,
          [before.id]
        );
        for(const x of items.rows){
          if(x.track_stock){
            await c.query('UPDATE store_products SET stock_quantity=COALESCE(stock_quantity,0)+$2,updated_at=NOW() WHERE id=$1',[x.product_id,x.quantity]);
          }
        }
      }

      let paymentStatus=Object.prototype.hasOwnProperty.call(b,'paymentStatus')?text(b.paymentStatus,40):before.payment_status;
      if(commitInventory&&paymentStatus==='pending')paymentStatus='paid';
      if(nextStatus==='refunded')paymentStatus='refunded';
      const r=await c.query(
        `UPDATE store_orders SET
          status=$2,payment_status=$3,
          shipping_company=$4,tracking_number=$5,
          inventory_committed_at=CASE
            WHEN $6::boolean AND inventory_committed_at IS NULL THEN NOW()
            WHEN $7::boolean THEN NULL
            ELSE inventory_committed_at END,
          paid_at=CASE WHEN $6::boolean AND paid_at IS NULL THEN NOW() ELSE paid_at END,
          shipped_at=CASE WHEN $2='shipped' AND shipped_at IS NULL THEN NOW() ELSE shipped_at END,
          delivered_at=CASE WHEN $2='delivered' AND delivered_at IS NULL THEN NOW() ELSE delivered_at END,
          cancelled_at=CASE WHEN $2 IN ('cancelled','refunded') AND cancelled_at IS NULL THEN NOW() ELSE cancelled_at END,
          updated_at=NOW()
          WHERE id::text=$1
          RETURNING *`,
        [
          id,nextStatus,paymentStatus,
          Object.prototype.hasOwnProperty.call(b,'shippingCompany')?text(b.shippingCompany,120)||null:before.shipping_company,
          Object.prototype.hasOwnProperty.call(b,'trackingNumber')?text(b.trackingNumber,160)||null:before.tracking_number,
          commitInventory,releaseInventory
        ]
      );
      await c.query('COMMIT');
      await writeAdminAudit(pool,req,{action:'store_order_updated',targetType:'store_order',targetId:id,targetLabel:r.rows[0].order_no,before:{status:before.status,paymentStatus:before.payment_status},after:{status:r.rows[0].status,paymentStatus:r.rows[0].payment_status,shippingCompany:r.rows[0].shipping_company,trackingNumber:r.rows[0].tracking_number}});
      return res.json({ok:true,order:orderJson(r.rows[0])});
    }catch(e){
      await c.query('ROLLBACK').catch(()=>{});
      console.error('admin update store order',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }finally{c.release();}
  });

  app.get('/api/admin/manage/store/stats',guard,async(_req,res)=>{
    try{
      const [p,o,revenue]=await Promise.all([
        pool.query(`SELECT COUNT(*)::int AS total,
          COUNT(*) FILTER(WHERE active)::int AS active,
          COUNT(*) FILTER(WHERE coming_soon)::int AS coming_soon,
          COUNT(*) FILTER(WHERE track_stock AND COALESCE(stock_quantity,0)<=5)::int AS low_stock
          FROM store_products`),
        pool.query(`SELECT COUNT(*)::int AS total,
          COUNT(*) FILTER(WHERE status='pending_payment')::int AS pending_payment,
          COUNT(*) FILTER(WHERE status IN ('paid','preparing'))::int AS processing,
          COUNT(*) FILTER(WHERE status='shipped')::int AS shipped,
          COUNT(*) FILTER(WHERE status='delivered')::int AS delivered
          FROM store_orders`),
        pool.query(`SELECT
          COALESCE(SUM(total) FILTER(WHERE status IN ('paid','preparing','shipped','delivered')),0) AS gross_revenue,
          COALESCE(SUM(total) FILTER(WHERE status IN ('paid','preparing','shipped','delivered') AND created_at>=NOW()-INTERVAL '30 days'),0) AS revenue_30d,
          COUNT(*) FILTER(WHERE status IN ('paid','preparing','shipped','delivered') AND created_at>=NOW()-INTERVAL '30 days')::int AS orders_30d
          FROM store_orders`)
      ]);
      return res.json({ok:true,products:p.rows[0],orders:o.rows[0],revenue:{grossRevenue:Number(revenue.rows[0]?.gross_revenue||0),revenue30d:Number(revenue.rows[0]?.revenue_30d||0),orders30d:Number(revenue.rows[0]?.orders_30d||0)}});
    }catch(e){
      console.error('admin store stats',e);
      return res.status(500).json({error:'SERVER_ERROR'});
    }
  });
};
