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

/// Single white card, four columns when legible; 2x2 on narrow screens.
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
      padding:const EdgeInsets.fromLTRB(13,13,13,14),
      decoration:BoxDecoration(
        color:Colors.white,borderRadius:BorderRadius.circular(24),
        border:Border.all(color:const Color(0xFFECECF3)),
        boxShadow:const [
          BoxShadow(color:Color(0x0C101426),blurRadius:17,offset:Offset(0,5)),
        ],
      ),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Row(children:[
          const Icon(Icons.bar_chart_rounded,color:Color(0xFF651FFF),size:24),
          const SizedBox(width:7),
          const Expanded(child:Text('Bu Ayki Özetim',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:Color(0xFF101426),fontSize:16,
              fontWeight:FontWeight.w800))),
          InkWell(
            key:const ValueKey('owner-monthly-view-all'),onTap:onViewAll,
            borderRadius:BorderRadius.circular(10),
            child:const Padding(padding:EdgeInsets.symmetric(vertical:7,horizontal:2),
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                Text('Tümünü Gör',style:TextStyle(color:Color(0xFF651FFF),
                  fontSize:11,fontWeight:FontWeight.w700)),
                Icon(Icons.chevron_right_rounded,color:Color(0xFF651FFF),size:19),
              ]),
            ),
          ),
        ]),
        const SizedBox(height:9),
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
          final columns=box.maxWidth>=350?4:2;
          const gap=7.0;
          final count=metrics.length>4?4:metrics.length;
          return Column(children:[
            for(var start=0;start<count;start+=columns)...[
              if(start>0)const SizedBox(height:7),
              Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                for(var i=start;i<start+columns;i++)...[
                  if(i>start)const SizedBox(width:gap),
                  Expanded(child:i<count
                    ?_MonthlyMetricTile(metric:metrics[i],compact:columns==4)
                    :const SizedBox.shrink()),
                ],
              ]),
            ],
          ]);
        }),
      ]),
    );
  }
}

class _MonthlyMetricTile extends StatelessWidget{
  const _MonthlyMetricTile({required this.metric,required this.compact});
  final OwnerMonthlyMetric metric;
  final bool compact;

  @override
  Widget build(BuildContext context){
    final change=metric.changePercent;
    final showChange=change!=null&&change.isFinite;
    final side=compact?29.0:37.0;
    return Material(color:Colors.transparent,child:InkWell(
      key:ValueKey('owner-monthly-'+metric.id),
      onTap:metric.onTap,
      borderRadius:BorderRadius.circular(17),
      child:Container(
        height:showChange?111:(compact?91:87),
        padding:EdgeInsets.fromLTRB(compact?5:10,9,compact?5:10,7),
        decoration:BoxDecoration(
          color:metric.background,borderRadius:BorderRadius.circular(17),
        ),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(
              height:side,width:side,
              decoration:BoxDecoration(
                color:Colors.white.withValues(alpha:.69),
                borderRadius:BorderRadius.circular(compact?10:12),
              ),
              child:Icon(metric.icon,color:metric.tint,size:compact?20:23),
            ),
            const SizedBox(width:4),
            Expanded(child:FittedBox(
              fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
              child:Text(metric.count==null?'—':metric.count.toString(),
                key:ValueKey('owner-monthly-value-'+metric.id),
                maxLines:1,style:TextStyle(color:const Color(0xFF101426),
                  fontSize:compact?23:26,fontWeight:FontWeight.w800,height:1)),
            )),
          ]),
          const SizedBox(height:8),
          Text(metric.label,maxLines:2,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:const Color(0xFF737B94),
              fontSize:compact?10:11.5,fontWeight:FontWeight.w600,height:1.05)),
          if(showChange)...[
            const Spacer(),
            Align(alignment:Alignment.centerRight,child:Text(
              change>0?'↑ %'+change.abs().toStringAsFixed(0):
                change<0?'↓ %'+change.abs().toStringAsFixed(0):'– %0',
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:TextStyle(fontSize:compact?9:10,fontWeight:FontWeight.w700,
                color:change>0?const Color(0xFF29964B):
                  change<0?const Color(0xFFD84D63):
                  const Color(0xFF737B94)),
            )),
          ],
        ]),
      ),
    ));
  }
}
