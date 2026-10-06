import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_ui_config.dart';

typedef OwnerHomeComponentBuilder=Widget Function(AppUiComponent component);

class OwnerHomeComponentRegistry{
  OwnerHomeComponentRegistry(Map<String,OwnerHomeComponentBuilder> builders):_builders=Map.unmodifiable(builders);
  final Map<String,OwnerHomeComponentBuilder> _builders;

  Widget? build(AppUiComponent component){
    final builder=_builders[component.type];
    if(builder==null){
      debugPrint('Server-driven UI skipped unknown component: ${component.type}');
      return null;
    }
    try{return builder(component);}
    catch(e,st){
      debugPrint('Server-driven UI component failed ${component.id}/${component.type}: $e\n$st');
      return null;
    }
  }
}
