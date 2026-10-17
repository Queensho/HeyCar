import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';

/// Shared authenticated owner avatar, used on home, profile and account.
class OwnerAvatarStore {
  static final ValueNotifier<Uint8List?> image=ValueNotifier(null);
  static String _token='';
  static Future<void>? _pending;

  static bool _isImage(Uint8List bytes) {
    if(bytes.length<12)return false;
    final png=bytes[0]==137&&bytes[1]==80&&bytes[2]==78&&bytes[3]==71;
    final jpeg=bytes[0]==255&&bytes[1]==216&&bytes[2]==255;
    final webp=String.fromCharCodes(bytes.sublist(0,4))=='RIFF'&&
      String.fromCharCodes(bytes.sublist(8,12))=='WEBP';
    return png||jpeg||webp;
  }

  static Future<void> load({bool force=false}) async {
    await OwnerAuth.restore();
    final token=OwnerAuth.accessToken;
    if(token.isEmpty){_token='';image.value=null;return;}
    if(_token!=token){_token=token;image.value=null;_pending=null;}
    if(!force&&image.value!=null)return;
    if(_pending!=null)return _pending;
    final request=_fetch(token);
    _pending=request;
    try{await request;}finally{if(identical(_pending,request))_pending=null;}
  }

  static Future<void> _fetch(String token)async{
    try{
      final r=await OwnerHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/account/avatar'),
        json:false).timeout(const Duration(seconds:12));
      if(_token!=token)return;
      if(r.statusCode==200&&_isImage(r.bodyBytes)){
        image.value=r.bodyBytes;
      }else{
        image.value=null;
      }
    }catch(_){}
  }

  static void setUploaded(Uint8List bytes){
    if(_isImage(bytes))image.value=bytes;
  }
}

class OwnerAvatar extends StatefulWidget{
  const OwnerAvatar({super.key,required this.initials,required this.radius,
    this.background=const Color(0xFF651FFF),
    this.foreground=Colors.white});
  final String initials;
  final double radius;
  final Color background,foreground;
  @override State<OwnerAvatar> createState()=>_OwnerAvatarState();
}
class _OwnerAvatarState extends State<OwnerAvatar>{
  @override void initState(){super.initState();OwnerAvatarStore.load();}
  @override Widget build(BuildContext context)=>ValueListenableBuilder<Uint8List?>(
    valueListenable:OwnerAvatarStore.image,
    builder:(context,bytes,_)=>CircleAvatar(
      radius:widget.radius,backgroundColor:widget.background,
      foregroundImage:bytes==null?null:MemoryImage(bytes),
      child:bytes==null?Text(widget.initials,maxLines:1,
        style:TextStyle(color:widget.foreground,fontSize:widget.radius*.65,
          fontWeight:FontWeight.w800)):null,
    ),
  );
}
