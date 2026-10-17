import 'package:flutter/material.dart';

/// Data-only presentation model; existing authenticated owner API supplies counts.
@immutable
class OwnerMonthlyMetric {
  const OwnerMonthlyMetric({
    required this.id,required this.label,required this.icon,
    required this.tint,required this.background,required this.count,
    this.onTap,this.changePercent,
  });
  final String id,label;
  final IconData icon;
  final Color tint,background;
  final int? count;
  final VoidCallback? onTap;
  final double? changePercent;
}

/// Responsive monthly overview: four equal-width cards on every mobile width.
class OwnerMonthlySummaryPanel extends StatelessWidget {
  const OwnerMonthlySummaryPanel({
    super.key,required this.metrics,required this.onViewAll,
    this.isLoading=false,this.hasError=false,this.onRetry,
  });
  final List<OwnerMonthlyMetric> metrics;
  final VoidCallback onViewAll;
  final bool isLoading,hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context){
    return Container(
      key:const ValueKey('owner-monthly-summary-panel'),
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(
        color:Colors.white,borderRadius:BorderRadius.circular(21),
        border:Border.all(color:const Color(0xFFECECF3)),
        boxShadow:const [
          BoxShadow(color:Color(0x0C101426),blurRadius:17,offset:Offset(0,5)),
        ],
      ),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          const _SummaryBarsIcon(),
          const SizedBox(width:7),
          const Expanded(child:Text('Bu Ayki Özetim',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:Color(0xFF101426),fontSize:17,
              fontWeight:FontWeight.w800))),
          InkWell(
            key:const ValueKey('owner-monthly-view-all'),onTap:onViewAll,
            borderRadius:BorderRadius.circular(18),
            child:const Padding(padding:EdgeInsets.symmetric(vertical:7,horizontal:9),
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                Text('Tümünü Gör',style:TextStyle(color:Color(0xFF651FFF),
                  fontSize:11,fontWeight:FontWeight.w700)),
                Icon(Icons.chevron_right_rounded,color:Color(0xFF651FFF),size:19),
              ]),
            ),
          ),
        ]),
        const SizedBox(height:10),
        if(isLoading)
          const SizedBox(height:64,child:Center(child:SizedBox(
            width:28,height:28,child:CircularProgressIndicator(
              strokeWidth:2.5,color:Color(0xFF651FFF)),
          )))
        else if(hasError)
          SizedBox(height:64,child:Row(
            mainAxisAlignment:MainAxisAlignment.center,children:[
              const Flexible(child:Text('İstatistikler yüklenemedi.',
                style:TextStyle(color:Color(0xFF737B94),fontSize:12))),
              if(onRetry!=null)TextButton(
                onPressed:onRetry,child:const Text('Tekrar dene')),
            ],
          ))
        else if(metrics.isEmpty)
          const SizedBox(height:64,child:Center(child:Text(
            'Henüz istatistik bulunmuyor.',
            style:TextStyle(color:Color(0xFF737B94),fontSize:12),
          )))
        else LayoutBuilder(builder:(context,box){
          const gap=6.0;
          final count=metrics.length>4?4:metrics.length;
          // The parent already applies the 16 px page gutters.
          // Equal Expanded tiles keep all four metrics in one row even at 320 px.
          return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            for(var i=0;i<count;i++)...[
              if(i>0)const SizedBox(width:gap),
              Expanded(child:_MonthlyMetricTile(metric:metrics[i],
                availableWidth:(box.maxWidth-gap*(count-1))/count)),
            ],
          ]);
        }),
      ]),
    );
  }
}

class _SummaryBarsIcon extends StatelessWidget {
  const _SummaryBarsIcon();
  @override Widget build(BuildContext context)=>SizedBox(
    width:23,height:23,
    child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
      Container(width:6,height:12,decoration:BoxDecoration(
        color:const Color(0xFF651FFF),borderRadius:BorderRadius.circular(4))),
      const SizedBox(width:2),
      Container(width:6,height:22,decoration:BoxDecoration(
        color:const Color(0xFF651FFF),borderRadius:BorderRadius.circular(4))),
      const SizedBox(width:2),
      Container(width:6,height:9,decoration:BoxDecoration(
        color:const Color(0xFFB9FF45),borderRadius:BorderRadius.circular(4))),
    ]),
  );
}

class _MonthlyMetricTile extends StatelessWidget{
  const _MonthlyMetricTile({required this.metric,required this.availableWidth});
  final OwnerMonthlyMetric metric;
  final double availableWidth;

  @override
  Widget build(BuildContext context){
    final change=metric.changePercent;
    final showChange=change!=null&&change.isFinite;
    final narrow=availableWidth<68;
    final iconSize=narrow?19.0:22.0;
    final accent=metric.id=='messages'?const Color(0xFF9D58FF):
      metric.id=='park'?const Color(0xFFFF7191):
      metric.id=='calls'?const Color(0xFFBEC8F7):
      const Color(0xFFB9FF45);
    return Material(color:Colors.transparent,child:InkWell(
      key:ValueKey('owner-monthly-'+metric.id),
      onTap:metric.onTap,
      borderRadius:BorderRadius.circular(16),
      child:Container(
        height:120,
        clipBehavior:Clip.antiAlias,
        decoration:BoxDecoration(color:metric.background,
          borderRadius:BorderRadius.circular(16)),
        child:Stack(children:[
          Positioned(top:-19,right:-17,child:Transform.rotate(
            angle:-0.65,child:Container(width:53,height:42,
              decoration:BoxDecoration(color:accent,
                borderRadius:BorderRadius.circular(15))))),
          Padding(
            padding:EdgeInsets.fromLTRB(narrow?5:7,8,narrow?4:6,6),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Container(width:32,height:32,
                decoration:BoxDecoration(
                  color:metric.tint.withValues(alpha:.09),
                  borderRadius:BorderRadius.circular(11)),
                child:Icon(metric.icon,color:metric.tint,size:iconSize)),
              const SizedBox(height:5),
              FittedBox(fit:BoxFit.scaleDown,
                alignment:Alignment.centerLeft,
                child:Text(metric.count==null?'—':metric.count.toString(),
                  key:ValueKey('owner-monthly-value-'+metric.id),
                  maxLines:1,style:const TextStyle(
                    color:Color(0xFF10152D),fontSize:24,
                    fontWeight:FontWeight.w800,height:1))),
              const SizedBox(height:3),
              Text(metric.label,maxLines:2,overflow:TextOverflow.ellipsis,
                style:TextStyle(color:const Color(0xFF778096),
                  fontSize:narrow?9:10,fontWeight:FontWeight.w600,height:1.08)),
              if(showChange)...[
                const Spacer(),
                FittedBox(fit:BoxFit.scaleDown,
                  alignment:Alignment.centerLeft,
                  child:Text(change>0?'↑ %${change.abs().toStringAsFixed(0)}':
                    change<0?'↓ %${change.abs().toStringAsFixed(0)}':'– %0',
                    maxLines:1,style:TextStyle(fontSize:9,
                      fontWeight:FontWeight.w700,
                      color:change>0?const Color(0xFF29964B):
                        change<0?const Color(0xFFD84D63):
                        const Color(0xFF778096)))),
              ],
            ]),
          ),
        ]),
      ),
    ));
  }
}
