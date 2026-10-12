import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'onboarding_backend.dart';
import 'owner_chat_page.dart';
import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'owner_reference_design.dart';

const _purple=Color(0xFF8B5CFF);
Color get _bg=>CepqarTheme.bg;
Color get _panel=>CepqarTheme.panel;
Color get _line=>CepqarTheme.line;
Color get _muted=>CepqarTheme.muted;
Color get _text=>CepqarTheme.text;
final ValueNotifier<int> ownerUnreadNotificationCount=ValueNotifier<int>(0);
class OwnerNotificationsPage extends StatefulWidget{const OwnerNotificationsPage({super.key,this.vehicleId='',this.plate='',this.active=true,this.onSettings});final String vehicleId,plate;final bool active;final VoidCallback? onSettings;@override State<OwnerNotificationsPage> createState()=>_S();}
class _S extends State<OwnerNotificationsPage>{static const base='https://heycar-api-185-165-46-213.nip.io';List<Map<String,dynamic>> items=[];bool loading=true,markingAll=false,_refreshing=false;String? error;Timer? timer;int tab=0;@override void initState(){super.initState();if(widget.active){_load();_startPolling();}else loading=false;}void _startPolling(){timer?.cancel();if(!widget.active)return;timer=Timer.periodic(const Duration(seconds:30),(_)=>_load(silent:true));}@override void didUpdateWidget(covariant OwnerNotificationsPage oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.active!=widget.active||oldWidget.vehicleId!=widget.vehicleId){if(widget.active){_load(silent:true);_startPolling();}else timer?.cancel();}}@override void dispose(){timer?.cancel();super.dispose();}
Future<void> _load({bool silent=false})async{if(_refreshing||(!widget.active&&silent))return;final o=OnboardingDraft.userId.trim();if(o.isEmpty)return;_refreshing=true;if(!silent&&mounted)setState(()=>loading=true);try{final r=await OwnerHttp.get(Uri.parse('$base/api/owner/notifications'),json:false);final d=jsonDecode(r.body);if(r.statusCode<200||r.statusCode>=300||d is! Map||d['notifications'] is! List)throw Exception();var next=(d['notifications'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();if(widget.vehicleId.isNotEmpty)next=next.where((e)=>'${e['vehicle_id']}'==widget.vehicleId).toList();ownerUnreadNotificationCount.value=next.where((e)=>e['status']=='new').length;if(mounted)setState((){items=next;loading=false;error=null;});}catch(_){if(mounted&&!silent)setState((){loading=false;error='Bildirimler alınamadı. Tekrar dene.';});}finally{_refreshing=false;}}
Future<void> _status(Map<String,dynamic> n,String s)async{final id='${n['id']??''}';if(id.isEmpty)return;final old='${n['status']??'new'}';if(mounted)setState(()=>n['status']=s);try{final r=await OwnerHttp.patch(Uri.parse('$base/api/owner/notifications/$id'),body:jsonEncode({'status':s})).timeout(const Duration(seconds:10));if(r.statusCode<200||r.statusCode>=300)throw Exception('STATUS_${r.statusCode}_${r.body}');if(old=='new'&&s!='new')ownerUnreadNotificationCount.value=(ownerUnreadNotificationCount.value-1).clamp(0,1<<30);unawaited(_load(silent:true));}catch(e){if(mounted){setState(()=>n['status']=old);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s=='arriving'?'Geliyorum durumu gönderilemedi. Tekrar dene.':'Durum güncellenemedi. Tekrar dene.')));}}}
void _reply(Map<String,dynamic> n){if(n['status']=='new')_status(n,'read');Navigator.push(context,MaterialPageRoute(builder:(_)=>OwnerChatPage(notificationId:'${n['id']}',plate:'${n['plate']??''}')));}
String title(String t)=>{'move_vehicle':'Araç Çekme Talebi','lights_on':'Far Uyarısı','damage':'Hasar Bildirimi','call_request':'Gizli Arama Talebi'}[t]??'Mesaj';IconData icon(String t)=>{'lights_on':Icons.lightbulb_rounded,'damage':Icons.warning_amber_rounded,'call_request':Icons.phone_rounded,'move_vehicle':Icons.directions_car_filled_rounded}[t]??Icons.chat_bubble_rounded;String time(dynamic x){final d=DateTime.tryParse('$x')?.toLocal();if(d==null)return'';final q=DateTime.now().difference(d);if(q.inMinutes<1)return'Şimdi';if(q.inMinutes<60)return'${q.inMinutes} dk önce';if(q.inHours<24)return'${q.inHours} sa önce';return'${d.day}.${d.month}';}
String _cat(String t){final v=t.toLowerCase();if(v=='message'||v.contains('message')||v.contains('chat'))return'Mesaj';if(v=='call_request'||v.contains('call')||v.contains('arama'))return'Arama';if(v.contains('offer')||v.contains('deal')||v.contains('campaign')||v.contains('coupon')||v.contains('opportunity')||v.contains('firsat'))return'Fırsat';if(v=='move_vehicle'||v=='lights_on'||v=='damage'||v.contains('park')||v.contains('parking'))return'Park';return'Sistem';}
String _vTitle(String t){switch(t.toLowerCase()){case'move_vehicle':return'Park Uyarısı';case'lights_on':return'Farlarınız Açık';case'damage':return'Hasar Bildirimi';case'call_request':return'Arama Talebi';case'message':return'Yeni Mesaj';case'vehicle_added':return'Araç Eklendi';case'maintenance':case'maintenance_reminder':return'Bakım Hatırlatması';case'campaign':return'Kampanya';case'offer':case'deal':return'Fırsat';default:return _cat(t)=='Fırsat'?'Fırsat':_cat(t)=='Sistem'?'Sistem Bildirimi':'Bildirim';}}
IconData _vIcon(String t){switch(t.toLowerCase()){case'move_vehicle':return Icons.local_parking_rounded;case'lights_on':return Icons.lightbulb_rounded;case'damage':return Icons.warning_amber_rounded;case'call_request':return Icons.phone_in_talk_rounded;case'message':return Icons.chat_bubble_rounded;case'vehicle_added':return Icons.directions_car_filled_rounded;case'maintenance':case'maintenance_reminder':return Icons.build_circle_rounded;case'campaign':return Icons.campaign_rounded;case'offer':case'deal':return Icons.local_offer_rounded;default:return _cat(t)=='Fırsat'?Icons.local_offer_rounded:Icons.notifications_active_rounded;}}
Color _vColor(String t){switch(_cat(t)){case'Mesaj':return const Color(0xFF3B82F6);case'Arama':return const Color(0xFF22C983);case'Fırsat':return const Color(0xFFFFA62B);case'Park':return t=='damage'?const Color(0xFFFF4D63):_purple;default:return _purple;}}
DateTime? _dt(Map<String,dynamic> n)=>DateTime.tryParse('${n['created_at']??''}')?.toLocal();
bool _same(DateTime a,DateTime b)=>a.year==b.year&&a.month==b.month&&a.day==b.day;
String _when(Map<String,dynamic> n){final d=_dt(n);if(d==null)return'';final now=DateTime.now(),q=now.difference(d);if(q.inMinutes<1)return'Şimdi';if(q.inMinutes<60)return'${q.inMinutes} dk';if(_same(d,now))return'${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';return'${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}';}
String _group(Map<String,dynamic> n){final d=_dt(n);if(d==null)return'Daha Önce';final x=DateTime.now(),today=DateTime(x.year,x.month,x.day),day=DateTime(d.year,d.month,d.day),delta=today.difference(day).inDays;if(delta<=0)return'Bugün';if(delta==1)return'Dün';return'Daha Önce';}
String _desc(Map<String,dynamic> n){final m='${n['message']??''}'.trim(),p='${n['plate']??''}'.trim();if(m.isNotEmpty)return m;if(p.isNotEmpty)return'$p aracınızla ilgili yeni bir bildirim var.';switch(_cat('${n['type']??''}')){case'Arama':return'Araç sahibine ulaşmak için yeni bir arama talebi var.';case'Mesaj':return'Araç sahibine yeni bir mesaj bırakıldı.';case'Fırsat':return'Size özel yeni bir fırsat bulunuyor.';case'Park':return'Aracınızla ilgili yeni bir park bildirimi var.';default:return'CepQontag hesabınızla ilgili yeni bir bildirim var.';}}
List<Map<String,dynamic>> get filtered{
  const fs=['Tümü','Arama','Mesaj','Sistem'];
  if(tab==0)return List<Map<String,dynamic>>.from(items);
  final target=fs[tab];
  return items.where((e){
    final category=_cat('${e['type']??'system'}');
    return target=='Sistem'? !['Arama','Mesaj'].contains(category):category==target;
  }).toList();
}

