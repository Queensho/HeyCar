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

/// A compact, horizontally scrollable shortcut strip in admin-published order.
/// Swipe left to reveal additional shortcuts without changing their actions.
class OwnerQuickAccessPanel extends StatelessWidget {
  const OwnerQuickAccessPanel({super.key,required this.items});
  final List<OwnerQuickPanelItem> items;

  @override
  Widget build(BuildContext context) {
    if(items.isEmpty)return const SizedBox.shrink();
    final visible=items;
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
        child:ListView.separated(
          key:const ValueKey('owner-quick-horizontal-list'),
          scrollDirection:Axis.horizontal,
          physics:const BouncingScrollPhysics(),
          itemCount:visible.length,
          separatorBuilder:(_,i)=>Container(
            key:ValueKey('owner-quick-divider-${i+1}'),
            width:1,height:58,
            margin:const EdgeInsets.symmetric(vertical:18),
            color:const Color(0xFFE7E7EF),
          ),
          itemBuilder:(context,i)=>SizedBox(
            width:compact?82:90,
            child:
              InkWell(
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
                        child:visible[i].iconUrl.isNotEmpty
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
        ),
      );
    });
  }
}
