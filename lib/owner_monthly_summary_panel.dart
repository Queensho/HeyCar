import 'cepqar_theme.dart';
import 'design/cq_components.dart';
import 'package:flutter/material.dart';
import 'design/cq_motion.dart';
import 'design/cq_layout.dart';

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
        color:Colors.white,borderRadius:BorderRadius.circular(CQLayout.cardRadius),
        border:Border.all(color:const Color(0xFFECECF3)),
        boxShadow:const [
          BoxShadow(color:Color(0x0C101426),blurRadius:17,offset:Offset(0,5)),
        ],
      ),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        CQSectionHeading(
          title:const Text('Bu Ayki Özetim',style:TextStyle(
            color:Color(0xFF101426),fontSize:16,fontWeight:FontWeight.w800)),
          action:TextButton(
            key:const ValueKey('owner-monthly-view-all'),onPressed:onViewAll,
            child:const Text('Tümünü Gör')),
        ),
        const SizedBox(height:12),
        if(isLoading)
          const SizedBox(height:64,child:Center(child:SizedBox(
            width:28,height:28,child:CircularProgressIndicator(
              strokeWidth:2.5,color:CepqarTheme.purple),
          )))
        else if(hasError)
          ConstrainedBox(constraints:const BoxConstraints(minHeight:64),child:Row(
            mainAxisAlignment:MainAxisAlignment.center,children:[
              const Flexible(child:Text('İstatistikler yüklenemedi.',
                style:TextStyle(color:Color(0xFF626C83),fontSize:12))),
              if(onRetry!=null)TextButton(
                onPressed:onRetry,child:const Text('Tekrar dene')),
            ],
          ))
        else if(metrics.isEmpty)
          const Padding(padding:EdgeInsets.symmetric(vertical:16),child:Center(child:Text(
            'Henüz istatistik bulunmuyor.',
            style:TextStyle(color:Color(0xFF626C83),fontSize:12),
          )))
        else LayoutBuilder(builder:(context,box){
          final scaled=MediaQuery.textScalerOf(context).scale(12);
          final columns=scaled>24?1:(box.maxWidth>=320 && scaled<16?4:2);
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
    final side=compact?30.0:34.0;
    return CQPressable(
      key:ValueKey('owner-monthly-'+metric.id),
      onTap:metric.onTap,
      borderRadius:17,
      child:Container(
        constraints:const BoxConstraints(minHeight:88),
        padding:EdgeInsets.symmetric(horizontal:compact?4:10,vertical:6),
        decoration:BoxDecoration(
          color:metric.background,borderRadius:BorderRadius.circular(17),
        ),
        child:Column(
          mainAxisAlignment:MainAxisAlignment.center,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
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
                  fontSize:24,fontWeight:FontWeight.w800,height:1)),
            )),
          ]),
          const SizedBox(height:5),
          Text(metric.label,maxLines:2,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:const Color(0xFF626C83),
              fontSize:compact?10:11,fontWeight:FontWeight.w600,height:1.07)),
          if(showChange)...[
            const SizedBox(height:2),
            Align(alignment:Alignment.centerRight,child:Text(
              change>0?'↑ %'+change.abs().toStringAsFixed(0):
                change<0?'↓ %'+change.abs().toStringAsFixed(0):'– %0',
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:TextStyle(fontSize:compact?8:9,fontWeight:FontWeight.w700,height:1,
                color:change>0?const Color(0xFF29964B):
                  change<0?const Color(0xFFD84D63):
                  const Color(0xFF626C83)),
            )),
          ],
        ]),
      ),
    );
  }
}

