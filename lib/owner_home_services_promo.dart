import 'package:flutter/material.dart';

import 'app_ui_config.dart';

/// Presentation-only replacement for the home services_grid component.
/// The existing admin-configured service list remains the sole data source.
class OwnerHomeServicesPromo extends StatelessWidget {
  const OwnerHomeServicesPromo({
    super.key,required this.services,
    required this.onOpenServices,required this.tokens,
  });
  final List<AppUiServiceItem> services;
  final VoidCallback onOpenServices;
  final AppUiTokens tokens;

  static bool isLive(AppUiServiceItem item) {
    final badge=item.badgeText.trim().toLowerCase();
    return !item.testOnly&&item.action!='NONE'&&
      !badge.contains('yakında')&&!badge.contains('yakinda')&&
      !badge.contains('coming soon');
  }

  static String descriptionFor(List<AppUiServiceItem> services) {
    final active=services.where(isLive).toList();
    if(active.isEmpty){
      return 'Çekici, vale, yol yardımı ve daha fazlası yakında hizmetinizde.';
    }
    if(active.length==services.length){
      return 'Çekici, vale, yol yardımı ve daha fazlası hizmetinizde.';
    }
    final first=active.take(2).map((s)=>s.title.trim())
      .where((name)=>name.isNotEmpty).join(', ');
    return first.isEmpty?'Yeni hizmetlerimiz hizmetinizde.':
      '$first hizmetinizde, diğerleri yakında.';
  }

  Color _tagColor(AppUiServiceItem service) {
    return switch(service.id){
      'towing' when service.iconToken=='warning'=>const Color(0xFF651FFF),
      'roadside' when service.iconToken=='danger'=>const Color(0xFF651FFF),
      'valet' when service.iconToken=='primary'=>const Color(0xFF2978D8),
      'offers' when service.iconToken=='success'=>const Color(0xFF478D19),
      _=>tokens.token(service.iconToken),
    };
  }

  AppUiServiceItem? get _featuredService {
    for(final service in services){
      if(service.id=='towing'&&service.imageUrl.trim().isNotEmpty){
        return service;
      }
    }
    for(final service in services){
      if(service.imageUrl.trim().isNotEmpty)return service;
    }
    return null;
  }

  Widget _artwork(bool narrow) {
    final featured=_featuredService;
    final side=narrow?60.0:78.0;
    final url=featured?.imageUrl.trim()??'';
    return Container(
      width:side,height:side,
      clipBehavior:Clip.antiAlias,
      decoration:BoxDecoration(
        borderRadius:BorderRadius.circular(22),
        color:const Color(0xFFF0E8FF),
      ),
      child:Stack(fit:StackFit.expand,children:[
        const Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
          gradient:RadialGradient(
            center:Alignment.topLeft,radius:1.1,
            colors:[Color(0xFFE5D4FF),Color(0xFFF8F4FF)],
          ),
        ))),
        if(url.isEmpty)
          Icon(Icons.fire_truck_rounded,size:narrow?37:49,
            color:const Color(0xFF651FFF))
        else
          Transform.translate(
            offset:Offset(featured!.imageX*.2,featured.imageY*.2),
            child:Transform.scale(
              scale:featured.imageScale.clamp(.5,1.5).toDouble(),
              child:Opacity(
                opacity:featured.imageOpacity.clamp(0,1).toDouble(),
                child:Image.network(
                  url,fit:featured.fit=='cover'?BoxFit.cover:BoxFit.contain,
                  errorBuilder:(_,__,___)=>Icon(
                    Icons.fire_truck_rounded,size:narrow?37:49,
                    color:const Color(0xFF651FFF)),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if(services.isEmpty)return const SizedBox.shrink();
    return LayoutBuilder(builder:(context,box){
      final narrow=box.maxWidth<330;
      return Material(
        color:Colors.white,borderRadius:BorderRadius.circular(24),
        child:InkWell(
          key:const ValueKey('owner-home-services-promo'),
          onTap:onOpenServices,
          borderRadius:BorderRadius.circular(24),
          child:Container(
            height:124,
            padding:EdgeInsets.symmetric(horizontal:narrow?10:12,vertical:10),
            decoration:BoxDecoration(
              borderRadius:BorderRadius.circular(24),
              border:Border.all(color:const Color(0xFFECECF3)),
              boxShadow:const [BoxShadow(
                color:Color(0x10101426),blurRadius:15,offset:Offset(0,5)),
              ],
            ),
            child:Row(children:[
              _artwork(narrow),
              SizedBox(width:narrow?7:10),
              Expanded(child:Column(
                mainAxisAlignment:MainAxisAlignment.center,
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text('CepQontag Hizmetleri',maxLines:2,
                    overflow:TextOverflow.ellipsis,
                    style:TextStyle(color:const Color(0xFF101426),
                      fontSize:narrow?13.5:15.3,
                      fontWeight:FontWeight.w700,height:1.05)),
                  const SizedBox(height:3),
                  Text(descriptionFor(services),maxLines:2,
                    overflow:TextOverflow.ellipsis,
                    style:TextStyle(color:const Color(0xFF737B94),
                      fontSize:narrow?10.1:11.2,height:1.13)),
                  const SizedBox(height:7),
                  SizedBox(
                    height:20,
                    child:ListView.separated(
                      key:const ValueKey('owner-home-service-tags'),
                      scrollDirection:Axis.horizontal,
                      physics:const BouncingScrollPhysics(),
                      itemCount:services.length,
                      separatorBuilder:(_,__)=>const SizedBox(width:5),
                      itemBuilder:(context,i){
                        final service=services[i];
                        final tagColor=_tagColor(service);
                        return Container(
                          key:ValueKey('owner-service-tag-'+service.id),
                          padding:const EdgeInsets.symmetric(horizontal:9,vertical:2),
                          decoration:BoxDecoration(
                            color:tagColor.withValues(alpha:.11),
                            borderRadius:BorderRadius.circular(12)),
                          child:Center(child:Text(service.title,
                            maxLines:1,overflow:TextOverflow.ellipsis,
                            style:TextStyle(color:tagColor,
                              fontSize:10,fontWeight:FontWeight.w700))),
                        );
                      },
                    ),
                  ),
                ],
              )),
              SizedBox(width:narrow?5:8),
              Container(
                width:narrow?32:38,height:narrow?32:38,
                decoration:const BoxDecoration(
                  color:Color(0xFFF1EAFF),shape:BoxShape.circle),
                child:const Icon(Icons.chevron_right_rounded,
                  color:Color(0xFF651FFF),size:25),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
