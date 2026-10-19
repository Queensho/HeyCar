import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AdminOffersPageDesign extends StatefulWidget {
 const AdminOffersPageDesign({super.key,required this.token});
 final String token;
 @override State<AdminOffersPageDesign> createState()=>_AdminOffersPageDesignState();
}
class _AdminOffersPageDesignState extends State<AdminOffersPageDesign>{
 static const api='https://heycar-api-185-165-46-213.nip.io';
 final fields=<String,TextEditingController>{};
 bool loading=true,busy=false,search=true,categories=true;
 String? error;
 Map<String,dynamic> published={};
 Map<String,String> get headers=>{'Authorization':'Bearer ${widget.token}','Content-Type':'application/json'};
 @override void initState(){super.initState();load();}
 @override void dispose(){for(final c in fields.values){c.dispose();}super.dispose();}
 String val(String key)=>fields[key]?.text??'';
 void setField(String key,String value){
  fields.putIfAbsent(key,()=>TextEditingController()).text=value;
 }
 Future<void> load()async{
  try{
   final r=await http.get(Uri.parse('$api/api/admin/manage/offers-page-design'),headers:headers);
   if(r.statusCode!=200)throw Exception('Tasarım yüklenemedi (${r.statusCode})');
   final d=jsonDecode(r.body) as Map;
   final draft=Map<String,dynamic>.from(d['draft'] as Map);
   published=Map<String,dynamic>.from(d['published'] as Map);
   for(final e in draft.entries){if(e.value is String)setField(e.key,e.value as String);}
   search=draft['show_search']!=false;categories=draft['show_categories']!=false;
  }catch(e){error=e.toString();}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> upload(String key)async{
  final file=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:1800,imageQuality:82);
  if(file==null)return;
  if(!RegExp(r'\.(jpg|jpeg|png|webp)$',caseSensitive:false).hasMatch(file.name)){
   setState(()=>error='JPG, PNG veya WEBP seç.');return;
  }
  final bytes=await file.readAsBytes();
  if(bytes.length>3*1024*1024){setState(()=>error='Fotoğraf en fazla 3 MB olabilir.');return;}
  setState(()=>busy=true);
  try{
   final mime=file.name.toLowerCase().endsWith('.png')?'image/png':file.name.toLowerCase().endsWith('.webp')?'image/webp':'image/jpeg';
   final h=Map<String,String>.from(headers)..['Content-Type']='application/octet-stream'..['X-File-Type']=mime..['X-File-Name']=file.name;
   final r=await http.put(Uri.parse('$api/api/admin/manage/stories/media/content'),headers:h,body:bytes);
   if(r.statusCode!=201)throw Exception('Yükleme başarısız (${r.statusCode})');
   final url=(jsonDecode(r.body) as Map)['url']?.toString()??'';
   if(!url.startsWith('https://'))throw Exception('Görsel adresi geçersiz');
   setState(()=>setField(key,url));
  }catch(e){setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> save({bool publish=false})async{
  setState(()=>busy=true);
  try{
   final payload={for(final e in fields.entries)e.key:e.value.text,'show_search':search,'show_categories':categories};
   final r=await http.put(Uri.parse('$api/api/admin/manage/offers-page-design/draft'),headers:headers,body:jsonEncode(payload));
   if(r.statusCode!=200)throw Exception('Taslak kaydedilemedi (${r.statusCode})');
   if(publish){
    final p=await http.post(Uri.parse('$api/api/admin/manage/offers-page-design/publish'),headers:headers);
    if(p.statusCode!=200)throw Exception('Yayınlanamadı (${p.statusCode})');
    published=Map<String,dynamic>.from((jsonDecode(p.body) as Map)['design'] as Map);
   }
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(publish?'Tasarım yayınlandı':'Taslak kaydedildi')));
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Widget field(String key,String label,{int lines=1})=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(
  controller:fields.putIfAbsent(key,()=>TextEditingController()),maxLines:lines,
  decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
 Widget photo(String key,String label)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(label,style:const TextStyle(fontWeight:FontWeight.bold)),
  const SizedBox(height:8),
  if(val(key).startsWith('https://'))ClipRRect(borderRadius:BorderRadius.circular(12),child:
   SizedBox(height:130,width:double.infinity,child:Image.network(val(key),fit:BoxFit.cover,
    errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined))))),
  OutlinedButton.icon(onPressed:busy?null:()=>upload(key),icon:const Icon(Icons.photo_library_outlined),label:Text(val(key).isEmpty?'Galeriden Görsel Seç':'Görseli Değiştir')),
  if(val(key).isNotEmpty)TextButton(onPressed:()=>setState(()=>setField(key,'')),child:const Text('Görseli Kaldır')),
  const SizedBox(height:12),
 ]);
 Widget preview()=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(
  color:const Color(0xFFF8F9FC),borderRadius:BorderRadius.circular(18)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Text('Taslak önizlemesi',style:TextStyle(fontWeight:FontWeight.bold)),
  const SizedBox(height:10),
  Container(width:double.infinity,padding:const EdgeInsets.all(18),
   decoration:BoxDecoration(color:Color(int.tryParse(val('header_color').replaceFirst('#','0xFF'))??0xFF651FFF),borderRadius:BorderRadius.circular(16)),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(val('header_title'),style:const TextStyle(fontSize:24,color:Colors.white,fontWeight:FontWeight.bold)),
    Text(val('header_subtitle'),style:const TextStyle(color:Colors.white)),
    if(search)const Padding(padding:EdgeInsets.only(top:12),child:Text('⌕ Fırsat ara...',style:TextStyle(color:Colors.white))),
    if(categories)const Padding(padding:EdgeInsets.only(top:10),child:Text('Tümü  •  Oto Yıkama  •  Lastik',style:TextStyle(color:Colors.white))),
   ])),
  const SizedBox(height:12),
  Container(height:155,width:double.infinity,clipBehavior:Clip.antiAlias,
   decoration:BoxDecoration(color:const Color(0xFF4912C8),borderRadius:BorderRadius.circular(16)),
   child:Stack(fit:StackFit.expand,children:[
    if(val('banner_image_url').startsWith('https://'))Image.network(val('banner_image_url'),fit:BoxFit.cover),
    Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(val('banner_title'),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
     Text(val('banner_highlight'),style:const TextStyle(color:Color(0xFFB9FF45),fontSize:18,fontWeight:FontWeight.bold)),
     Text(val('banner_subtitle'),style:const TextStyle(color:Colors.white)),
    ])),
   ])),
 ]));
 @override Widget build(BuildContext context)=>loading?const Center(child:CircularProgressIndicator()):
 ListView(padding:const EdgeInsets.all(16),children:[
  const Text('Fırsatlar • Sayfa Tasarımı',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
  if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Text(error!,style:const TextStyle(color:Colors.red))),
  const SizedBox(height:16),
  const Text('Header',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
  field('header_title','Sayfa başlığı'),field('header_subtitle','Açıklama',lines:2),
  field('header_color','Arka plan rengi (#651FFF)'),
  photo('header_image_url','Header arka plan görseli'),
  SwitchListTile(title:const Text('Arama alanını göster'),value:search,onChanged:(v)=>setState(()=>search=v)),
  SwitchListTile(title:const Text('Kategorileri göster'),value:categories,onChanged:(v)=>setState(()=>categories=v)),
  const Divider(height:32),
  const Text('Premium Banner',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
  photo('banner_image_url','Banner arka plan görseli'),
  field('banner_title','Banner başlığı'),field('banner_highlight','Vurgulu metin'),
  field('banner_subtitle','Banner açıklaması',lines:2),field('banner_button','Buton yazısı'),
  const SizedBox(height:12),preview(),const SizedBox(height:18),
  Wrap(spacing:10,children:[
   OutlinedButton(onPressed:busy?null:()=>save(),child:const Text('Taslak Kaydet')),
   FilledButton(onPressed:busy?null:()=>save(publish:true),child:const Text('Yayınla')),
  ]),
  const SizedBox(height:40),
 ]);
}
