"""Regression tests: Android runtime patch supports the new five-tab UI.

No Flutter app or backend files are mutated; fixtures run in temporary dirs.
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT=Path(__file__).resolve().parents[1]/'fix_runtime_android.py'


class RuntimePatchTest(unittest.TestCase):
    def apply(self, notifications):
        with tempfile.TemporaryDirectory() as d:
            directory=Path(d)/'lib'
            directory.mkdir()
            (directory/'owner_notifications_page.dart').write_text(notifications)
            (directory/'push_notifications.dart').write_text(
                "icon:'@mipmap/ic_launcher',largeIcon:const DrawableResourceAndroidBitmap('@mipmap/ic_launcher')"
            )
            result=subprocess.run(
                [sys.executable,str(SCRIPT)],cwd=d,capture_output=True,text=True,
                check=False,
            )
            return result, (directory/'owner_notifications_page.dart').read_text(), (
                directory/'push_notifications.dart').read_text()

    def test_new_reference_scaffold_is_accepted_without_alteration(self):
        source=(
            "Widget build(BuildContext c){return Scaffold("
            "backgroundColor:OwnerReference.background,body:SafeArea("
            "bottom:false,child:RefreshIndicator(onRefresh:_load)));}\n"
            "Widget _card(Map<String,dynamic> n){return "
            "Material(color:Colors.transparent,child:InkWell());}\n"
        )
        result,notifications,push=self.apply(source)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(notifications,source)
        self.assertIn("icon:'ic_stat_cepqar'",push)

    def test_legacy_material_patch_still_works(self):
        source="return ColoredBox(color:_bg,child:SafeArea(bottom:false,child:RefreshIndicator("
        result,notifications,_=self.apply(source)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn("return Scaffold(backgroundColor:_bg,body:SafeArea(",notifications)

    def test_unrecognized_page_fails_closed(self):
        result,_,_=self.apply("Widget build(BuildContext c)=>const Placeholder();")
        self.assertNotEqual(result.returncode,0)
        self.assertIn("owner notifications root pattern not found",result.stderr)


if __name__=='__main__':
    unittest.main()
