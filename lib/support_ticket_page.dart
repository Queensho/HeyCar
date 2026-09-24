import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';

const _bg=Color(0xFF07111F),_panel=Color(0xFF111A31),_line=Color(0xFF29345A),_purple=Color(0xFF8B5CFF),_muted=Color(0xFFA7B0C7),_green=Color(0xFF35D07F),_amber=Color(0xFFFFB74D);
const _cardReply=Color(0xFF171B38);

const _categories=<String,String>{
  'technical':'Teknik sorun',
  'qr':'QR / Etiket',
  'vehicle':'Araç',
  'notifications_calls':'Bildirim / Arama',
  'offers':'Fırsatlar',
  'premium_payment':'Premium / Ödeme',
  'account_security':'Hesap / Güvenlik',
  'other':'Diğer',
};

String _statusLabel(String s)=>switch(s){
  'open'=>'Açık',
  'in_review'=>'İncelemede',
  'answered'=>'Yanıtlandı',
  'resolved'=>'Çözüldü',
  _=>s,
};
Color _statusColor(String s)=>switch(s){
  'open'=>const Color(0xFFFF6B7A),
  'in_review'=>_amber,
  'answered'=>const Color(0xFF4AB8FF),
  'resolved'=>_green,
  _=>_muted,
};
String _date(dynamic raw){
  final d=DateTime.tryParse('${raw??''}')?.toLocal();
  if(d==null)return '-';
  String p(int n)=>n.toString().padLeft(2,'0');
  return '${p(d.day)}.${p(d.month)}.${d.year} ${p(d.hour)}:${p(d.minute)}';
}