Future<void> _markAllRead()async{final unread=items.where((e)=>e['status']=='new').toList();if(unread.isEmpty||markingAll)return;setState((){markingAll=true;for(final n in unread)n['status']='read';});ownerUnreadNotificationCount.value=0;try{for(final n in unread){final id='${n['id']??''}';if(id.isEmpty)continue;final r=await OwnerHttp.patch(Uri.parse('$base/api/owner/notifications/$id'),headers:{'Cache-Control':'no-cache'},body:jsonEncode({'status':'read'})).timeout(const Duration(seconds:10));if(r.statusCode<200||r.statusCode>=300)throw Exception();}await _load(silent:true);}catch(_){await _load(silent:true);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bazı bildirimler okundu olarak işaretlenemedi.')));}finally{if(mounted)setState(()=>markingAll=false);}}
@override Widget build(BuildContext c){final list=filtered,unread=items.where((e)=>e['status']=='new').length;final groups=<String,List<Map<String,dynamic>>>{'Bugün':[],'Dün':[],'Daha Önce':[]};for(final n in list)groups[_group(n)]!.add(n);return Scaffold(backgroundColor:OwnerReference.background,body:SafeArea(bottom:false,child:RefreshIndicator(onRefresh:_load,color:_purple,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,8,16,22),children:[_header(unread),const SizedBox(height:7),_filters(),const SizedBox(height:7),if(loading)const Padding(padding:EdgeInsets.all(48),child:Center(child:CircularProgressIndicator(color:_purple)))else if(error!=null)_state(Icons.error_outline_rounded,error!)else if(list.isEmpty)_state(Icons.notifications_none_rounded,tab==0?'Henüz bildiriminiz yok.':'Bu kategoride bildirim yok.')else ...[for(final g in ['Bugün','Dün','Daha Önce'])if(groups[g]!.isNotEmpty)_section(g,groups[g]!)]]))));}
Widget _header(int unread){
  final canMark=unread>0&&!markingAll;
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    OwnerReferenceHeader(
      onNotifications:(){},onSettings:widget.onSettings??(){},
      unread:unread>0,
    ),
    const SizedBox(height:20),
    Text('Bildirimler',style:TextStyle(
      color:OwnerReference.foreground,fontSize:28,fontWeight:FontWeight.w900)),
    const SizedBox(height:5),
    Text('Araçlarınızla ilgili tüm bildirimler burada.',
      style:TextStyle(color:OwnerReference.subtitle,fontSize:13)),
    if(canMark)
      Align(alignment:Alignment.centerRight,child:TextButton.icon(
        onPressed:_markAllRead,icon:const Icon(Icons.done_all_rounded,size:17),
        label:const Text('Tümünü okundu işaretle',style:TextStyle(fontSize:11)),
      ))
    else const SizedBox(height:12),
  ]);
}
Widget _filters(){
  const filters=[
    ('Tümü',Icons.apps_rounded),
    ('Aramalar',Icons.phone_in_talk_outlined),
    ('Mesajlar',Icons.chat_bubble_outline_rounded),
    ('Sistem',Icons.settings_outlined),
  ];
  return SizedBox(height:47,child:ListView.separated(
    scrollDirection:Axis.horizontal,itemCount:filters.length,
    separatorBuilder:(_,__)=>const SizedBox(width:8),
    itemBuilder:(_,i){
      final active=tab==i;
      return InkWell(
        onTap:()=>setState(()=>tab=i),
        borderRadius:BorderRadius.circular(23),
        child:AnimatedContainer(
          duration:const Duration(milliseconds:180),
          alignment:Alignment.center,
          padding:const EdgeInsets.symmetric(horizontal:14),
          decoration:BoxDecoration(
            color:active?OwnerReference.purple:OwnerReference.surface,
            borderRadius:BorderRadius.circular(23),
            boxShadow:CepqarTheme.isLight?[
              BoxShadow(color:OwnerReference.deep.withValues(alpha:.06),
                blurRadius:10,offset:const Offset(0,4)),
            ]:null,
          ),
          child:Row(children:[
            Icon(filters[i].$2,size:17,color:active?Colors.white:OwnerReference.subtitle),
            const SizedBox(width:7),
            Text(filters[i].$1,style:TextStyle(
              color:active?Colors.white:OwnerReference.subtitle,
              fontSize:12,fontWeight:FontWeight.w800)),
          ]),
        ),
      );
    },
  ));
}
Widget _section(String name,List<Map<String,dynamic>> xs)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Padding(padding:const EdgeInsets.fromLTRB(2,9,0,7),child:Text(name,style:TextStyle(color:_text,fontSize:CepqarTheme.cardTitle,fontWeight:FontWeight.w900))),for(final n in xs)...[_card(n),const SizedBox(height:7)]]);
Widget _card(Map<String,dynamic> n){final t='${n['type']??'system'}',fresh=n['status']=='new',color=_vColor(t),light=CepqarTheme.isLight;return Material(color:Colors.transparent,child:InkWell(onTap:()=>_details(n),borderRadius:BorderRadius.circular(15),child:Ink(padding:const EdgeInsets.fromLTRB(10,10,8,10),decoration:BoxDecoration(color:fresh?Color.alphaBlend(_purple.withValues(alpha:light ? .035 : .055),_panel):_panel,borderRadius:BorderRadius.circular(23),border:Border.all(color:fresh?_purple.withValues(alpha:light ? .18 : .27):_line),boxShadow:light?[BoxShadow(color:Colors.black.withValues(alpha:.025),blurRadius:10,offset:const Offset(0,3))]:null),child:Row(children:[Container(width:52,height:52,decoration:BoxDecoration(color:color.withValues(alpha:light ? .10 : .16),borderRadius:BorderRadius.circular(21)),child:Icon(_vIcon(t),color:color,size:24)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(_vTitle(t),maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:_text,fontSize:14,fontWeight:fresh?FontWeight.w900:FontWeight.w800)),const SizedBox(height:3),Text(_desc(n),maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:_muted,fontSize:CepqarTheme.bodySmall,height:1.2,fontWeight:FontWeight.w500))])),const SizedBox(width:7),SizedBox(width:48,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(_when(n),maxLines:1,style:TextStyle(color:_muted,fontSize:CepqarTheme.caption,fontWeight:FontWeight.w600)),const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.end,children:[if(fresh)const CircleAvatar(radius:3.5,backgroundColor:Color(0xFFFF4D63)),if(fresh)const SizedBox(width:6),Icon(Icons.chevron_right_rounded,color:_muted,size:18)])]))]))));}
Future<void> _details(Map<String,dynamic> n)async{
  final t='${n['type']??'system'}';
  final status='${n['status']??'new'}';
  final fresh=status=='new';
  final trackable=t!='message'&&t!='call_request';
  final color=_vColor(t);
  final photo='${n['photo_path']??''}'.trim();
  final lat=double.tryParse('${n['latitude']??''}');
  final lng=double.tryParse('${n['longitude']??''}');
  final plate='${n['plate']??''}'.trim();
  final hasExtras=photo.isNotEmpty||(lat!=null&&lng!=null);
  await showModalBottomSheet<void>(
    context:context,
    isScrollControlled:true,
    backgroundColor:_panel,
    shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(22))),
    builder:(sc){
      return SafeArea(
        top:false,
        child:Padding(
          padding:const EdgeInsets.fromLTRB(16,9,16,14),
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Center(child:Container(width:38,height:4,decoration:BoxDecoration(color:_line,borderRadius:BorderRadius.circular(4)))),
              const SizedBox(height:13),
              Row(children:[
                Container(width:42,height:42,decoration:BoxDecoration(color:color.withValues(alpha:.13),borderRadius:BorderRadius.circular(13)),child:Icon(_vIcon(t),color:color,size:21)),
                const SizedBox(width:10),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(_vTitle(t),style:TextStyle(color:_text,fontSize:15,fontWeight:FontWeight.w900)),
                  const SizedBox(height:2),
                  Text([if(plate.isNotEmpty)plate,_when(n)].join(' • '),style:TextStyle(color:_muted,fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w600)),
                ])),
                IconButton(onPressed:()=>Navigator.pop(sc),icon:Icon(Icons.close_rounded,color:_muted,size:20)),
              ]),
              const SizedBox(height:12),
              Container(
                width:double.infinity,
                padding:const EdgeInsets.all(12),
                decoration:BoxDecoration(
                  color:CepqarTheme.isLight?const Color(0xFFF7F7FB):const Color(0xFF0B1426),
                  borderRadius:BorderRadius.circular(14),
                  border:Border.all(color:_line),
                ),
                child:Text(_desc(n),style:TextStyle(color:_text,fontSize:CepqarTheme.body,height:1.38,fontWeight:FontWeight.w600)),
              ),
              if(hasExtras) ...[
                const SizedBox(height:8),
                Row(children:[
                  if(photo.isNotEmpty)
                    Expanded(child:TextButton.icon(
                      onPressed:()=>launchUrl(Uri.parse(photo.startsWith('http')?photo:'$base$photo')),
                      icon:const Icon(Icons.image_outlined,size:17),
                      label:const Text('Fotoğraf',style:TextStyle(fontSize:CepqarTheme.bodySmall)),
                    )),
                  if(photo.isNotEmpty&&lat!=null&&lng!=null)const SizedBox(width:6),
                  if(lat!=null&&lng!=null)
                    Expanded(child:TextButton.icon(
                      onPressed:()=>launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')),
                      icon:const Icon(Icons.location_on_outlined,size:17),
                      label:const Text('Konum',style:TextStyle(fontSize:CepqarTheme.bodySmall)),
                    )),
                ]),
              ],
              const SizedBox(height:11),
              Row(children:[
                Expanded(
                  child:trackable
                    ?FilledButton.icon(
                      onPressed:status=='resolved'||status=='arriving'?null:(){
                        Navigator.pop(sc);
                        _status(n,fresh?'read':'arriving');
                      },
                      style:FilledButton.styleFrom(
                        backgroundColor:_purple,
                        foregroundColor:Colors.white,
                        minimumSize:const Size(0,42),
                        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
                      ),
                      icon:Icon(fresh?Icons.visibility_rounded:Icons.directions_walk_rounded,size:17),
                      label:Text(
                        fresh?'Gördüm':status=='arriving'?'Geliyorum ✓':status=='resolved'?'Çözüldü':'Geliyorum',
                        style:const TextStyle(fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w800),
                      ),
                    )
                    :FilledButton.icon(
                      onPressed:(){
                        Navigator.pop(sc);
                        _reply(n);
                      },
                      style:FilledButton.styleFrom(
                        backgroundColor:_purple,
                        foregroundColor:Colors.white,
                        minimumSize:const Size(0,42),
                        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
                      ),
                      icon:const Icon(Icons.reply_rounded,size:17),
                      label:const Text('Cevapla',style:TextStyle(fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w800)),
                    ),
                ),
                const SizedBox(width:8),
                Expanded(
                  child:OutlinedButton.icon(
                    onPressed:status=='resolved'?null:(){
                      Navigator.pop(sc);
                      _status(n,'resolved');
                    },
                    style:OutlinedButton.styleFrom(
                      foregroundColor:_muted,
                      side:BorderSide(color:_line),
                      minimumSize:const Size(0,42),
                      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13)),
                    ),
                    icon:const Icon(Icons.check_circle_outline_rounded,size:17),
                    label:Text(status=='resolved'?'Çözüldü ✓':'Çözüldü',style:const TextStyle(fontSize:CepqarTheme.bodySmall,fontWeight:FontWeight.w800)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
    },
  );
}
Widget _state(IconData i,String t)=>Container(margin:const EdgeInsets.only(top:18),padding:const EdgeInsets.symmetric(horizontal:20,vertical:30),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Column(children:[Container(width:48,height:48,decoration:BoxDecoration(color:_purple.withValues(alpha:.10),borderRadius:BorderRadius.circular(15)),child:Icon(i,color:_purple,size:25)),const SizedBox(height:10),Text(t,textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:CepqarTheme.body,fontWeight:FontWeight.w700))]));}
