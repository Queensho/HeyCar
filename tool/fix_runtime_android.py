from pathlib import Path

# Fix the notifications page: InkWell/InkResponse requires a Material ancestor.
p = Path('lib/owner_notifications_page.dart')
s = p.read_text()
old = "return ColoredBox(color:_bg,child:SafeArea(bottom:false,child:RefreshIndicator("
new = "return Scaffold(backgroundColor:_bg,body:SafeArea(bottom:false,child:RefreshIndicator("
if old not in s:
    raise SystemExit('owner notifications root pattern not found')
s = s.replace(old, new, 1)
p.write_text(s)

# Android notification small icon must be a drawable. The full-colour Cepqar launcher
# remains the large icon, while this vector is used in the status bar.
p = Path('lib/push_notifications.dart')
s = p.read_text()
s = s.replace("icon:'@mipmap/ic_launcher',largeIcon:const DrawableResourceAndroidBitmap('@mipmap/ic_launcher')", "icon:'ic_stat_cepqar',largeIcon:const DrawableResourceAndroidBitmap('@mipmap/ic_launcher')")
p.write_text(s)

print('RUNTIME_ANDROID_FIX_OK')
