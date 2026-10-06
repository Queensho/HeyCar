import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'admin_ui.dart';

class AdminStoryManagementPage extends StatefulWidget{
  const AdminStoryManagementPage({super.key,required this.token,this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminStoryManagementPage> createState()=>_AdminStoryManagementPageState();
}

class _AdminStoryManagementPageState extends State<AdminStoryManagementPage>{
  static const api='https://heycar-api-185-165-46-213.nip.io';
  List<Map<String,dynamic>> stories=[];
  List<Map<String,dynamic>> categories=[];
  bool loading=true,reordering=false;
  String? error;

  Map<String,String> get headers=>{
    'Authorization':'Bearer ${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
  };

  @override void initState(){super.initState();load();}

  Map<String,dynamic> _decode(http.Response r){
    try{final x=jsonDecode(r.body);return x is Map?Map<String,dynamic>.from(x):{};}catch(_){return{};}
  }
  String _message(Map<String,dynamic> d)=>switch((d['error']??'').toString()){
    'REQUIRED_FIELDS_MISSING'=>'Başlık, küçük görsel ve story görseli zorunlu.',
    'INVALID_ACTION_TARGET'=>'CTA hedefi geçersiz.',
    'INVALID_DATE_RANGE'=>'Başlangıç/bitiş tarih aralığı geçersiz.',
    'CITY_REQUIRED_FOR_DISTRICT'=>'İlçe hedefi için şehir seçmelisin.',
    'INVALID_CATEGORY'=>'Kategori bulunamadı.',
    'IMAGE_TOO_LARGE'=>'Görsel 3 MB sınırını aşıyor.',
    'INVALID_IMAGE_TYPE'=>'Sadece JPG, PNG veya WEBP yüklenebilir.',
    _=>(d['message']??d['error']??'İşlem başarısız.').toString(),
  };

  Future<Map<String,dynamic>> request(String method,String path,[Map<String,dynamic>? body])async{
    final uri=Uri.parse('$api$path');late http.Response r;
    if(method=='GET')r=await http.get(uri,headers:headers);
    else if(method=='POST')r=await http.post(uri,headers:headers,body:jsonEncode(body??{}));
    else if(method=='PATCH')r=await http.patch(uri,headers:headers,body:jsonEncode(body??{}));
    else r=await http.delete(uri,headers:headers);
    final d=_decode(r);
    if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
    return d;
  }

  Future<void> load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final d=await request('GET','/api/admin/manage/stories');
      final s=d['items'],c=d['categories'];
      if(mounted)setState((){
        stories=s is List?s.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
        categories=c is List?c.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():[];
      });
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<String> upload(XFile file,String kind)async{
    final bytes=await file.readAsBytes();
    if(bytes.length>3*1024*1024)throw Exception('Görsel 3 MB sınırını aşıyor.');
    final n=file.name.toLowerCase();
    final mime=n.endsWith('.png')?'image/png':n.endsWith('.webp')?'image/webp':'image/jpeg';
    final h=Map<String,String>.from(headers)
      ..['Content-Type']='application/octet-stream'
      ..['X-File-Type']=mime
      ..['X-File-Name']=file.name;
    final r=await http.put(Uri.parse('$api/api/admin/manage/stories/media/$kind'),headers:h,body:bytes);
    final d=_decode(r);
    if(r.statusCode<200||r.statusCode>=300)throw Exception(_message(d));
    final url=(d['url']??'').toString();
    if(url.isEmpty)throw Exception('Görsel yüklenemedi.');
    return url;
  }

  String statusLabel(Map<String,dynamic> s)=>switch((s['displayStatus']??s['status']??'').toString()){
    'live'=>'Yayında','scheduled'=>'Planlandı','expired'=>'Süresi Doldu','inactive'=>'Pasif','draft'=>'Taslak',_=>'Taslak'
  };
  Color statusColor(Map<String,dynamic> s)=>switch((s['displayStatus']??s['status']??'').toString()){
    'live'=>AdminUi.green,'scheduled'=>AdminUi.blue,'expired'=>AdminUi.muted,'inactive'=>Colors.redAccent,_=>AdminUi.amber
  };
  String dateText(dynamic raw){
    final d=DateTime.tryParse((raw??'').toString())?.toLocal();if(d==null)return '-';
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  Future<DateTime?> pickDateTime(BuildContext context,DateTime initial)async{
    final date=await showDatePicker(context:context,initialDate:initial,firstDate:DateTime.now().subtract(const Duration(days:365)),lastDate:DateTime.now().add(const Duration(days:3650)));
    if(date==null||!context.mounted)return null;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(initial));
    if(time==null)return null;
    return DateTime(date.year,date.month,date.day,time.hour,time.minute);
  }

  List<DropdownMenuItem<String>> actionTargets(String actionType){
    final values=switch(actionType){
      'IN_APP_PAGE'=>const [('premium','Premium'),('services','Hizmetler'),('vehicles','Araçlarım'),('notifications','Bildirimler'),('settings','Profil / Ayarlar'),('qr_security','QR Güvenliği'),('maintenance','Bakım'),('parking','Park'),('offers','Fırsatlar')],
      'SERVICE'=>const [('towing','Çekici'),('valet','Vale'),('roadside_help','Yol Yardım'),('parking','Otopark'),('maintenance','Bakım / Servis'),('offers','Fırsatlar')],
      _=>const <(String,String)>[],
    };
    return values.map((e)=>DropdownMenuItem(value:e.$1,child:Text(e.$2))).toList();
  }

  Future<void> edit([Map<String,dynamic>? existing])async{
    final editing=existing!=null;
    final title=TextEditingController(text:(existing?['title']??'').toString());
    final subtitle=TextEditingController(text:(existing?['subtitle']??'').toString());
    final badgeText=TextEditingController(text:(existing?['badgeText']??'').toString());
    final ctaText=TextEditingController(text:(existing?['ctaText']??'Fırsatı Gör').toString());
    final target=TextEditingController(text:(existing?['actionTarget']??'').toString());
    final city=TextEditingController(text:(existing?['targetCity']??'').toString());
    final district=TextEditingController(text:(existing?['targetDistrict']??'').toString());
    var thumb=(existing?['thumbnailUrl']??'').toString(),content=(existing?['contentImageUrl']??'').toString();
    var categoryId=(existing?['categoryId']??(categories.isEmpty?'':categories.first['id']??'')).toString();
    var badgeType=(existing?['badgeType']??'none').toString();
    var ctaEnabled=existing?['ctaEnabled']==true:false;
    var actionType=(existing?['actionType']??'NONE').toString();
    var audience=(existing?['audienceType']??'all').toString();
    var status=(existing?['status']??'draft').toString();
    var starts=DateTime.tryParse((existing?['startsAt']??'').toString())?.toLocal()??DateTime.now();
    DateTime? ends=DateTime.tryParse((existing?['endsAt']??'').toString())?.toLocal();
    bool busy=false;String? formError;
    final picker=ImagePicker();

    await showDialog(context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,setD){
      Future<void> chooseImage(String kind)async{
        final x=await picker.pickImage(source:ImageSource.gallery,imageQuality:kind=='thumbnail'?76:84,maxWidth:kind=='thumbnail'?700:1800);
        if(x==null)return;
        setD(()=>busy=true);
        try{
          final url=await upload(x,kind);
          setD((){if(kind=='thumbnail')thumb=url;else content=url;});
        }catch(e){setD(()=>formError=e.toString().replaceFirst('Exception: ',''));}
        finally{setD(()=>busy=false);}
      }
      Widget imageBox(String label,String url,String kind,double ratio)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:12)),
        const SizedBox(height:6),
        AspectRatio(
          aspectRatio:ratio,
          child:Container(
            clipBehavior:Clip.antiAlias,
            decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(14),border:Border.all(color:AdminUi.line)),
            child:url.isEmpty
              ?Center(child:Icon(kind=='thumbnail'?Icons.circle_outlined:Icons.image_outlined,color:AdminUi.muted,size:35))
              :Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined))),
          ),
        ),
        const SizedBox(height:6),
        SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:busy?null:()=>chooseImage(kind),icon:const Icon(Icons.upload_rounded),label:Text(url.isEmpty?'Görsel Yükle':'Değiştir'))),
        Text(kind=='thumbnail'?'Önerilen: 700×700 • JPG/PNG/WEBP • max 3 MB':'Önerilen: 1080×1920 • dikey • JPG/PNG/WEBP • max 3 MB',style:const TextStyle(color:AdminUi.muted,fontSize:9)),
      ]);

      Widget field(TextEditingController c,String label,{int lines=1})=>TextField(controller:c,maxLines:lines,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()));
      final wide=MediaQuery.sizeOf(dialog).width>950;
      Widget form=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        field(title,'Story başlığı'),
        const SizedBox(height:10),field(subtitle,'Alt açıklama',lines:2),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:DropdownButtonFormField<String>(value:categoryId.isEmpty?null:categoryId,decoration:const InputDecoration(labelText:'Kategori',border:OutlineInputBorder()),items:categories.where((x)=>x['isActive']!=false).map((x)=>DropdownMenuItem(value:'${x['id']}',child:Text('${x['name']}'))).toList(),onChanged:(v)=>setD(()=>categoryId=v??''))),
          const SizedBox(width:8),
          Expanded(child:DropdownButtonFormField<String>(value:badgeType,decoration:const InputDecoration(labelText:'Badge',border:OutlineInputBorder()),items:const [
            DropdownMenuItem(value:'none',child:Text('Yok')),DropdownMenuItem(value:'new',child:Text('Yeni')),DropdownMenuItem(value:'discount',child:Text('% İndirim')),DropdownMenuItem(value:'count',child:Text('Fırsat Sayısı')),DropdownMenuItem(value:'custom',child:Text('Özel Metin')),DropdownMenuItem(value:'pro',child:Text('PRO')),
          ],onChanged:(v)=>setD(()=>badgeType=v??'none'))),
        ]),
        if(badgeType!='none')...[const SizedBox(height:10),field(badgeText,'Badge metni (örn. %20 / Yeni / 3 Fırsat)')],
        const SizedBox(height:12),
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(child:imageBox('Küçük Story Görseli',thumb,'thumbnail',1)),
          const SizedBox(width:10),
          Expanded(child:imageBox('Tam Ekran Story Görseli',content,'content',9/16)),
        ]),
        const SizedBox(height:10),
        SwitchListTile(contentPadding:EdgeInsets.zero,value:ctaEnabled,onChanged:(v)=>setD(()=>ctaEnabled=v),title:const Text('CTA butonu',style:TextStyle(fontWeight:FontWeight.w900))),
        if(ctaEnabled)...[
          field(ctaText,'CTA metni'),const SizedBox(height:10),
          DropdownButtonFormField<String>(value:actionType,decoration:const InputDecoration(labelText:'CTA action',border:OutlineInputBorder()),items:const [
            DropdownMenuItem(value:'NONE',child:Text('NONE')),DropdownMenuItem(value:'IN_APP_PAGE',child:Text('IN_APP_PAGE')),DropdownMenuItem(value:'SERVICE',child:Text('SERVICE')),DropdownMenuItem(value:'OPPORTUNITY',child:Text('OPPORTUNITY')),DropdownMenuItem(value:'EXTERNAL_URL',child:Text('EXTERNAL_URL')),
          ],onChanged:(v)=>setD((){actionType=v??'NONE';target.clear();})),
          const SizedBox(height:10),
          if(actionType=='IN_APP_PAGE'||actionType=='SERVICE')
            DropdownButtonFormField<String>(value:target.text.isEmpty?null:target.text,decoration:const InputDecoration(labelText:'CTA hedefi',border:OutlineInputBorder()),items:actionTargets(actionType),onChanged:(v)=>setD(()=>target.text=v??''))
          else if(actionType=='OPPORTUNITY')field(target,'Fırsat ID')
          else if(actionType=='EXTERNAL_URL')field(target,'HTTPS URL'),
        ],
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:audience,decoration:const InputDecoration(labelText:'Hedef kitle',border:OutlineInputBorder()),items:const [
          DropdownMenuItem(value:'all',child:Text('Tüm kullanıcılar')),DropdownMenuItem(value:'pro',child:Text('PRO kullanıcılar')),DropdownMenuItem(value:'non_pro',child:Text('PRO olmayanlar')),DropdownMenuItem(value:'qr_active',child:Text('Etiketi aktif olanlar')),DropdownMenuItem(value:'qr_inactive',child:Text('Etiketi aktif olmayanlar')),
        ],onChanged:(v)=>setD(()=>audience=v??'all')),
        const SizedBox(height:10),
        Row(children:[Expanded(child:field(city,'Şehir (opsiyonel)')),const SizedBox(width:8),Expanded(child:field(district,'İlçe (opsiyonel)'))]),
        const SizedBox(height:5),
        const Text('Konum hedefi doluysa, konum izni olmayan kullanıcılara bu story gösterilmez.',style:TextStyle(color:AdminUi.muted,fontSize:9.5)),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:InkWell(onTap:()async{final x=await pickDateTime(dialog,starts);if(x!=null)setD(()=>starts=x);},child:InputDecorator(decoration:const InputDecoration(labelText:'Başlangıç',border:OutlineInputBorder()),child:Text(dateText(starts.toIso8601String()))))),
          const SizedBox(width:8),
          Expanded(child:InkWell(onTap:()async{final base=ends??starts.add(const Duration(days:7));final x=await pickDateTime(dialog,base);if(x!=null)setD(()=>ends=x);},child:InputDecorator(decoration:const InputDecoration(labelText:'Bitiş',border:OutlineInputBorder()),child:Text(ends==null?'Süresiz':dateText(ends!.toIso8601String()))))),
        ]),
        if(ends!=null)Align(alignment:Alignment.centerRight,child:TextButton(onPressed:()=>setD(()=>ends=null),child:const Text('Bitişi kaldır'))),
        DropdownButtonFormField<String>(value:status,decoration:const InputDecoration(labelText:'Durum',border:OutlineInputBorder()),items:const [
          DropdownMenuItem(value:'draft',child:Text('Taslak')),DropdownMenuItem(value:'scheduled',child:Text('Planlandı')),DropdownMenuItem(value:'published',child:Text('Yayında')),DropdownMenuItem(value:'inactive',child:Text('Pasif')),
        ],onChanged:(v)=>setD(()=>status=v??'draft')),
        if(formError!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(formError!,style:const TextStyle(color:Colors.redAccent,fontWeight:FontWeight.w800))),
      ]);

      Widget preview=Container(
        width:wide?300:null,
        padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(18),border:Border.all(color:AdminUi.line)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('ANA SAYFA ÖNİZLEMESİ',style:TextStyle(color:AdminUi.muted,fontSize:9,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          Center(child:StoryBubblePreview(title:title.text.isEmpty?'Story':title.text,subtitle:subtitle.text,imageUrl:thumb,badge:badgeText.text)),
          const SizedBox(height:18),
          const Text('STORY ÖNİZLEMESİ',style:TextStyle(color:AdminUi.muted,fontSize:9,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          StoryPhonePreview(title:title.text.isEmpty?'Story Başlığı':title.text,subtitle:subtitle.text,imageUrl:content,cta:ctaEnabled?ctaText.text:''),
        ]),
      );

      return AlertDialog(
        title:Text(editing?'Story Düzenle':'Yeni Story',style:const TextStyle(fontWeight:FontWeight.w900)),
        content:SizedBox(
          width:wide?950:560,
          child:SingleChildScrollView(
            child:wide?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:form),const SizedBox(width:16),preview]):Column(children:[form,const SizedBox(height:16),preview]),
          ),
        ),
        actions:[
          TextButton(onPressed:busy?null:()=>Navigator.pop(dialog),child:const Text('Vazgeç')),
          FilledButton.icon(
            onPressed:busy?null:()async{
              setD((){busy=true;formError=null;});
              try{
                final payload=<String,dynamic>{
                  'title':title.text.trim(),'subtitle':subtitle.text.trim(),'thumbnailUrl':thumb,'contentImageUrl':content,
                  'badgeType':badgeType,'badgeText':badgeText.text.trim(),'ctaEnabled':ctaEnabled,'ctaText':ctaText.text.trim(),
                  'actionType':ctaEnabled?actionType:'NONE','actionTarget':ctaEnabled?target.text.trim():'',
                  'categoryId':categoryId.isEmpty?null:categoryId,'audienceType':audience,'targetCountry':'TR',
                  'targetCity':city.text.trim(),'targetDistrict':district.text.trim(),'startsAt':starts.toUtc().toIso8601String(),
                  'endsAt':ends?.toUtc().toIso8601String(),'status':status,
                  'sortOrder':existing?['sortOrder']??((stories.length+1)*10):(stories.length+1)*10,
                };
                if(editing)await request('PATCH','/api/admin/manage/stories/${existing['id']}',payload);
                else await request('POST','/api/admin/manage/stories',payload);
                if(dialog.mounted)Navigator.pop(dialog);
                await load();
              }catch(e){if(dialog.mounted)setD(()=>formError=e.toString().replaceFirst('Exception: ',''));}
              finally{if(dialog.mounted)setD(()=>busy=false);}
            },
            style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),
            icon:busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded),
            label:Text(editing?'Kaydet':'Story Oluştur'),
          ),
        ],
      );
    }));
  }

  Future<void> toggle(Map<String,dynamic> s)async{
    final live=(s['displayStatus']??'').toString()=='live'||(s['status']??'').toString()=='published';
    await request('PATCH','/api/admin/manage/stories/${s['id']}',{'status':live?'inactive':'published'});
    await load();
  }

  Future<void> remove(Map<String,dynamic> s)async{
    final ok=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('Story silinsin mi?'),content:Text('“${s['title']}” kalıcı olarak silinecek.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(d,true),style:FilledButton.styleFrom(backgroundColor:Colors.redAccent),child:const Text('Sil'))]));
    if(ok!=true)return;
    await request('DELETE','/api/admin/manage/stories/${s['id']}');
    await load();
  }

  Future<void> preview(Map<String,dynamic> s)async{
    await showDialog(context:context,builder:(d)=>Dialog(
      backgroundColor:Colors.black,
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:390,maxHeight:720),child:StoryPhonePreview(title:'${s['title']}',subtitle:'${s['subtitle']??''}',imageUrl:'${s['contentImageUrl']??''}',cta:s['ctaEnabled']==true?'${s['ctaText']??''}':'')),
    ));
  }

  Future<void> reorder(int oldIndex,int newIndex)async{
    if(reordering)return;
    if(newIndex>oldIndex)newIndex-=1;
    final next=List<Map<String,dynamic>>.from(stories);
    final item=next.removeAt(oldIndex);next.insert(newIndex,item);
    setState(()=>stories=next);
    reordering=true;
    try{
      await request('POST','/api/admin/manage/stories/reorder',{'ids':next.map((e)=>e['id'].toString()).toList()});
      await load();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));await load();}
    finally{reordering=false;}
  }

  Future<void> categoryManager()async{
    await showDialog(context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,setD){
      Future<void> refresh()async{await load();if(dialog.mounted)setD((){});}
      return AlertDialog(
        title:const Text('Story Kategorileri',style:TextStyle(fontWeight:FontWeight.w900)),
        content:SizedBox(width:560,child:SingleChildScrollView(child:Column(children:[
          for(final c in categories)Container(
            margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(color:AdminUi.surfaceSoft,borderRadius:BorderRadius.circular(12)),
            child:Row(children:[
              Icon(_categoryIcon('${c['icon']}'),color:AdminUi.purple),
              const SizedBox(width:9),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${c['name']}',style:const TextStyle(fontWeight:FontWeight.w900)),Text('${c['slug']} • sıra ${c['sortOrder']}',style:const TextStyle(color:AdminUi.muted,fontSize:10))])),
              Switch(value:c['isActive']==true,onChanged:(v)async{await request('PATCH','/api/admin/manage/story-categories/${c['id']}',{'isActive':v});await refresh();}),
              IconButton(onPressed:()async{
                final name=TextEditingController(text:'${c['name']}'),icon=TextEditingController(text:'${c['icon']}'),order=TextEditingController(text:'${c['sortOrder']}');
                final ok=await showDialog<bool>(context:dialog,builder:(x)=>AlertDialog(title:const Text('Kategori Düzenle'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'İsim')),TextField(controller:icon,decoration:const InputDecoration(labelText:'Icon anahtarı')),TextField(controller:order,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Sıralama'))]),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(x,true),child:const Text('Kaydet'))]));
                if(ok==true){await request('PATCH','/api/admin/manage/story-categories/${c['id']}',{'name':name.text,'icon':icon.text,'sortOrder':int.tryParse(order.text)??0});await refresh();}
              },icon:const Icon(Icons.edit_outlined)),
            ]),
          ),
        ]))),
        actions:[
          TextButton.icon(onPressed:()async{
            final name=TextEditingController(),slug=TextEditingController(),icon=TextEditingController(text:'campaign'),order=TextEditingController(text:'90');
            final ok=await showDialog<bool>(context:dialog,builder:(x)=>AlertDialog(title:const Text('Yeni Kategori'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'İsim')),TextField(controller:slug,decoration:const InputDecoration(labelText:'Slug (örn. lastik)')),TextField(controller:icon,decoration:const InputDecoration(labelText:'Icon anahtarı')),TextField(controller:order,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Sıralama'))]),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(x,true),child:const Text('Ekle'))]));
            if(ok==true){await request('POST','/api/admin/manage/story-categories',{'name':name.text,'slug':slug.text,'icon':icon.text,'sortOrder':int.tryParse(order.text)??90,'isActive':true});await refresh();}
          },icon:const Icon(Icons.add_rounded),label:const Text('Kategori Ekle')),
          FilledButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Kapat')),
        ],
      );
    }));
  }

  IconData _categoryIcon(String x)=>switch(x){
    'towing'=>Icons.fire_truck_rounded,'valet'=>Icons.local_parking_rounded,'fuel'=>Icons.local_gas_station_rounded,
    'car_wash'=>Icons.local_car_wash_rounded,'service'=>Icons.build_rounded,'parking'=>Icons.local_parking_rounded,
    'gift'=>Icons.card_giftcard_rounded,_=>Icons.campaign_rounded,
  };

  Widget metric(String value,String label,IconData icon,Color color)=>Container(
    padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:color.withValues(alpha:.07),borderRadius:BorderRadius.circular(14)),
    child:Row(children:[Icon(icon,color:color,size:22),const SizedBox(width:8),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:TextStyle(color:AdminUi.ink,fontSize:17,fontWeight:FontWeight.w900)),Text(label,style:const TextStyle(color:AdminUi.muted,fontSize:9))])]),
  );

  Widget storyRow(Map<String,dynamic> s,int index){
    final a=s['analytics'] is Map?Map<String,dynamic>.from(s['analytics'] as Map):<String,dynamic>{};
    final sc=statusColor(s);
    return Container(
      key:ValueKey(s['id']),
      margin:const EdgeInsets.fromLTRB(14,0,14,10),
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(color:AdminUi.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:AdminUi.line)),
      child:Row(children:[
        ReorderableDragStartListener(index:index,child:const Padding(padding:EdgeInsets.all(6),child:Icon(Icons.drag_indicator_rounded,color:AdminUi.muted))),
        ClipOval(child:SizedBox(width:54,height:54,child:Image.network('${s['thumbnailUrl']??''}',fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:AdminUi.surfaceSoft,child:const Icon(Icons.image_outlined))))),
        const SizedBox(width:10),
        Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('${s['title']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:13))),Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:sc.withValues(alpha:.10),borderRadius:BorderRadius.circular(10)),child:Text(statusLabel(s),style:TextStyle(color:sc,fontSize:8.5,fontWeight:FontWeight.w900)))]),
          const SizedBox(height:3),Text('${s['categoryName']??'-'} • ${s['badgeText']??''}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:AdminUi.muted,fontSize:10)),
          const SizedBox(height:3),Text('${dateText(s['startsAt'])} → ${s['endsAt']==null?'-':dateText(s['endsAt'])}',style:const TextStyle(color:AdminUi.muted,fontSize:9)),
        ])),
        const SizedBox(width:10),
        Expanded(flex:3,child:Wrap(spacing:6,runSpacing:6,children:[
          metric('${a['impressions']??0}','Gösterim',Icons.visibility_outlined,AdminUi.blue),
          metric('${a['uniqueViews']??0}','Görüntüleme',Icons.person_outline_rounded,AdminUi.purple),
          metric('${a['clicks']??0}','CTA',Icons.touch_app_outlined,AdminUi.green),
          metric('%${a['ctr']??0}','CTR',Icons.insights_rounded,AdminUi.amber),
        ])),
        const SizedBox(width:8),
        PopupMenuButton<String>(
          onSelected:(v)async{
            try{
              if(v=='edit')await edit(s);else if(v=='toggle')await toggle(s);else if(v=='delete')await remove(s);else if(v=='preview')await preview(s);
            }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
          },
          itemBuilder:(_)=>[
            const PopupMenuItem(value:'preview',child:Text('Önizle')),
            const PopupMenuItem(value:'edit',child:Text('Düzenle')),
            PopupMenuItem(value:'toggle',child:Text((s['displayStatus']??'')=='live'?'Pasife Al':'Yayına Al')),
            const PopupMenuItem(value:'delete',child:Text('Sil',style:TextStyle(color:Colors.redAccent))),
          ],
        ),
      ]),
    );
  }

  @override Widget build(BuildContext context){
    if(loading&&stories.isEmpty)return const Center(child:CircularProgressIndicator(color:AdminUi.purple));
    if(error!=null&&stories.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,style:const TextStyle(color:AdminUi.muted)),const SizedBox(height:10),FilledButton.icon(onPressed:load,icon:const Icon(Icons.refresh_rounded),label:const Text('Tekrar Dene'))]));
    return Column(children:[
      Padding(
        padding:const EdgeInsets.fromLTRB(16,15,16,12),
        child:Row(children:[
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Story Yönetimi',style:TextStyle(color:AdminUi.ink,fontSize:21,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('Ana sayfadaki Öne Çıkanlar alanını yönetin.',style:TextStyle(color:AdminUi.muted,fontSize:11))])),
          OutlinedButton.icon(onPressed:categoryManager,icon:const Icon(Icons.category_outlined),label:const Text('Kategoriler')),
          const SizedBox(width:8),
          FilledButton.icon(onPressed:()=>edit(),style:FilledButton.styleFrom(backgroundColor:AdminUi.purple),icon:const Icon(Icons.add_rounded),label:const Text('Yeni Story')),
        ]),
      ),
      if(stories.isEmpty)Expanded(child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.auto_stories_outlined,color:AdminUi.muted,size:42),const SizedBox(height:8),const Text('Henüz story oluşturulmadı.',style:TextStyle(color:AdminUi.muted)),const SizedBox(height:10),FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('İlk Story’yi Oluştur'))])))
      else Expanded(child:ReorderableListView.builder(
        buildDefaultDragHandles:false,
        padding:const EdgeInsets.only(bottom:24),
        itemCount:stories.length,
        onReorder:reorder,
        itemBuilder:(_,i)=>storyRow(stories[i],i),
      )),
    ]);
  }
}

