import importlib.util
import io
from pathlib import Path
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('public_pages', Path(__file__).parents[1]/'public_pages.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

class PagesTests(unittest.TestCase):
    def test_overlay_preserves_all_other_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/'site'; panel=Path(tmp)/'panel'; root.mkdir(); panel.mkdir()
            for name in ['index.html','isletme/index.html','owner/index.html','admin/index.html']:
                p=root/name;p.parent.mkdir(exist_ok=True);p.write_text('production '+name)
            (panel/'index.html').write_text('staging');(panel/'main.dart.js').write_text('stage app')
            before=m.inventory(root);m.overlay(root,panel)
            self.assertEqual(before,m.inventory(root));self.assertEqual((root/'isletme-staging/index.html').read_text(),'staging')
    def test_unsafe_tar_cannot_escape_or_link_to_production(self):
        for name,kind in [('../production',tarfile.REGTYPE),('/production',tarfile.REGTYPE),('link',tarfile.SYMTYPE),('link',tarfile.LNKTYPE)]:
            with tempfile.TemporaryDirectory() as tmp:
                archive=Path(tmp)/'payload.tar'
                with tarfile.open(archive,'w') as tar:
                    item=tarfile.TarInfo(name);item.type=kind;item.linkname='/etc/nginx/nginx.conf';tar.addfile(item,io.BytesIO())
                with self.assertRaisesRegex(RuntimeError,'UNSAFE_PAGES_ARCHIVE_MEMBER'):
                    m.unpack_tar(archive,Path(tmp)/'out')
    def test_incomplete_panel_is_not_overlaid(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)/'site';panel=Path(tmp)/'panel';root.mkdir();panel.mkdir();(root/'index.html').write_text('prod')
            with self.assertRaisesRegex(RuntimeError,'STAGING_PANEL_PAYLOAD_INCOMPLETE'):m.overlay(root,panel)
            self.assertEqual((root/'index.html').read_text(),'prod')

if __name__=='__main__':unittest.main()
