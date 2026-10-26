import 'dart:io';
import 'dart:convert';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(responseDataCallback:(data)async{
 await File('staging-ui-result.json').writeAsString(jsonEncode(data));
},onScreenshot:(name,bytes,[args])async{
 final directory=Directory('staging-evidence');await directory.create(recursive:true);
 await File('${directory.path}/$name.png').writeAsBytes(bytes);
 return true;
});
