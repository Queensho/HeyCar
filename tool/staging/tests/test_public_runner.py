from pathlib import Path
import json
import os
import subprocess
import tempfile
import unittest

class RunnerTests(unittest.TestCase):
    def test_native_states_are_prebuilt_and_stale_fixture_is_rejected_before_adb(self):
        script=Path(__file__).parents[1]/'run_e2e.sh'
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/'bin').mkdir(); (root/'android').mkdir()
            flutter=root/'bin/flutter'
            flutter.write_text('#!/bin/bash\nset -eu\nmkdir -p build/app/outputs/flutter-apk\nprintf "%s" "$*" > build/app/outputs/flutter-apk/app-debug.apk\n')
            flutter.chmod(0o755)
            gradle=root/'android/gradlew'
            gradle.write_text('#!/bin/bash\ntest "$1" = --stop\nprintf stopped > ../gradle-stopped\n')
            gradle.chmod(0o755)
            (root/'staging-fixture.json').write_text(json.dumps({'campaignId':'test-campaign'}))
            env={**os.environ,'PATH':str(root/'bin')+':'+os.environ['PATH'],
                 'SSH_PORT':'22','SSH_USER':'test','SSH_HOST':'unused.invalid',
                 'GITHUB_SHA':'test-source','GITHUB_RUN_ID':'test-run','STAGING_PUBLIC_API':'https://staging-api-185-165-46-213.nip.io'}
            result=subprocess.run(['bash',str(script.resolve()),'build-android'],cwd=root,env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertTrue((root/'gradle-stopped').exists())
            for state in ('true','false'):
                flags=(root/f'staging-native/{state}.apk').read_text()
                self.assertIn('--dart-define=STAGING_EXPECT_ACTIVE='+state,flags)
                self.assertIn('--dart-define=STAGING_CAMPAIGN_ID=test-campaign',flags)
                self.assertIn('--dart-define=STAGING_SSH_TUNNEL=false',flags)
            context=root/'staging-native/context.json'
            original=json.loads(context.read_text())
            for field in ('campaignId','api','source'):
                with self.subTest(field=field):
                    context.write_text(json.dumps({**original,field:'stale'}))
                    result=subprocess.run(['bash',str(script.resolve()),'mobile'],cwd=root,env=env,capture_output=True,text=True)
                    self.assertNotEqual(result.returncode,0)
                    self.assertIn('STALE_NATIVE_TEST_BINARY',result.stderr)

    def test_android_foreground_check_uses_python_and_accepts_real_dumpsys_variants(self):
        script=(Path(__file__).parents[1]/'run_e2e.sh').read_text()
        command=next(line.strip() for line in script.splitlines() if 'STAGING_APK_NOT_FOREGROUND' in line)
        with tempfile.TemporaryDirectory() as tmp:
            snapshot=Path(tmp)/'activities.txt'
            command=command.replace('/tmp/staging-activities.txt',str(snapshot))
            for prefix in ['mResumedActivity:','topResumedActivity=']:
                snapshot.write_text(prefix+' ActivityRecord{u0 com.cepqar.app.staging/com.cepqar.app.MainActivity}')
                result=subprocess.run(['/bin/bash','-c',command],capture_output=True,text=True)
                self.assertEqual(result.returncode,0,result.stderr)
            snapshot.write_text('mResumedActivity: launcher')
            result=subprocess.run(['/bin/bash','-c',command],capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('STAGING_APK_NOT_FOREGROUND',result.stderr)

if __name__=='__main__':unittest.main()
