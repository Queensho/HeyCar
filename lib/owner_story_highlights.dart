import 'dart:async';

import 'package:flutter/material.dart';

import 'cepqar_theme.dart';
import 'story_service.dart';

class OwnerStoryHighlights extends StatefulWidget{
  const OwnerStoryHighlights({
    super.key,
    required this.items,
    required this.service,
    required this.shortcut,
    required this.onChanged,
  });
  final List<StoryItem> items;
  final StoryService service;
  final ValueChanged<String> shortcut;
  final VoidCallback onChanged;
  @override State<OwnerStoryHighlights> createState()=>_OwnerStoryHighlightsState();
}

class _OwnerStoryHighlightsState extends State<OwnerStoryHighlights>{
  final Set<String> _impressed={};

  @override void initState(){super.initState();_markImpressions();}
  @override void didUpdateWidget(covariant OwnerStoryHighlights oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.items.map((e)=>e.id).join(',')!=widget.items.map((e)=>e.id).join(','))_markImpressions();
  }
  void _markImpressions(){
    WidgetsBinding.instance.addPostFrameCallback((_){
      for(final s in widget.items){
        if(_impressed.add(s.id))widget.service.mark(s.id,'impression');
      }
    });
  }

  List<_StoryGroup> get groups{
    final map=<String,List<StoryItem>>{};
    for(final item in widget.items){
      final key=item.categoryId.isNotEmpty?item.categoryId:(item.categorySlug.isNotEmpty?item.categorySlug:item.id);
      map.putIfAbsent(key,()=>[]).add(item);
    }
    final out=< _StoryGroup>[];
    for(final entry in map.entries){
      final list=entry.value..sort((a,b)=>a.sortOrder.compareTo(b.sortOrder));
      out.add(_StoryGroup(items:list));
    }
    out.sort((a,b)=>a.first.sortOrder.compareTo(b.first.sortOrder));
    return out;
  }

  IconData _icon(String value)=>switch(value){
    'towing'=>Icons.fire_truck_rounded,
    'valet'=>Icons.local_parking_rounded,
    'fuel'=>Icons.local_gas_station_rounded,
    'car_wash'=>Icons.local_car_wash_rounded,
    'service'=>Icons.build_rounded,
    'parking'=>Icons.local_parking_rounded,
    'gift'=>Icons.card_giftcard_rounded,
    _=>Icons.local_offer_rounded,
  };

  Future<void> _open(_StoryGroup group)async{
    if(group.items.isEmpty)return;
    await widget.service.mark(group.items.first.id,'open');
    if(!mounted)return;
    await Navigator.push(context,PageRouteBuilder(
      opaque:true,
      transitionDuration:const Duration(milliseconds:220),
      pageBuilder:(_,animation,__)=>FadeTransition(
        opacity:animation,
        child:StoryViewerPage(
          items:group.items,
          service:widget.service,
          shortcut:widget.shortcut,
        ),
      ),
    ));
    widget.onChanged();
  }


  @override Widget build(BuildContext context){
    final g=groups;
    if(g.isEmpty)return const SizedBox.shrink();
    return Padding(
      padding:const EdgeInsets.fromLTRB(16,15,0,0),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(
          padding:const EdgeInsets.only(right:16),
          child:Row(children:[
            Expanded(child:Text('Öne Çıkanlar',
              style:TextStyle(color:CepqarTheme.text,fontSize:18,fontWeight:FontWeight.w900))),
            InkWell(
              onTap:()=>_open(g.firstWhere((x)=>!x.viewed,orElse:()=>g.first)),
              borderRadius:BorderRadius.circular(12),
              child:const Padding(
                padding:EdgeInsets.symmetric(horizontal:3,vertical:4),
                child:Row(children:[
                  Text('Tümünü Gör',style:TextStyle(color:CepqarTheme.purple,fontSize:11,fontWeight:FontWeight.w800)),
                  Icon(Icons.chevron_right_rounded,color:CepqarTheme.purple,size:17),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height:8),
        SizedBox(
          height:84,
          child:ListView.separated(
            scrollDirection:Axis.horizontal,
            physics:const BouncingScrollPhysics(),
            padding:const EdgeInsets.only(right:16),
            itemCount:g.length,
            separatorBuilder:(_,__)=>const SizedBox(width:8),
            itemBuilder:(_,i){
              final group=g[i],item=group.first;
              return SizedBox(
                width:137,
                child:InkWell(
                  onTap:()=>_open(group),
                  borderRadius:BorderRadius.circular(17),
                  child:ClipRRect(
                    borderRadius:BorderRadius.circular(17),
                    child:Stack(fit:StackFit.expand,children:[
                      DecoratedBox(decoration:const BoxDecoration(
                        gradient:LinearGradient(
                          begin:Alignment.topLeft,end:Alignment.bottomRight,
                          colors:[Color(0xFF141735),Color(0xFF6945AC)],
                        ),
                      )),
                      if(item.thumbnailUrl.isNotEmpty)Image.network(
                        item.thumbnailUrl,fit:BoxFit.cover,
                        errorBuilder:(_,__,___)=>Center(child:Icon(
                          _icon(item.categoryIcon),color:Colors.white70,size:42)),
                      )else Center(child:Icon(
                        _icon(item.categoryIcon),color:Colors.white70,size:42)),
                      const DecoratedBox(decoration:BoxDecoration(
                        gradient:LinearGradient(
                          begin:Alignment.topCenter,end:Alignment.bottomCenter,
                          colors:[Colors.transparent,Color(0xD9000014)],
                          stops:[.25,1],
                        ),
                      )),
                      Positioned(left:9,right:25,bottom:9,child:Column(
                        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
                        children:[
                          Text(item.categoryName.isNotEmpty?item.categoryName:item.title,
                            maxLines:1,overflow:TextOverflow.ellipsis,
                            style:const TextStyle(color:Colors.white,fontSize:12,
                              fontWeight:FontWeight.w900,height:1.1)),
                          if(item.subtitle.isNotEmpty)...[
                            const SizedBox(height:3),
                            Text(item.subtitle,maxLines:1,overflow:TextOverflow.ellipsis,
                              style:const TextStyle(color:Colors.white70,fontSize:9,height:1.1)),
                          ],
                        ],
                      )),
                      const Positioned(right:7,bottom:8,
                        child:CircleAvatar(radius:11,backgroundColor:Color(0xEFFFFFFF),
                          child:Icon(Icons.chevron_right_rounded,size:17,color:Color(0xFF5C20E3)))),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _StoryGroup{
  const _StoryGroup({required this.items});
  final List<StoryItem> items;
  StoryItem get first=>items.first;
  bool get viewed=>items.every((e)=>e.viewed);
}

class StoryViewerPage extends StatefulWidget{
  const StoryViewerPage({
    super.key,
    required this.items,
    required this.service,
    required this.shortcut,
  });
  final List<StoryItem> items;
  final StoryService service;
  final ValueChanged<String> shortcut;
  @override State<StoryViewerPage> createState()=>_StoryViewerPageState();
}
class _StoryViewerPageState extends State<StoryViewerPage> with SingleTickerProviderStateMixin{
  int index=0;
  late final AnimationController progress;

  StoryItem get item=>widget.items[index];

  @override void initState(){
    super.initState();
    progress=AnimationController(vsync:this,duration:const Duration(seconds:6))..addStatusListener((s){
      if(s==AnimationStatus.completed)_next();
    });
    _showCurrent();
  }
  @override void dispose(){progress.dispose();super.dispose();}

  void _showCurrent(){
    widget.service.mark(item.id,'open');
    widget.service.mark(item.id,'view');
    progress.forward(from:0);
  }
  void _next(){
    if(index>=widget.items.length-1){Navigator.pop(context);return;}
    setState(()=>index++);
    _showCurrent();
  }
  void _previous(){
    if(index<=0){progress.forward(from:0);return;}
    setState(()=>index--);
    _showCurrent();
  }
  Future<void> _cta()async{
    progress.stop();
    await widget.service.mark(item.id,'click');
    if(!mounted)return;
    await StoryActionHandler.handle(context,item,widget.shortcut);
    if(mounted)progress.forward();
  }

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:Colors.black,
    body:Stack(children:[
      Positioned.fill(
        child:item.contentImageUrl.isEmpty
          ?Container(color:const Color(0xFF171127))
          :Image.network(item.contentImageUrl,fit:BoxFit.cover,errorBuilder:(_,__,___)=>Container(color:const Color(0xFF171127))),
      ),
      Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(
          begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:[Colors.black.withValues(alpha:.48),Colors.transparent,Colors.black.withValues(alpha:.74)],
          stops:const [0,.48,1],
        ),
      ))),
      Positioned.fill(
        child:Row(children:[
          Expanded(child:GestureDetector(behavior:HitTestBehavior.translucent,onTap:_previous)),
          Expanded(child:GestureDetector(behavior:HitTestBehavior.translucent,onTap:_next)),
        ]),
      ),
      SafeArea(
        child:Padding(
          padding:const EdgeInsets.fromLTRB(12,8,12,16),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:List.generate(widget.items.length,(i)=>Expanded(child:Padding(
              padding:EdgeInsets.only(right:i==widget.items.length-1?0:4),
              child:AnimatedBuilder(
                animation:progress,
                builder:(_,__)=>LinearProgressIndicator(
                  minHeight:2.5,
                  borderRadius:BorderRadius.circular(4),
                  value:i<index?1:i>index?0:progress.value,
                  backgroundColor:Colors.white.withValues(alpha:.28),
                  valueColor:const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            )))),
            const SizedBox(height:10),
            Row(children:[
              Expanded(child:Text(item.categoryName.isNotEmpty?item.categoryName:item.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w900))),
              IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded,color:Colors.white,size:26)),
            ]),
            const Spacer(),
            if(item.badgeType!='none'&&item.badgeText.isNotEmpty)
              Container(
                margin:const EdgeInsets.only(bottom:9),
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                decoration:BoxDecoration(color:const Color(0xFFFF465D),borderRadius:BorderRadius.circular(12)),
                child:Text(item.badgeText,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w900)),
              ),
            Text(item.title,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900,height:1.05)),
            if(item.subtitle.isNotEmpty)...[
              const SizedBox(height:7),
              Text(item.subtitle,style:TextStyle(color:Colors.white.withValues(alpha:.86),fontSize:13,height:1.35,fontWeight:FontWeight.w600)),
            ],
            if(item.ctaEnabled&&item.actionType!='NONE')...[
              const SizedBox(height:16),
              SizedBox(
                width:double.infinity,height:50,
                child:FilledButton(
                  onPressed:_cta,
                  style:FilledButton.styleFrom(
                    backgroundColor:CepqarTheme.lime,
                    foregroundColor:Colors.black,
                    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15)),
                  ),
                  child:Text(item.ctaText.isEmpty?'DETAYI GÖR':item.ctaText.toUpperCase(),style:const TextStyle(fontWeight:FontWeight.w900,letterSpacing:.2)),
                ),
              ),
            ],
          ]),
        ),
      ),
    ]),
  );
}
