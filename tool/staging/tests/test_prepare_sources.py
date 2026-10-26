import importlib.util
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

spec=importlib.util.spec_from_file_location('prepare_sources',Path(__file__).parents[1]/'prepare_sources.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class PrepareTests(unittest.TestCase):
    def test_public_and_tunnel_builds_are_distinct_without_production_files(self):
        for https_only in [False,True]:
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp);(root/'lib').mkdir();(root/'android/app/src/main').mkdir(parents=True)
                (root/'lib/api.dart').write_text("const base='"+m.PRODUCTION_API+"';")
                (root/'android/app/build.gradle.kts').write_text('android { defaultConfig { applicationId = "com.cepqar.app" }; compileOptions {} }')
                (root/'android/app/src/main/AndroidManifest.xml').write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="app"></application></manifest>')
                (root/'android/app/google-services.json').write_text('{"fake":"production-config-sentinel"}')
                m.prepare(root,https_only=https_only)
                manifest=ET.parse(root/'android/app/src/main/AndroidManifest.xml').getroot();app=manifest.find('application')
                prefix='{http://schemas.android.com/apk/res/android}'
                self.assertEqual(app.attrib[prefix+'usesCleartextTraffic'],'false' if https_only else 'true')
                self.assertEqual(app.attrib[prefix+'label'],'CepQontag STAGING')
                self.assertIn('com.cepqar.app.staging',(root/'android/app/build.gradle.kts').read_text())
                self.assertFalse((root/'android/app/google-services.json').exists())
                self.assertNotIn(m.PRODUCTION_API,(root/'lib/api.dart').read_text())
                self.assertIn('AppEnvironment.apiBase',(root/'lib/api.dart').read_text())
                flags={x.attrib[prefix+'name']:x.attrib[prefix+'value'] for x in app.findall('meta-data')}
                self.assertEqual(flags['firebase_messaging_auto_init_enabled'],'false')
                self.assertEqual(flags['firebase_analytics_collection_enabled'],'false')

if __name__=='__main__':unittest.main()
