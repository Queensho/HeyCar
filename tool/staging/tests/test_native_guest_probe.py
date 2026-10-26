import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('native_guest_probe', Path(__file__).parents[1]/'native_guest_probe.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class NativeGuestTests(unittest.TestCase):
    def test_click_targets_smallest_staging_login_node_and_ignores_production(self):
        xml = '''<hierarchy>
        <node package="com.cepqar.app" text="Giriş Yap" bounds="[0,0][20,20]" />
        <node package="com.cepqar.app.staging" content-desc="Giriş Yap Kayıt Ol" bounds="[0,0][1080,1920]">
          <node package="com.cepqar.app.staging" content-desc="Giriş Yap" bounds="[70,1490][1010,1610]" />
        </node></hierarchy>'''
        self.assertEqual(probe.login_bounds(xml), (70,1490,1010,1610))
        with self.assertRaisesRegex(RuntimeError, 'NOT_ACCESSIBLE'):
            probe.login_bounds('<hierarchy><node package="com.cepqar.app" text="Giriş Yap" bounds="[1,2][30,40]" /></hierarchy>')

    def test_actual_login_fields_and_staging_banner_must_belong_to_stage(self):
        xml = '''<hierarchy>
        <node package="com.cepqar.app.staging" text="Telefon Numarası" />
        <node package="com.cepqar.app.staging" content-desc="Şifre" />
        <node package="com.cepqar.app.staging" text="STAGING / TEST ORTAMI" />
        <node package="com.cepqar.app.staging" class="android.widget.EditText" password="false" />
        <node package="com.cepqar.app.staging" class="android.widget.EditText" password="true" />
        </hierarchy>'''
        self.assertTrue(probe.login_form_visible(xml))
        self.assertFalse(probe.login_form_visible(xml.replace('com.cepqar.app.staging', 'com.cepqar.app')))
        self.assertFalse(probe.login_form_visible(xml.replace('password="true"', 'password="false"')))

    def test_turkish_accessibility_case_and_whitespace_are_normalized(self):
        self.assertEqual(probe.normalized('STAGİNG / TEST\nORTAMI'), 'staging / test ortami')
        self.assertEqual(probe.normalized('Telefon Numarası'), 'telefon numarasi')

    def test_static_login_labels_without_editable_fields_are_not_a_form(self):
        xml='<hierarchy><node package="com.cepqar.app.staging" text="Telefon Numarası Şifre STAGING / TEST ORTAMI" /></hierarchy>'
        self.assertFalse(probe.login_form_visible(xml))


if __name__ == '__main__':
    unittest.main()