class SupportTicketPage extends StatefulWidget{
  const SupportTicketPage({super.key});
  @override State<SupportTicketPage> createState()=>_SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage>{
  final _message=TextEditingController();
  String _category='technical';
  XFile? _image;
  Uint8List? _imageBytes;
  bool _loading=true,_sending=false;
  String? _error;
  List<Map<String,dynamic>> _items=[];

  @override void initState(){super.initState();_load();}
  @override void dispose(){_message.dispose();super.dispose();}

  Future<void> _load()async{
    if(mounted)setState((){_loading=true;_error=null;});
    try{
      final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/support-tickets'),json:false).timeout(const Duration(seconds:15));
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode<200||r.statusCode>=300)throw Exception('Destek talepleri alınamadı.');
      final raw=d is Map?d['items']:null;
      final rows=raw is List?raw.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];
      if(mounted)setState(()=>_items=rows);
    }catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>_loading=false);}
  }

  Future<void> _pick()async{
    final x=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:82,maxWidth:1600,maxHeight:1600);
    if(x==null)return;
    final bytes=await x.readAsBytes();
    if(bytes.length>5*1024*1024){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Ekran görüntüsü en fazla 5 MB olabilir.')));
      return;
    }
    if(mounted)setState((){_image=x;_imageBytes=bytes;});
  }

  Future<void> _send()async{
    final message=_message.text.trim();
    if(message.length<10){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sorununu en az 10 karakterle açıkla.')));
      return;
    }
    setState(()=>_sending=true);
    try{
      final r=await OwnerHttp.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/support-tickets'),
        body:jsonEncode({'category':_category,'message':message}),
      ).timeout(const Duration(seconds:20));
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode<200||r.statusCode>=300){
        final code=d is Map?d['error']?.toString():'';
        if(code=='TOO_MANY_SUPPORT_TICKETS')throw Exception('Kısa sürede çok fazla talep oluşturdun. Biraz sonra tekrar dene.');
        throw Exception('Destek talebi oluşturulamadı.');
      }
      final ticket=d is Map?d['ticket']:null;
      final ticketId=ticket is Map?'${ticket['id']??''}':'';
      bool imageOk=true;
      if(ticketId.isNotEmpty&&_imageBytes!=null&&_image!=null){
        final name=_image!.name.toLowerCase();
        final mime=name.endsWith('.png')?'image/png':name.endsWith('.webp')?'image/webp':'image/jpeg';
        final up=await OwnerHttp.post(
          Uri.parse('${OnboardingBackend.baseUrl}/api/owner/support-tickets/$ticketId/attachment'),
          json:false,
          headers:{'Content-Type':mime},
          body:_imageBytes!,
        ).timeout(const Duration(seconds:30));
        imageOk=up.statusCode>=200&&up.statusCode<300;
      }
      _message.clear();
      setState((){_image=null;_imageBytes=null;_category='technical';});
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(imageOk?'Destek talebin oluşturuldu.':'Talep oluşturuldu; ekran görüntüsü yüklenemedi.')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
    }finally{if(mounted)setState(()=>_sending=false);}
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:_bg,
    appBar:AppBar(backgroundColor:_bg,title:const Text('Destek Talepleri'),foregroundColor:Colors.white),
    body:RefreshIndicator(color:_purple,onRefresh:_load,child:ListView(
      physics:const AlwaysScrollableScrollPhysics(),
      padding:const EdgeInsets.fromLTRB(14,10,14,30),
      children:[
        Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF1E1450),Color(0xFF111A31)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:_purple.withValues(alpha:.45))),
          child:const Row(children:[
            CircleAvatar(radius:25,backgroundColor:Color(0x332F8BFF),child:Icon(Icons.support_agent_rounded,color:Colors.white,size:27)),
            SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Nasıl yardımcı olabiliriz?',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),
              SizedBox(height:3),
              Text('Sorununu gönder; destek ekibi cevabı burada gösterecek.',style:TextStyle(color:Color(0xFFC8CDE0),fontSize:11.5,height:1.3)),
            ])),
          ]),
        ),
        const SizedBox(height:12),
        Container(
          padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:_line)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Yeni destek talebi',style:TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),
            const SizedBox(height:12),
            DropdownButtonFormField<String>(
              value:_category,
              dropdownColor:_panel,
              decoration:const InputDecoration(labelText:'Kategori',prefixIcon:Icon(Icons.category_outlined)),
              items:_categories.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
              onChanged:_sending?null:(v)=>setState(()=>_category=v??'technical'),
            ),
            const SizedBox(height:10),
            TextField(
              controller:_message,
              enabled:!_sending,
              maxLength:2000,
              maxLines:5,
              style:const TextStyle(color:Colors.white),
              decoration:const InputDecoration(labelText:'Sorununu anlat',alignLabelWithHint:true,prefixIcon:Icon(Icons.edit_note_rounded)),
            ),
            const SizedBox(height:4),
            if(_imageBytes!=null)...[
              ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.memory(_imageBytes!,height:150,width:double.infinity,fit:BoxFit.cover)),
              const SizedBox(height:7),
            ],
            Row(children:[
              Expanded(child:OutlinedButton.icon(
                onPressed:_sending?null:_pick,
                icon:Icon(_imageBytes==null?Icons.add_photo_alternate_outlined:Icons.change_circle_outlined),
                label:Text(_imageBytes==null?'Ekran görüntüsü ekle':'Görseli değiştir'),
              )),
              if(_imageBytes!=null)...[
                const SizedBox(width:7),
                IconButton(onPressed:_sending?null:()=>setState((){_image=null;_imageBytes=null;}),icon:const Icon(Icons.delete_outline,color:Colors.redAccent)),
              ],
            ]),
            const SizedBox(height:9),
            SizedBox(width:double.infinity,height:48,child:FilledButton.icon(
              onPressed:_sending?null:_send,
              style:FilledButton.styleFrom(backgroundColor:_purple),
              icon:_sending?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.send_rounded),
              label:Text(_sending?'Gönderiliyor...':'Talebi Gönder',style:const TextStyle(fontWeight:FontWeight.w900)),
            )),
          ]),
        ),
        const SizedBox(height:16),
        const Text('Taleplerim',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        if(_loading)const Padding(padding:EdgeInsets.all(30),child:Center(child:CircularProgressIndicator(color:_purple)))
        else if(_error!=null)Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.redAccent.withValues(alpha:.4))),child:Text(_error!,style:const TextStyle(color:Colors.redAccent)))
        else if(_items.isEmpty)Container(padding:const EdgeInsets.symmetric(vertical:34,horizontal:16),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:const Column(children:[Icon(Icons.support_agent_outlined,color:_muted,size:38),SizedBox(height:8),Text('Henüz destek talebin yok.',style:TextStyle(color:_muted,fontWeight:FontWeight.w700))]))
        else ..._items.map(_ticketCard),
      ],
    )),
  );

  Widget _ticketCard(Map<String,dynamic> x){
    final st=(x['status']??'open').toString(),color=_statusColor(st),reply=(x['admin_reply']??'').toString();
    return Container(
      margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:color.withValues(alpha:.30))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Text('#${x['id']} • ${_categories[(x['category']??'').toString()]??x['category']??'Destek'}',style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900))),
          Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(_statusLabel(st),style:TextStyle(color:color,fontSize:9.5,fontWeight:FontWeight.w900))),
        ]),
        const SizedBox(height:5),
        Text((x['message']??'').toString(),style:const TextStyle(color:Colors.white70,fontSize:11.5,height:1.35)),
        const SizedBox(height:6),
        Row(children:[
          Text(_date(x['created_at']),style:const TextStyle(color:_muted,fontSize:9.5)),
          if((x['attachment_count']??0) != 0)...[const SizedBox(width:8),const Icon(Icons.image_outlined,color:_muted,size:13),const SizedBox(width:2),const Text('Ekran görüntüsü',style:TextStyle(color:_muted,fontSize:9.5))],
        ]),
        if(reply.isNotEmpty)...[
          const SizedBox(height:10),
          Container(width:double.infinity,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:_cardReply,borderRadius:BorderRadius.circular(14),border:Border.all(color:_purple.withValues(alpha:.28))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Row(children:[Icon(Icons.support_agent_rounded,color:_purple,size:17),SizedBox(width:6),Text('Cepqar Destek',style:TextStyle(color:_purple,fontSize:10.5,fontWeight:FontWeight.w900))]),
            const SizedBox(height:5),
            Text(reply,style:const TextStyle(color:Colors.white,fontSize:11.5,height:1.35)),
            const SizedBox(height:4),
            Text(_date(x['replied_at']),style:const TextStyle(color:_muted,fontSize:9)),
          ])),
        ],
      ]),
    );
  }
}
