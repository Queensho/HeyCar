import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _base='https://heycar-api-185-165-46-213.nip.io';
const _bg=Color(0xFF060A18),_card=Color(0xFF0C1226),_card2=Color(0xFF111A31),_line=Color(0xFF242D49),_muted=Color(0xFF8993AD),_purple=Color(0xFFA72BFF),_green=Color(0xFF28F39A),_blue=Color(0xFF499DFF),_amber=Color(0xFFFFBF55);

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
String _statusLabel(String s)=>switch(s){'open'=>'Açık','in_review'=>'İncelemede','answered'=>'Yanıtlandı','resolved'=>'Çözüldü',_=>s};
Color _statusColor(String s)=>switch(s){'open'=>Colors.redAccent,'in_review'=>_amber,'answered'=>_blue,'resolved'=>_green,_=>_muted};
String _date(dynamic raw){final d=DateTime.tryParse('${raw??''}')?.toLocal();if(d==null)return '-';String p(int n)=>n.toString().padLeft(2,'0');return '${p(d.day)}.${p(d.month)}.${d.year} ${p(d.hour)}:${p(d.minute)}';}
Map<String,dynamic> _map(dynamic x)=>x is Map?Map<String,dynamic>.from(x):<String,dynamic>{};
List<Map<String,dynamic>> _list(dynamic x)=>x is List?x.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];

