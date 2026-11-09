"""Generate only a test identity; no production signing/Firebase credentials."""
from pathlib import Path
import re
import textwrap
import shutil

p = Path('android/app/build.gradle.kts')
s = p.read_text()
s = s.replace('applicationId = "com.cepqar.app"', 'applicationId = "com.cepqar.app.carwashstaging"')
s = s.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
s += '\n\ndependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }\n'
p.write_text(s)

p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text().replace('android:label="app"', 'android:label="CepQontag STAGING"')
s = s.replace('android:name=".MainActivity"', 'android:name="com.cepqar.app.MainActivity"')
permissions = ['INTERNET', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'CAMERA',
               'RECORD_AUDIO', 'MODIFY_AUDIO_SETTINGS', 'BLUETOOTH_CONNECT',
               'POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED', 'USE_FULL_SCREEN_INTENT',
               'WAKE_LOCK', 'VIBRATE', 'NFC']
s = s.replace('<application', ''.join(f'<uses-permission android:name="android.permission.{x}" />\n' for x in permissions) + '<uses-feature android:name="android.hardware.nfc" android:required="false" />\n<application', 1)
p.write_text(s)

# Reuse the existing Android system-settings bridge without changing its code.
workflow = Path('.github/workflows/pages.yml').read_text()
bridge = re.search(r"cat > android/app/src/main/kotlin/com/cepqar/app/MainActivity.kt <<'EOF'\n(.*?)\n\s+EOF", workflow, re.S)
if not bridge:
    raise SystemExit('Existing Android bridge missing')
Path('android/app/src/main/kotlin/com/cepqar/app/MainActivity.kt').write_text(textwrap.dedent(bridge[1]) + '\n')
for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
    folder = Path(f'android/app/src/main/res/mipmap-{density}')
    folder.mkdir(parents=True, exist_ok=True)
    shutil.copyfile('assets/app_icons/cepqar_icon.png', folder/'ic_launcher.png')
print('STAGING_ANDROID_IDENTITY_READY com.cepqar.app.carwashstaging')
