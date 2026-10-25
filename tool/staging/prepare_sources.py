"""Prepare an isolated build checkout, never production artifacts or source refs."""
import re
from pathlib import Path

PRODUCTION_API = 'https://heycar-api-185-165-46-213.nip.io'

def prepare(root):
    for path in (root / 'lib').rglob('*.dart'):
        if path.name == 'app_environment.dart':
            continue
        source = path.read_text()
        if PRODUCTION_API not in source:
            continue
        # Covers constants and URLs with a path. Interpolation is supported in
        # both const Dart strings and ordinary HTTP request strings.
        source = source.replace(PRODUCTION_API, '${AppEnvironment.apiBase}')
        relative = '../' * (len(path.relative_to(root / 'lib').parts) - 1) + 'app_environment.dart'
        source = "import '" + relative + "';\n" + source
        path.write_text(source)
    android = root / 'android/app/build.gradle.kts'
    text = android.read_text()
    text = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.cepqar.app.staging"', text)
    if 'applicationId = "com.cepqar.app.staging"' not in text:
        raise RuntimeError('STAGING_APPLICATION_ID_NOT_SET')
    if 'isCoreLibraryDesugaringEnabled = true' not in text:
        text = text.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
    if 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:' not in text:
        text += '\ndependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }\n'
    android.write_text(text)
    manifest = root / 'android/app/src/main/AndroidManifest.xml'
    text = manifest.read_text()
    text = re.sub(r'android:label="[^"]+"', 'android:label="CepQontag STAGING"', text)
    # Loopback-only SSH transport is used by the emulator test artifact. Public
    # staging builds still require HTTPS in AppEnvironment.validate().
    text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET" /><uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" /><uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" /><application', 1)
    text = text.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
    text = text.replace('</application>', '<meta-data android:name="firebase_messaging_auto_init_enabled" android:value="false" /><meta-data android:name="firebase_analytics_collection_enabled" android:value="false" /><meta-data android:name="firebase_crashlytics_collection_enabled" android:value="false" /></application>')
    manifest.write_text(text)
    # Do not restore any production Firebase configuration in staging builds.
    for candidate in root.glob('android/**/google-services.json'):
        candidate.unlink()
    print('STAGING_SOURCE_AND_PACKAGE_ISOLATION_OK')

if __name__ == '__main__':
    prepare(Path('.'))