class AdminSupportPage extends StatefulWidget{
  const AdminSupportPage({super.key,required this.token,required this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminSupportPage> createState()=>_AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage>{
  bool loading=true;
  String? error;
  String status='open';
  Map<String,dynamic> data={};

  Map<String,String> get headers=>{
    'Authorization':'Bearer ${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
    if((widget.admin?['display_name']??widget.admin?['name']??'').toString().isNotEmpty)'X-Admin-Name':(widget.admin?['display_name']??widget.admin?['name']).toString(),
  };

  @override void initState(){super.initState();load();}

  Future<void> load([String? next])async{
    final f=next??status;
    if(mounted)setState((){status=f;loading=true;error=null;});
    try{
      final r=await http.get(Uri.parse('$_base/api/admin/manage/support-tickets?status=$f'),headers:headers);
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map?d['error']??'SERVER_ERROR':'SERVER_ERROR');
      if(mounted)setState(()=>data=Map<String,dynamic>.from(d as Map));
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> update(String id,String nextStatus,String reply)async{
    final r=await http.patch(Uri.parse('$_base/api/admin/manage/support-tickets/$id'),headers:headers,body:jsonEncode({'status':nextStatus,'adminReply':reply}));
    final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
    if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map?d['error']??'SERVER_ERROR':'SERVER_ERROR');
    await load();
  }

  @override Widget build(BuildContext context){
    final s=_map(data['summary']),items=_list(data['items']);
    if(loading&&data.isEmpty)return const Center(child:CircularProgressIndicator(color:_purple));
    return RefreshIndicator(color:_purple,onRefresh:()=>load(),child:LayoutBuilder(builder:(context,c){
      final compact=c.maxWidth<760,pad=compact?12.0:18.0,width=c.maxWidth-pad*2,cols=compact?2:5,gap=9.0,mw=(width-gap*(cols-1))/cols;
      return ListView(physics:const AlwaysScrollableScrollPhysics(),padding:EdgeInsets.fromLTRB(pad,14,pad,28),children:[
        Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF111A32),Color(0xFF1A092A)]),borderRadius:BorderRadius.circular(22),border:Border.all(color:_purple.withValues(alpha:.35))),
          child:const Row(children:[
            CircleAvatar(radius:24,backgroundColor:Color(0x222F8BFF),child:Icon(Icons.support_agent_rounded,color:_purple,size:26)),
            SizedBox(width:11),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Destek Talepleri',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
              SizedBox(height:2),
              Text('Kullanıcı sorunlarını incele, yanıtla ve çöz.',style:TextStyle(color:_muted,fontSize:11.5)),
            ])),
          ]),
        ),
        const SizedBox(height:12),
        Wrap(spacing:gap,runSpacing:gap,children:[
          SizedBox(width:mw,child:_metric('${s['total']??0}','Toplam',Icons.support_agent_rounded,_purple)),
          SizedBox(width:mw,child:_metric('${s['open']??0}','Açık',Icons.mark_email_unread_rounded,Colors.redAccent)),
          SizedBox(width:mw,child:_metric('${s['in_review']??0}','İncelemede',Icons.manage_search_rounded,_amber)),
          SizedBox(width:mw,child:_metric('${s['answered']??0}','Yanıtlandı',Icons.mark_email_read_rounded,_blue)),
          SizedBox(width:mw,child:_metric('${s['resolved']??0}','Çözüldü',Icons.task_alt_rounded,_green)),
        ]),
        const SizedBox(height:11),
        Wrap(spacing:7,runSpacing:7,children:[
          for(final x in const [('open','Açık'),('in_review','İncelemede'),('answered','Yanıtlandı'),('resolved','Çözüldü'),('all','Tümü')])
            ChoiceChip(label:Text(x.$2),selected:status==x.$1,onSelected:(_)=>load(x.$1)),
        ]),
        const SizedBox(height:10),
        if(error!=null)Padding(padding:const EdgeInsets.only(bottom:8),child:Text(error!,style:const TextStyle(color:Colors.redAccent))),
        if(items.isEmpty)_empty('Bu filtrede destek talebi yok.')
        else ...items.map((x)=>_ticket(context,x)),
      ]);
    }));
  }

  Widget _ticket(BuildContext context,Map<String,dynamic> x){
    final st=(x['status']??'open').toString(),color=_statusColor(st);
    return InkWell(
      borderRadius:BorderRadius.circular(18),
      onTap:()=>_open(context,x),
      child:Container(
        margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:color.withValues(alpha:.28))),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.12),shape:BoxShape.circle),child:Icon(Icons.support_agent_rounded,color:color,size:21)),
          const SizedBox(width:10),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Expanded(child:Text('#${x['id']} • ${_categories[(x['category']??'').toString()]??x['category']??'Destek'}',style:const TextStyle(color:Colors.white,fontSize:13.5,fontWeight:FontWeight.w900))),
              _pill(_statusLabel(st),color),
            ]),
            const SizedBox(height:4),
            Text('${x['display_name']??'İsimsiz'} • ${x['phone']??x['email']??'-'}',style:const TextStyle(color:_blue,fontSize:10.5,fontWeight:FontWeight.w700)),
            const SizedBox(height:4),
            Text((x['message']??'').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,fontSize:11.5,height:1.3)),
            const SizedBox(height:5),
            Text('${_date(x['created_at'])}${(x['attachment_count']??0)!=0?' • Ekran görüntüsü var':''}',style:const TextStyle(color:_muted,fontSize:9.5)),
          ])),
          const SizedBox(width:5),
          const Icon(Icons.chevron_right_rounded,color:_purple),
        ]),
      ),
    );
  }

  Future<void> _open(BuildContext context,Map<String,dynamic> x)async{
    Uint8List? attachmentBytes;
    if((x['attachment_count']??0)!=0){
      try{
        final ar=await http.get(
          Uri.parse('$_base/api/admin/manage/support-tickets/${x['id']}/attachment'),
          headers:headers,
        ).timeout(const Duration(seconds:15));
        if(ar.statusCode>=200&&ar.statusCode<300)attachmentBytes=ar.bodyBytes;
      }catch(_){}
    }
    final reply=TextEditingController(text:(x['admin_reply']??'').toString());
    String next=(x['status']??'open').toString();
    final id=x['id'].toString();
    bool busy=false;
    await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
      title:Text('Destek #$id'),
      content:SizedBox(width:620,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        Text('${x['display_name']??'İsimsiz'} • ${x['phone']??x['email']??'-'}',style:const TextStyle(color:_blue,fontWeight:FontWeight.w800)),
        const SizedBox(height:5),
        Text(_categories[(x['category']??'').toString()]??(x['category']??'-').toString(),style:const TextStyle(color:_muted,fontSize:11)),
        const SizedBox(height:10),
        Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_card2,borderRadius:BorderRadius.circular(14)),child:SelectableText((x['message']??'').toString(),style:const TextStyle(color:Colors.white,height:1.4))),
        if((x['attachment_count']??0)!=0)...[
          const SizedBox(height:12),
          if(attachmentBytes!=null)
            ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.memory(attachmentBytes,height:260,width:double.infinity,fit:BoxFit.contain))
          else
            Container(height:100,alignment:Alignment.center,color:_card2,child:const Text('Ekran görüntüsü yüklenemedi.',style:TextStyle(color:_muted))),
        ],
        const SizedBox(height:12),
        DropdownButtonFormField<String>(
          value:next,
          decoration:const InputDecoration(labelText:'Durum'),
          items:const [
            DropdownMenuItem(value:'open',child:Text('Açık')),
            DropdownMenuItem(value:'in_review',child:Text('İncelemede')),
            DropdownMenuItem(value:'answered',child:Text('Yanıtlandı')),
            DropdownMenuItem(value:'resolved',child:Text('Çözüldü')),
          ],
          onChanged:busy?null:(v)=>setD(()=>next=v??next),
        ),
        const SizedBox(height:10),
        TextField(controller:reply,maxLines:5,maxLength:3000,decoration:const InputDecoration(labelText:'Admin cevabı',alignLabelWithHint:true,prefixIcon:Icon(Icons.reply_rounded))),
        const Text('Yanıtlandı durumunda cevap zorunludur. Cevap kullanıcı uygulamasında görünür ve push bildirimi gönderilir.',style:TextStyle(color:_muted,fontSize:10.5)),
      ]))),
      actions:[
        TextButton(onPressed:busy?null:()=>Navigator.pop(d),child:const Text('Kapat')),
        FilledButton.icon(
          onPressed:busy?null:()async{
            setD(()=>busy=true);
            try{
              await update(id,next,reply.text.trim());
              if(d.mounted)Navigator.pop(d);
            }catch(e){
              setD(()=>busy=false);
              if(d.mounted)ScaffoldMessenger.of(d).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
            }
          },
          icon:busy?const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded),
          label:const Text('Kaydet'),
        ),
      ],
    )));
    reply.dispose();
  }

  Widget _metric(String value,String label,IconData icon,Color color)=>Container(height:88,padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(17),border:Border.all(color:color.withValues(alpha:.25))),child:Row(children:[Icon(icon,color:color,size:24),const SizedBox(width:8),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900)),Text(label,maxLines:2,style:const TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700))]))]));
  Widget _pill(String text,Color color)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:color.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),child:Text(text,style:TextStyle(color:color,fontSize:9.5,fontWeight:FontWeight.w900)));
  Widget _empty(String text)=>Container(width:double.infinity,padding:const EdgeInsets.symmetric(vertical:40,horizontal:16),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Column(children:[const Icon(Icons.support_agent_outlined,color:_muted,size:38),const SizedBox(height:8),Text(text,style:const TextStyle(color:_muted,fontWeight:FontWeight.w700))]));
}
