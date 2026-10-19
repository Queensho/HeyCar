import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminOfferEditorialPage extends StatefulWidget{
 const AdminOfferEditorialPage({super.key,required this.token});
 final String token;
 @override State<AdminOfferEditorialPage> createState()=>_AdminOfferEditorialPageState();
}
class _AdminOfferEditorialPageState extends State<AdminOfferEditorialPage>{
 static const base='https://heycar-api-185-165-46-213.nip.io';
 List<Map<String,dynamic>> offers=[];
 bool loading=false;String? error;
 Map<String,String> get headers=>{'Authorization':'Bearer ${widget.token}','Content-Type':'application/json'};
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  setState((){loading=true;error=null;});
  try{final r=await http.get(Uri.parse('$base/api/admin/manage/offer-editorial'),headers:headers);
   if(r.statusCode!=200)throw Exception('Liste alınamadı (${r.statusCode})');
   final d=jsonDecode(r.body) as Map;
   if(mounted)setState(()=>offers=(d['offers'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
  }catch(e){if(mounted)setState(()=>error=e.toString());}
  finally{if(mounted)setState(()=>loading=false);}
 }
 Future<void> save(Map<String,dynamic> item,{bool create=false})async{
  final uri=Uri.parse('$base/api/admin/manage/offer-editorial${create?'':'/${item['id']}'}');
  final body=jsonEncode({for(final k in ['placement','title','description','badge','image_url','target_url','is_active','sort_order'])k:item[k]});
  final r=create?await http.post(uri,headers:headers,body:body):await http.patch(uri,headers:headers,body:body);
  if(r.statusCode<200||r.statusCode>=300)throw Exception('Kaydedilemedi (${r.statusCode})');
  await load();
 }
 Future<void> edit([Map<String,dynamic>? existing])async{
  final title=TextEditingController(text='${existing?['title']??''}');
  final description=TextEditingController(text='${existing?['description']??''}');
  final badge=TextEditingController(text='${existing?['badge']??''}');
  final image=TextEditingController(text='${existing?['image_url']??''}');
  final url=TextEditingController(text='${existing?['target_url']??''}');
  var placement='${existing?['placement']??'personal'}',active=existing?['is_active']==true;
  final result=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,change)=>AlertDialog(
   title:Text(existing==null?'Yeni vitrin fırsatı':'Vitrin fırsatını düzenle'),
   content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    DropdownButtonFormField<String>(initialValue:placement,decoration:const InputDecoration(labelText:'Bölüm'),
     items:const [DropdownMenuItem(value:'personal',child:Text('Sana Özel Fırsatlar')),DropdownMenuItem(value:'featured',child:Text('Öne Çıkanlar'))],
     onChanged:(v)=>change(()=>placement=v??'personal')),
    TextField(controller:title,maxLength:120,decoration:const InputDecoration(labelText:'Başlık *')),
    TextField(controller:description,maxLength:500,decoration:const InputDecoration(labelText:'Açıklama')),
    TextField(controller:badge,maxLength:60,decoration:const InputDecoration(labelText:'İndirim etiketi')),
    TextField(controller:image,decoration:const InputDecoration(labelText:'Görsel URL (https)')),
    TextField(controller:url,decoration:const InputDecoration(labelText:'Detay bağlantısı (https)')),
    SwitchListTile(value:active,onChanged:(v)=>change(()=>active=v),title:const Text('Yayında')),
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Vazgeç')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,{
     'id':existing?['id'],'placement':placement,'title':title.text.trim(),'description':description.text.trim(),
     'badge':badge.text.trim(),'image_url':image.text.trim(),'target_url':url.text.trim(),
     'is_active':active,'sort_order':existing?['sort_order']??0,
    }),child:const Text('Kaydet'))],
  )));
  title.dispose();description.dispose();badge.dispose();image.dispose();url.dispose();
  if(result==null)return;
  if((result['title'] as String).isEmpty){message('Başlık zorunlu');return;}
  try{await save(result,create:existing==null);message('Kaydedildi');}catch(e){message(e.toString());}
 }
 void message(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
  Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('Fırsatlar Vitrin Yönetimi',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
   Text('Sana Özel ve Öne Çıkanlar admin tarafından yönetilir. Yakındaki fırsatlar işletmelerden gelir.',style:TextStyle(fontSize:12)),
  ])),FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.add),label:const Text('Yeni Fırsat'))]),
  const SizedBox(height:14),
  if(loading)const LinearProgressIndicator(),
  if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),
  for(final section in ['personal','featured'])...[
   Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(section=='personal'?'Sana Özel Fırsatlar':'Öne Çıkanlar',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))),
   if(!offers.any((x)=>x['placement']==section))const Card(child:ListTile(title:Text('Henüz kampanya eklenmedi'))),
   for(final item in offers.where((x)=>x['placement']==section))Card(child:ListTile(
    leading:Icon(item['is_active']==true?Icons.visibility:Icons.visibility_off,color:const Color(0xFF651FFF)),
    title:Text('${item['title']}'),subtitle:Text('${item['badge']??''} • ${item['is_active']==true?'Yayında':'Taslak'}'),
    trailing:IconButton(onPressed:()=>edit(item),icon:const Icon(Icons.edit_outlined)),
    onTap:()=>edit(item),
   )),
  ],
 ]);
}