class StoryBubblePreview extends StatelessWidget{
  const StoryBubblePreview({super.key,required this.title,required this.subtitle,required this.imageUrl,required this.badge});
  final String title,subtitle,imageUrl,badge;
  @override Widget build(BuildContext context)=>SizedBox(width:105,child:Column(children:[
    Stack(clipBehavior:Clip.none,children:[
      Container(width:82,height:82,padding:const EdgeInsets.all(3),decoration:const BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[AdminUi.purple,Color(0xFF8A59FF),Color(0xFFC8FC06)])),child:ClipOval(child:imageUrl.isEmpty?Container(color:AdminUi.surfaceSoft,child:const Icon(Icons.image_outlined)):Image.network(imageUrl,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)))),
      if(badge.isNotEmpty)Positioned(right:-9,top:1,child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:const Color(0xFFFF465D),borderRadius:BorderRadius.circular(12)),child:Text(badge,style:const TextStyle(color:Colors.white,fontSize:8,fontWeight:FontWeight.w900)))),
    ]),
    const SizedBox(height:6),Text(title,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:10)),
    if(subtitle.isNotEmpty)Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(color:AdminUi.muted,fontSize:8)),
  ]));
}

class StoryPhonePreview extends StatelessWidget{
  const StoryPhonePreview({super.key,required this.title,required this.subtitle,required this.imageUrl,required this.cta});
  final String title,subtitle,imageUrl,cta;
  @override Widget build(BuildContext context)=>AspectRatio(
    aspectRatio:9/16,
    child:ClipRRect(borderRadius:BorderRadius.circular(24),child:Stack(children:[
      Positioned.fill(child:imageUrl.isEmpty?Container(color:const Color(0xFF241645)):Image.network(imageUrl,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:const Color(0xFF241645)))),
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.black.withValues(alpha:.32),Colors.transparent,Colors.black.withValues(alpha:.72)])))),
      Positioned(left:12,right:12,top:12,child:Row(children:List.generate(3,(i)=>Expanded(child:Container(height:2,margin:EdgeInsets.only(right:i==2?0:3),color:i==0?Colors.white:Colors.white.withValues(alpha:.35)))))),
      Positioned(left:16,right:16,bottom:18,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),
        if(subtitle.isNotEmpty)...[const SizedBox(height:5),Text(subtitle,style:TextStyle(color:Colors.white.withValues(alpha:.85),fontSize:10,height:1.3))],
        if(cta.isNotEmpty)...[const SizedBox(height:12),Container(height:38,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFFC8FC06),borderRadius:BorderRadius.circular(12)),child:Text(cta.toUpperCase(),style:const TextStyle(color:Colors.black,fontSize:10,fontWeight:FontWeight.w900)))],
      ])),
    ])),
  );
}
