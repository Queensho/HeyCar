from pathlib import Path
import subprocess
import tempfile
import unittest

class RunnerTests(unittest.TestCase):
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
