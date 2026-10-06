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
      padding:const EdgeInsets.fromLTRB(16,14,0,0),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(
          padding:const EdgeInsets.only(right:16),
          child:Row(children:[
            Expanded(child:Text('Öne Çıkanlar',style:TextStyle(color:CepqarTheme.text,fontSize:16,fontWeight:FontWeight.w900))),
            InkWell(
              onTap:()=>_open(g.firstWhere((x)=>!x.viewed,orElse:()=>g.first)),
              borderRadius:BorderRadius.circular(12),
              child:const Padding(
                padding:EdgeInsets.symmetric(horizontal:3,vertical:5),
                child:Row(children:[
                  Text('Tümünü Gör',style:TextStyle(color:CepqarTheme.purple,fontSize:11,fontWeight:FontWeight.w900)),
                  Icon(Icons.chevron_right_rounded,color:CepqarTheme.purple,size:17),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height:9),
        SizedBox(
          height:126,
          child:ListView.separated(
            scrollDirection:Axis.horizontal,
            padding:const EdgeInsets.only(right:16),
            itemCount:g.length,
            separatorBuilder:(_,__)=>const SizedBox(width:10),
            itemBuilder:(_,i){
              final group=g[i],s=group.first;
              final viewed=group.viewed;
              return SizedBox(
                width:76,
                child:InkWell(
                  onTap:()=>_open(group),
                  borderRadius:BorderRadius.circular(38),
                  child:Column(children:[
                    Stack(clipBehavior:Clip.none,children:[
                      Container(
                        width:70,height:70,padding:const EdgeInsets.all(3),
                        decoration:BoxDecoration(
                          shape:BoxShape.circle,
                          gradient:viewed?null:const LinearGradient(
                            begin:Alignment.topLeft,end:Alignment.bottomRight,
                            colors:[CepqarTheme.purple,Color(0xFF8759FF),CepqarTheme.lime],
                          ),
                          color:viewed?const Color(0xFFCED1D9):null,
                        ),
                        child:Container(
                          padding:const EdgeInsets.all(2),
                          decoration:BoxDecoration(shape:BoxShape.circle,color:CepqarTheme.panel),
                          child:ClipOval(
                            child:s.thumbnailUrl.isEmpty
                              ?Container(color:CepqarTheme.purple.withValues(alpha:.10),child:Icon(_icon(s.categoryIcon),color:CepqarTheme.purple,size:30))
                              :Image.network(
                                  s.thumbnailUrl,
                                  fit:BoxFit.cover,
                                  errorBuilder:(_,__,___)=>Container(color:CepqarTheme.purple.withValues(alpha:.10),child:Icon(_icon(s.categoryIcon),color:CepqarTheme.purple,size:30)),
                                ),
                          ),
                        ),
                      ),
                      if(s.badgeType!='none'&&s.badgeText.isNotEmpty)
                        Positioned(
                          right:-5,top:0,
                          child:Container(
                            constraints:const BoxConstraints(maxWidth:58),
                            padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),
                            decoration:BoxDecoration(
                              color:const Color(0xFFFF465D),
                              borderRadius:BorderRadius.circular(12),
                              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.10),blurRadius:5,offset:const Offset(0,2))],
                            ),
                            child:Text(s.badgeText,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:8.5,fontWeight:FontWeight.w900)),
                          ),
                        ),
                    ]),
                    const SizedBox(height:6),
                    Text(s.categoryName.isNotEmpty?s.categoryName:s.title,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.text,fontSize:10.5,fontWeight:FontWeight.w900)),
                    if(s.subtitle.isNotEmpty)...[
                      const SizedBox(height:2),
                      Text(s.subtitle,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:TextStyle(color:CepqarTheme.muted,fontSize:8.2,height:1.12,fontWeight:FontWeight.w600)),
                    ],
                  ]),
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
