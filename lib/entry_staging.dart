import 'app_environment.dart';
import 'entry_theme_live.dart' as ownerDriver;
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppEnvironment.isStaging) throw StateError('STAGING_BUILD_REQUIRED');
  await AppEnvironment.verifyServer();
  await ownerDriver.main();
}
