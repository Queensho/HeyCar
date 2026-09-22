import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class CrashReporting {
  static bool _ready=false;
  static String _pendingRole='unknown';

  static Future<void> init() async {
    if(_ready)return;
    if(Firebase.apps.isEmpty)await Firebase.initializeApp();
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    FlutterError.onError=(details){
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError=(error,stack){
      FirebaseCrashlytics.instance.recordError(error,stack,fatal:true);
      return true;
    };

    await FirebaseCrashlytics.instance.setCustomKey('app','Cepqar');
    await FirebaseCrashlytics.instance.setCustomKey('channel',kReleaseMode?'release':kProfileMode?'profile':'debug');
    await FirebaseCrashlytics.instance.setCustomKey('role',_pendingRole);
    _ready=true;
  }

  static Future<void> setContext({required String role}) async {
    _pendingRole=role;
    if(!_ready)return;
    await FirebaseCrashlytics.instance.setCustomKey('role',role);
  }

  static Future<void> record(Object error,StackTrace stack,{bool fatal=false,String? reason}) async {
    if(!_ready)return;
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      fatal:fatal,
      reason:reason,
    );
  }

  static Future<void> log(String message) async {
    if(!_ready)return;
    await FirebaseCrashlytics.instance.log(message);
  }
}
