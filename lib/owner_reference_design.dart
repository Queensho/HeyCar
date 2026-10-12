import 'package:flutter/material.dart';

import 'cepqar_theme.dart';

/// Shared visual system for the five main owner tabs. Never changes
/// app navigation, authentication or the server-driven UI contract.
abstract final class OwnerReference {
  static const purple=Color(0xFF651FFF);
  static const deep=Color(0xFF351080);
  static const lilac=Color(0xFFEDE5FF);
  static const paper=Color(0xFFF8F6FF);
  static const ink=Color(0xFF101326);
  static const muted=Color(0xFF77788F);
  static const success=Color(0xFF20C978);
  static const danger=Color(0xFFFF3B45);

  static Color get background=>CepqarTheme.isLight?paper:CepqarTheme.bg;
  static Color get surface=>CepqarTheme.isLight?Colors.white:CepqarTheme.panel;
  static Color get foreground=>CepqarTheme.isLight?ink:Colors.white;
  static Color get subtitle=>CepqarTheme.isLight?muted:CepqarTheme.muted;
  static BoxDecoration card({double radius=24,bool highlight=false})=>
      BoxDecoration(
        color:surface,
        borderRadius:BorderRadius.circular(radius),
        border:Border.all(
          color:highlight?purple.withValues(alpha:.32):
              purple.withValues(alpha:CepqarTheme.isLight ? .08 : .20),
        ),
        boxShadow:CepqarTheme.isLight?[
          BoxShadow(color:deep.withValues(alpha:.075),blurRadius:24,
            offset:const Offset(0,8)),
        ]:null,
      );
}

class OwnerReferenceHeader extends StatelessWidget {
  const OwnerReferenceHeader({
    super.key,
    required this.onNotifications,
    required this.onSettings,
    required this.unread,
  });
  final VoidCallback onNotifications,onSettings;
  final bool unread;

  @override
  Widget build(BuildContext context){
    return SizedBox(
      height:52,
      child:Row(children:[
        Image.asset(
          CepqarTheme.isLight
              ?'assets/file_00000000b130820abb8d411e67ab0d25.png'
              :'assets/Logoyeni.png',
          height:37,fit:BoxFit.contain,alignment:Alignment.centerLeft,
        ),
        const Spacer(),
        _HeaderAction(icon:Icons.notifications_none_rounded,
          label:'Bildirimler',onTap:onNotifications,showDot:unread),
        const SizedBox(width:10),
        _HeaderAction(icon:Icons.settings_outlined,
          label:'Ayarlar',onTap:onSettings,showDot:false),
      ]),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,required this.label,required this.onTap,
    required this.showDot,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;
  @override Widget build(BuildContext context)=>Material(
    color:OwnerReference.surface,
    shape:const CircleBorder(),
    child:InkWell(
      onTap:onTap,customBorder:const CircleBorder(),
      child:SizedBox(width:42,height:42,child:Stack(children:[
        Center(child:Icon(icon,color:OwnerReference.foreground,size:24)),
        if(showDot)const Positioned(right:8,top:6,child:CircleAvatar(
          radius:4.5,backgroundColor:OwnerReference.danger)),
      ])),
    ),
  );
}

/// One fixed, genuinely interactive bottom bar, with an organic top edge.
/// SafeArea remains outside the painted area so iOS home indicator and
/// Android gesture navigation do not obscure controls.
class OwnerReferenceBottomNav extends StatelessWidget {
  const OwnerReferenceBottomNav({
    super.key,required this.selected,required this.onChanged,
    required this.unread,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  final bool unread;
  static const labels=['Anasayfa','Araçlarım','Hizmetler','Bildirimler','Profil'];
  static const icons=[
    Icons.home_outlined,Icons.directions_car_outlined,
    Icons.grid_view_rounded,Icons.receipt_long_outlined,Icons.person_outline,
  ];

  @override Widget build(BuildContext context){
    return DecoratedBox(
      decoration:const BoxDecoration(color:OwnerReference.deep),
      child:SafeArea(
        top:false,
        child:SizedBox(
          height:78,
          child:ClipPath(
            clipper:_NavigationWave(),
            child:DecoratedBox(
              decoration:const BoxDecoration(gradient:LinearGradient(
                begin:Alignment.topLeft,end:Alignment.bottomRight,
                colors:[Color(0xFF32106F),Color(0xFF48219B),Color(0xFF290A69)],
              )),
              child:Padding(
                padding:const EdgeInsets.fromLTRB(5,15,5,1),
                child:Row(children:List.generate(labels.length,(index){
                  final active=index==selected;
                  return Expanded(
                    child:Semantics(
                      button:true,selected:active,label:labels[index],
                      child:InkWell(
                        key:ValueKey('owner-reference-tab-$index'),
                        onTap:()=>onChanged(index),
                        borderRadius:BorderRadius.circular(34),
                        child:Stack(alignment:Alignment.center,children:[
                          if(active)IgnorePointer(child:Container(
                            key:const ValueKey('owner-reference-active-glow'),
                            width:58,height:58,
                            decoration:BoxDecoration(
                              shape:BoxShape.circle,
                              gradient:const RadialGradient(
                                colors:[Color(0xFF9133FF),Color(0xFF651BFC),Color(0x00551ACC)],
                                stops:[0,.63,1],
                              ),
                              boxShadow:[
                                BoxShadow(color:OwnerReference.purple.withValues(alpha:.50),
                                  blurRadius:17,spreadRadius:2),
                              ],
                            ),
                          )),
                          Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                            Stack(clipBehavior:Clip.none,children:[
                              Icon(icons[index],size:23,
                                color:active?Colors.white:const Color(0xFFC7B5EF)),
                              if(index==3&&unread)const Positioned(
                                right:-3,top:-2,
                                child:CircleAvatar(radius:3.7,backgroundColor:OwnerReference.danger),
                              ),
                            ]),
                            const SizedBox(height:3),
                            FittedBox(fit:BoxFit.scaleDown,child:Text(
                              labels[index],maxLines:1,
                              style:TextStyle(
                                fontSize:10.5,
                                fontWeight:active?FontWeight.w700:FontWeight.w500,
                                color:active?Colors.white:const Color(0xFFC7B5EF),
                              ),
                            )),
                          ]),
                        ]),
                      ),
                    ),
                  );
                })),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationWave extends CustomClipper<Path>{
  @override Path getClip(Size s){
    final p=Path()
      ..moveTo(0,12)
      ..cubicTo(s.width*.11,-2,s.width*.18,-1,s.width*.27,8)
      ..cubicTo(s.width*.40,19,s.width*.49,4,s.width*.59,9)
      ..cubicTo(s.width*.72,18,s.width*.78,-2,s.width*.88,7)
      ..cubicTo(s.width*.94,11,s.width*.98,9,s.width,14)
      ..lineTo(s.width,s.height)
      ..lineTo(0,s.height)
      ..close();
    return p;
  }
  @override bool shouldReclip(covariant CustomClipper<Path> oldClipper)=>false;
}
