"""Generate only a test identity; no production signing/Firebase credentials."""
from pathlib import Path
import re
import textwrap
import shutil
import argparse
import json

parser=argparse.ArgumentParser()
parser.add_argument("--qa-fcm",action="store_true")
args=parser.parse_args()
if args.qa_fcm:
    config=json.loads(Path("config/firebase/staging/google-services.json").read_text())
    assert config["project_info"]["project_id"]=="cepqontag-staging"
    assert config["project_info"]["project_number"]=="603919772851"
    assert [c["client_info"]["android_client_info"]["package_name"] for c in config["client"]]==["com.cepqar.app.carwashstaging"]
    assert not any(k in config for k in ["private_key","client_email","type"])

p = Path('android/app/build.gradle.kts')
s = p.read_text()
if args.qa_fcm:
    s=s.replace('plugins {','plugins {\n    id("com.google.gms.google-services") version "4.4.4"',1)
    s=s.replace('android {','android {\n    flavorDimensions += "environment"\n    productFlavors { create("staging") { dimension = "environment"; applicationId = "com.cepqar.app.carwashstaging" } }',1)
    folder=Path('android/app/src/staging');folder.mkdir(parents=True,exist_ok=True)
    shutil.copyfile('config/firebase/staging/google-services.json',folder/'google-services.json')
    (folder/'AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><meta-data android:name="firebase_messaging_auto_init_enabled" android:value="false"/><meta-data android:name="firebase_analytics_collection_enabled" android:value="false"/></application></manifest>')
else:
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
