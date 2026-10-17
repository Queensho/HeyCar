import 'package:flutter/material.dart';

/// Presentation-only data for a server-driven or locally customized shortcut.
/// The calling home page owns all action and navigation mappings.
@immutable
class OwnerQuickPanelItem {
  const OwnerQuickPanelItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
    this.onLongPress,
    this.iconUrl='',
  });
  final String id;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String iconUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
}

/// One compact panel, not four separate elevated cards. The list is supplied
/// by the existing admin config in its published order and may contain 1–4
/// enabled entries; every visible entry receives the same available width.
class OwnerQuickAccessPanel extends StatelessWidget {
  const OwnerQuickAccessPanel({super.key,required this.items});
  final List<OwnerQuickPanelItem> items;
  static const _assetIcons=<String,String>{
    'qr':'assets/images/services/QR_Kodum.png',
    'qr_security':'assets/images/services/QR_Guvenligi.png',
    'vehicle':'assets/images/services/Arac_Bilgilerim.png',
    'notifications':'assets/images/services/Bildirimler.png',
    'insurance':'assets/images/services/Sigorta_Kasko.png',
    'settings':'assets/images/services/Ayarlar.png',
  };

  @override
  Widget build(BuildContext context) {
    if(items.isEmpty)return const SizedBox.shrink();
    final visible=items.take(4).toList(growable:false);
    return LayoutBuilder(builder:(context,c){
      final compact=c.maxWidth<348;
      final side=compact?42.0:48.0;
      final fontSize=compact?10.2:11.5;
      return Container(
        key:const ValueKey('owner-home-quick-panel'),
        height:116,
        clipBehavior:Clip.antiAlias,
        decoration:BoxDecoration(
          color:const Color(0xFFFFFFFF),
          borderRadius:BorderRadius.circular(22),
          border:Border.all(color:const Color(0xFFE9EAF1)),
          boxShadow:const [BoxShadow(
            color:Color(0x0D101426),blurRadius:14,offset:Offset(0,5),
          )],
        ),
        padding:EdgeInsets.symmetric(horizontal:compact?6:10,vertical:10),
        child:Row(children:[
          for(var i=0;i<visible.length;i++)...[
            if(i>0)Container(
              key:ValueKey('owner-quick-divider-'+i.toString()),
              width:1,height:58,
              color:const Color(0xFFE7E7EF),
            ),
            Expanded(
              child:InkWell(
                key:ValueKey('owner-quick-'+visible[i].id),
                onTap:visible[i].onTap,
                onLongPress:visible[i].onLongPress,
                borderRadius:BorderRadius.circular(15),
                child:Padding(
                  padding:const EdgeInsets.symmetric(horizontal:2),
                  child:Column(
                    mainAxisAlignment:MainAxisAlignment.center,
                    children:[
                      Container(
                        width:side,height:side,
                        decoration:BoxDecoration(
                          color:visible[i].iconBackground,
                          borderRadius:BorderRadius.circular(16),
                        ),
                        alignment:Alignment.center,
                        child:_assetIcons.containsKey(visible[i].id)
                          ?Image.asset(
                            _assetIcons[visible[i].id]!,
                            fit:BoxFit.contain,
                            errorBuilder:(_,__,___)=>Icon(
                              visible[i].icon,color:visible[i].iconColor,size:24),
                          )
                          :visible[i].iconUrl.isNotEmpty
                            ?Padding(
                              padding:const EdgeInsets.all(4),
                              child:Image.network(
                                visible[i].iconUrl,
                                fit:BoxFit.contain,
                                errorBuilder:(_,__,___)=>Icon(
                                  visible[i].icon,color:visible[i].iconColor,size:24),
                              ),
                            )
                            :Icon(visible[i].icon,
                                color:visible[i].iconColor,size:24),
                      ),
                      const SizedBox(height:8),
                      Flexible(child:Text(
                        visible[i].title,
                        maxLines:2,softWrap:true,
                        overflow:TextOverflow.ellipsis,
                        textAlign:TextAlign.center,
                        style:TextStyle(
                          color:const Color(0xFF101426),
                          fontSize:fontSize,
                          fontWeight:FontWeight.w600,
                          height:1.05,
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ]),
      );
    });
  }
}
