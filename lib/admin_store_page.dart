
import 'dart:convert';

import 'package:flutter/material.dart';
import 'admin_ui.dart';
import 'package:http/http.dart' as http;

const _bg=AdminUi.bg;
const _card=AdminUi.surface;
const _card2=AdminUi.surfaceSoft;
const _purple=AdminUi.purple;
const _purple2=AdminUi.purple2;
const _green=AdminUi.green;
const _amber=AdminUi.amber;
const _muted=AdminUi.muted;
const _line=AdminUi.line;
const _ink=AdminUi.ink;
const _api='https://heycar-api-185-165-46-213.nip.io';

class AdminStorePage extends StatefulWidget{
  const AdminStorePage({super.key,required this.token,required this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminStorePage> createState()=>_AdminStorePageState();
}

class _AdminStorePageState extends State<AdminStorePage>{
  bool loading=true;
  String? error;
  int section=0;
  String orderStatus='all';
  List<Map<String,dynamic>> products=[];
  List<Map<String,dynamic>> orders=[];
  Map<String,dynamic> stats={};
  Map<String,dynamic> storeConfig={};

  Map<String,String> get headers=>{
    'Authorization':'Bearer '+widget.token,
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
  };

  @override void initState(){super.initState();load();}

  Map<String,dynamic> decode(http.Response r){
    try{final d=jsonDecode(r.body);return d is Map?Map<String,dynamic>.from(d):{};}catch(_){return{};}
  }
  String message(Map<String,dynamic> d){
    final e=(d['error']??'').toString();
    const m={
      'SKU_ALREADY_EXISTS':'Bu SKU zaten kullanılıyor.',
      'SKU_TITLE_REQUIRED':'SKU ve ürün adı zorunlu.',
      'INVALID_PRICE':'Fiyat geçersiz.',
      'INVALID_STOCK':'Stok geçersiz.',
      'OUT_OF_STOCK':'Bu sipariş için stok yetersiz.',
      'ORDER_NOT_FOUND':'Sipariş bulunamadı.',
      'PRODUCT_NOT_FOUND':'Ürün bulunamadı.',
    };
    return m[e]??(e.isEmpty?'İşlem başarısız.':e);
  }
  Future<Map<String,dynamic>> getJson(String path)async{
    final r=await http.get(Uri.parse(_api+path),headers:headers).timeout(const Duration(seconds:20));
    final d=decode(r);if(r.statusCode<200||r.statusCode>=300)throw Exception(message(d));return d;
  }
  Future<Map<String,dynamic>> send(String method,String path,Map<String,dynamic> body)async{
    final u=Uri.parse(_api+path);late http.Response r;
    if(method=='POST')r=await http.post(u,headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:20));
    else r=await http.patch(u,headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:20));
    final d=decode(r);if(r.statusCode<200||r.statusCode>=300)throw Exception(message(d));return d;
  }
  Future<void> load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final r=await Future.wait([
        getJson('/api/admin/manage/store/products'),
        getJson('/api/admin/manage/store/orders?status='+orderStatus),
        getJson('/api/admin/manage/store/stats'),
        getJson('/api/admin/manage/store/config'),
      ]);
      if(!mounted)return;
      setState((){
        products=(r[0]['items'] as List? ?? const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
        orders=(r[1]['items'] as List? ?? const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
        stats=r[2];
        storeConfig=Map<String,dynamic>.from(r[3]['config'] as Map? ?? const {});
      });
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> loadOrders(String status)async{
    setState((){orderStatus=status;loading=true;});
    try{
      final d=await getJson('/api/admin/manage/store/orders?status='+status);
      if(mounted)setState(()=>orders=(d['items'] as List? ?? const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList());
    }catch(e){snack(e);}finally{if(mounted)setState(()=>loading=false);}
  }
  void snack(Object e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
  String money(dynamic v){final n=v is num?v.toDouble():double.tryParse(v.toString())??0;return n.toStringAsFixed(2).replaceAll('.',',')+' TL';}
  int intv(dynamic v)=>v is num?v.toInt():int.tryParse(v.toString())??0;

  Widget field(TextEditingController c,String label,{int maxLines=1,TextInputType? keyboard})=>TextField(
    controller:c,maxLines:maxLines,keyboardType:keyboard,decoration:InputDecoration(labelText:label),
  );

  Future<void> editProduct([Map<String,dynamic>? source])async{
    final editing=source!=null;
    final sku=TextEditingController(text:(source?['sku']??'').toString());
    final title=TextEditingController(text:(source?['title']??'').toString());
    final subtitle=TextEditingController(text:(source?['subtitle']??'').toString());
    final category=TextEditingController(text:(source?['category']??'Etiketler').toString());
    final type=TextEditingController(text:(source?['productType']??'vehicle_qr').toString());
    final price=TextEditingController(text:source?['price']==null?'':source!['price'].toString());
    final badge=TextEditingController(text:(source?['badge']??'').toString());
    final asset=TextEditingController(text:(source?['imageAsset']??'').toString());
    final imageUrl=TextEditingController(text:(source?['imageUrl']??'').toString());
    final stock=TextEditingController(text:source?['stockQuantity']==null?'':source!['stockQuantity'].toString());
    final sort=TextEditingController(text:(source?['sortOrder']??0).toString());
    final rawFeatures=source?['features'] is List?(source!['features'] as List).map((e)=>e.toString()).join('\n'):'';
    final featureCtl=TextEditingController(text:rawFeatures);
    var active=source?['active']!=false;
    var coming=source?['comingSoon']==true;
    var track=source?['trackStock']==true;
    var saving=false;

    final ok=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text(editing?'Ürünü Düzenle':'Yeni Ürün'),
      content:SizedBox(width:680,child:SingleChildScrollView(child:Column(children:[
        Row(children:[Expanded(child:field(sku,'SKU')),const SizedBox(width:10),Expanded(child:field(title,'Ürün adı'))]),
        const SizedBox(height:10),field(subtitle,'Kısa açıklama',maxLines:2),
        const SizedBox(height:10),Row(children:[Expanded(child:field(category,'Kategori')),const SizedBox(width:10),Expanded(child:field(type,'Ürün tipi'))]),
        const SizedBox(height:10),Row(children:[
          Expanded(child:field(price,'Fiyat (TL)',keyboard:TextInputType.number)),
          const SizedBox(width:10),Expanded(child:field(badge,'Rozet')),
          const SizedBox(width:10),Expanded(child:field(sort,'Sıra',keyboard:TextInputType.number)),
        ]),
        const SizedBox(height:10),field(asset,'Uygulama asset yolu'),
        const SizedBox(height:10),field(imageUrl,'Görsel URL'),
        const SizedBox(height:10),field(featureCtl,'Özellikler • her satıra bir özellik',maxLines:5),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:saving?null:(v)=>setD(()=>active=v),title:const Text('Mağazada aktif')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:coming,onChanged:saving?null:(v)=>setD(()=>coming=v),title:const Text('Yakında olarak göster')),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:track,onChanged:saving?null:(v)=>setD(()=>track=v),title:const Text('Stok takibi')),
        if(track)field(stock,'Stok adedi',keyboard:TextInputType.number),
      ]))),
      actions:[
        TextButton(onPressed:saving?null:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),
        FilledButton.icon(
          onPressed:saving?null:()async{
            setD(()=>saving=true);
            try{
              final payload=<String,dynamic>{
                'sku':sku.text.trim(),'title':title.text.trim(),'subtitle':subtitle.text.trim(),
                'category':category.text.trim(),'productType':type.text.trim(),
                'price':price.text.trim().isEmpty?null:double.tryParse(price.text.trim().replaceAll(',','.')),
                'currency':'TRY','badge':badge.text.trim().isEmpty?null:badge.text.trim(),
                'imageAsset':asset.text.trim().isEmpty?null:asset.text.trim(),
                'imageUrl':imageUrl.text.trim().isEmpty?null:imageUrl.text.trim(),
                'features':featureCtl.text.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),
                'active':active,'comingSoon':coming,'trackStock':track,
                'stockQuantity':track?int.tryParse(stock.text.trim()):null,
                'sortOrder':int.tryParse(sort.text.trim())??0,
              };
              if(editing)await send('PATCH','/api/admin/manage/store/products/'+source!['id'].toString(),payload);
              else await send('POST','/api/admin/manage/store/products',payload);
              if(d.mounted)Navigator.pop(d,true);
            }catch(e){snack(e);setD(()=>saving=false);}
          },
          icon:saving?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded),
          label:Text(editing?'Kaydet':'Ürün Ekle'),
        ),
      ],
    )));
    for(final c in [sku,title,subtitle,category,type,price,badge,asset,imageUrl,stock,sort,featureCtl]){c.dispose();}
    if(ok==true)await load();
  }

  Widget statusBadge(String status){
    final item=switch(status){
      'paid'=>('Ödendi',_green),
      'preparing'=>('Hazırlanıyor',_amber),
      'shipped'=>('Kargoda',const Color(0xFF499DFF)),
      'delivered'=>('Teslim',_green),
      'cancelled'=>('İptal',Colors.redAccent),
      'refunded'=>('İade',Colors.redAccent),
      _=>('Ödeme Bekliyor',_muted),
    };
    return Container(
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
      decoration:BoxDecoration(color:item.$2.withValues(alpha:.12),borderRadius:BorderRadius.circular(9)),
      child:Text(item.$1,style:TextStyle(color:item.$2,fontSize:9.5,fontWeight:FontWeight.w900)),
    );
  }
  Widget miniBadge(String label,Color color)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
    decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(8)),
    child:Text(label,style:TextStyle(color:color,fontSize:8.5,fontWeight:FontWeight.w900)),
  );

  Future<void> openOrder(Map<String,dynamic> row)async{
    try{
      final d=await getJson('/api/admin/manage/store/orders/'+row['id'].toString());
      if(!mounted)return;
      final order=Map<String,dynamic>.from(d['order'] as Map? ?? const {});
      final items=(d['items'] as List? ?? const []).whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList();
      var status=(order['status']??'pending_payment').toString();
      final shipping=TextEditingController(text:(order['shippingCompany']??'').toString());
      final tracking=TextEditingController(text:(order['trackingNumber']??'').toString());
      var saving=false;
      final changed=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setD)=>AlertDialog(
        title:Row(children:[Expanded(child:Text((order['orderNo']??'Sipariş').toString(),style:const TextStyle(fontWeight:FontWeight.w900))),statusBadge(status)]),
        content:SizedBox(width:760,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(
            padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(14),border:Border.all(color:_line)),
            child:Column(children:[
              info('Müşteri',(order['ownerName']??'-').toString()),
              info('Telefon',(order['deliveryPhone']??'-').toString()),
              info('Adres',(order['deliveryAddress']??'-').toString()+' • '+(order['deliveryDistrict']??'').toString()+' / '+(order['deliveryCity']??'').toString()),
              info('Tutar',money(order['total'])),
            ]),
          ),
          const SizedBox(height:14),const Text('Ürünler',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)),const SizedBox(height:8),
          ...items.map((x)=>Container(
            margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(13),border:Border.all(color:_line)),
            child:Row(children:[
              const Icon(Icons.inventory_2_outlined,color:_purple),const SizedBox(width:9),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((x['title']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
                Text((x['sku']??'-').toString()+' • '+(x['plate']??'Araç seçilmedi').toString(),style:const TextStyle(color:_muted,fontSize:11)),
              ])),
              Text((x['quantity']??0).toString()+' × '+money(x['unit_price']),style:const TextStyle(fontWeight:FontWeight.w800)),
            ]),
          )),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(
            value:status,decoration:const InputDecoration(labelText:'Sipariş durumu'),
            items:const[
              DropdownMenuItem(value:'pending_payment',child:Text('Ödeme Bekliyor')),
              DropdownMenuItem(value:'paid',child:Text('Ödendi')),
              DropdownMenuItem(value:'preparing',child:Text('Hazırlanıyor')),
              DropdownMenuItem(value:'shipped',child:Text('Kargoda')),
              DropdownMenuItem(value:'delivered',child:Text('Teslim Edildi')),
              DropdownMenuItem(value:'cancelled',child:Text('İptal')),
              DropdownMenuItem(value:'refunded',child:Text('İade')),
            ],
            onChanged:saving?null:(v)=>setD(()=>status=v??status),
          ),
          const SizedBox(height:10),
          Row(children:[Expanded(child:field(shipping,'Kargo firması')),const SizedBox(width:10),Expanded(child:field(tracking,'Takip numarası'))]),
        ]))),
        actions:[
          TextButton(onPressed:saving?null:()=>Navigator.pop(c,false),child:const Text('Kapat')),
          FilledButton.icon(
            onPressed:saving?null:()async{
              setD(()=>saving=true);
              try{
                await send('PATCH','/api/admin/manage/store/orders/'+order['id'].toString(),{
                  'status':status,'shippingCompany':shipping.text.trim(),'trackingNumber':tracking.text.trim(),
                });
                if(c.mounted)Navigator.pop(c,true);
              }catch(e){snack(e);setD(()=>saving=false);}
            },
            icon:saving?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded),
            label:const Text('Güncelle'),
          ),
        ],
      )));
      shipping.dispose();tracking.dispose();
      if(changed==true)await load();
    }catch(e){snack(e);}
  }
  Widget info(String label,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:85,child:Text(label,style:const TextStyle(color:_muted,fontSize:11,fontWeight:FontWeight.w700))),
      Expanded(child:Text(value,style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w800))),
    ]),
  );

  Widget statCard(String label,String value,IconData icon,Color color)=>Container(
    padding:const EdgeInsets.all(13),
    decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(17),border:Border.all(color:_line)),
    child:Row(children:[
      Container(width:41,height:41,decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:color,size:21)),
      const SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_ink,fontSize:18,fontWeight:FontWeight.w900)),
        Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10.5)),
      ])),
    ]),
  );
  Widget statsView(){
    final p=stats['products'] is Map?Map<String,dynamic>.from(stats['products'] as Map):<String,dynamic>{};
    final o=stats['orders'] is Map?Map<String,dynamic>.from(stats['orders'] as Map):<String,dynamic>{};
    final r=stats['revenue'] is Map?Map<String,dynamic>.from(stats['revenue'] as Map):<String,dynamic>{};
    return LayoutBuilder(builder:(_,c){
      final cols=c.maxWidth<740?2:4;
      final w=(c.maxWidth-(cols-1)*9)/cols;
      final cards=[
        statCard('Aktif ürün',(p['active']??0).toString(),Icons.inventory_2_outlined,_purple),
        statCard('Kritik stok',(p['low_stock']??0).toString(),Icons.warning_amber_rounded,_amber),
        statCard('İşlenen sipariş',(o['processing']??0).toString(),Icons.local_shipping_outlined,const Color(0xFF499DFF)),
        statCard('30 günlük ciro',money(r['revenue30d']),Icons.payments_outlined,_green),
      ];
      return Wrap(spacing:9,runSpacing:9,children:cards.map((x)=>SizedBox(width:w,child:x)).toList());
    });
  }

  Widget productsView()=>Column(children:[
    Row(children:[
      const Expanded(child:Text('Ürünler',style:TextStyle(color:_ink,fontSize:17,fontWeight:FontWeight.w900))),
      FilledButton.icon(onPressed:()=>editProduct(),style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white),icon:const Icon(Icons.add_rounded),label:const Text('Ürün Ekle')),
    ]),
    const SizedBox(height:10),
    ...products.map((p)=>Container(
      margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),
      decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),
      child:Row(children:[
        Container(width:45,height:45,decoration:BoxDecoration(gradient:const LinearGradient(colors:[_purple2,_purple]),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.sell_outlined,color:Colors.white,size:22)),
        const SizedBox(width:10),
        Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Flexible(child:Text((p['title']??'-').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900))),
            if(p['comingSoon']==true)...[const SizedBox(width:6),miniBadge('Yakında',_purple)],
            if(p['active']!=true)...[const SizedBox(width:6),miniBadge('Pasif',Colors.redAccent)],
          ]),
          const SizedBox(height:3),
          Text((p['sku']??'-').toString()+' • '+(p['category']??'-').toString(),style:const TextStyle(color:_muted,fontSize:10.5)),
        ])),
        Expanded(child:Text(p['price']==null?'-':money(p['price']),textAlign:TextAlign.right,style:const TextStyle(fontWeight:FontWeight.w900))),
        const SizedBox(width:16),
        SizedBox(width:92,child:Text(p['trackStock']==true?(p['stockQuantity']??0).toString()+' stok':'Stok takipsiz',textAlign:TextAlign.right,style:const TextStyle(color:_muted,fontSize:10.5))),
        const SizedBox(width:8),
        IconButton(tooltip:'Düzenle',onPressed:()=>editProduct(p),icon:const Icon(Icons.edit_outlined,color:_purple)),
      ]),
    )),
  ]);

  Widget ordersView()=>Column(children:[
    Row(children:[
      const Expanded(child:Text('Siparişler',style:TextStyle(color:_ink,fontSize:17,fontWeight:FontWeight.w900))),
      SizedBox(width:190,child:DropdownButtonFormField<String>(
        value:orderStatus,decoration:const InputDecoration(labelText:'Durum',isDense:true),
        items:const[
          DropdownMenuItem(value:'all',child:Text('Tümü')),
          DropdownMenuItem(value:'pending_payment',child:Text('Ödeme Bekliyor')),
          DropdownMenuItem(value:'paid',child:Text('Ödendi')),
          DropdownMenuItem(value:'preparing',child:Text('Hazırlanıyor')),
          DropdownMenuItem(value:'shipped',child:Text('Kargoda')),
          DropdownMenuItem(value:'delivered',child:Text('Teslim')),
          DropdownMenuItem(value:'cancelled',child:Text('İptal')),
          DropdownMenuItem(value:'refunded',child:Text('İade')),
        ],
        onChanged:(v){if(v!=null)loadOrders(v);},
      )),
    ]),
    const SizedBox(height:10),
    if(orders.isEmpty)Container(
      width:double.infinity,padding:const EdgeInsets.all(28),
      decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),
      child:const Column(children:[Icon(Icons.receipt_long_outlined,color:_muted,size:40),SizedBox(height:8),Text('Henüz sipariş yok.',style:TextStyle(color:_muted,fontWeight:FontWeight.w700))]),
    )
    else ...orders.map((o)=>InkWell(
      onTap:()=>openOrder(o),borderRadius:BorderRadius.circular(16),
      child:Container(
        margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(11),
        decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),
        child:Row(children:[
          const Icon(Icons.receipt_long_rounded,color:_purple,size:27),const SizedBox(width:10),
          Expanded(flex:2,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text((o['orderNo']??'-').toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
            const SizedBox(height:2),
            Text((o['ownerName']??'-').toString()+' • '+(o['itemCount']??0).toString()+' ürün',style:const TextStyle(color:_muted,fontSize:10.5)),
          ])),
          Expanded(child:Text(money(o['total']),textAlign:TextAlign.right,style:const TextStyle(fontWeight:FontWeight.w900))),
          const SizedBox(width:14),statusBadge((o['status']??'').toString()),const SizedBox(width:5),
          const Icon(Icons.chevron_right_rounded,color:_muted),
        ]),
      ),
    )),
  ]);

  Widget sectionButton(int index,String label,IconData icon){
    final selected=section==index;
    return InkWell(
      onTap:()=>setState(()=>section=index),borderRadius:BorderRadius.circular(12),
      child:Container(
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
        decoration:BoxDecoration(
          gradient:selected?const LinearGradient(colors:[_purple2,_purple]):null,
          color:selected?null:_card,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:selected?_purple:_line),
        ),
        child:Row(children:[
          Icon(icon,color:selected?Colors.white:_muted,size:18),const SizedBox(width:7),
          Text(label,style:TextStyle(color:selected?Colors.white:_muted,fontSize:11,fontWeight:FontWeight.w900)),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context)=>ColoredBox(
    color:_bg,
    child:RefreshIndicator(
      onRefresh:load,color:_purple,
      child:ListView(
        physics:const AlwaysScrollableScrollPhysics(),
        padding:const EdgeInsets.fromLTRB(16,14,16,26),
        children:[
          statsView(),const SizedBox(height:16),
          Row(children:[
            sectionButton(0,'Ürün Yönetimi',Icons.inventory_2_outlined),const SizedBox(width:8),
            sectionButton(1,'Siparişler',Icons.receipt_long_outlined),const Spacer(),
            IconButton(tooltip:'Yenile',onPressed:loading?null:load,icon:const Icon(Icons.refresh_rounded)),
          ]),
          if(error!=null)...[
            const SizedBox(height:10),
            Container(
              padding:const EdgeInsets.all(11),
              decoration:BoxDecoration(color:Colors.redAccent.withValues(alpha:.08),borderRadius:BorderRadius.circular(12),border:Border.all(color:Colors.redAccent.withValues(alpha:.25))),
              child:Text(error!,style:const TextStyle(color:Colors.redAccent)),
            ),
          ],
          const SizedBox(height:14),
          if(loading&&products.isEmpty&&orders.isEmpty)
            const Center(child:Padding(padding:EdgeInsets.all(40),child:CircularProgressIndicator(color:_purple)))
          else if(section==0)productsView()
          else ordersView(),
        ],
      ),
    ),
  );
}
