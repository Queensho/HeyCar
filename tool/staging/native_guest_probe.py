"""Open the actual downloaded staging APK's guest login via Android accessibility.

Runner/emulator only; never accepts a production package or enters credentials.
The campaign screen integration suite is intentionally separate from this APK probe.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import unicodedata
import xml.etree.ElementTree as ET

PACKAGE = 'com.cepqar.app.staging'


def stage_nodes(xml):
    return [node for node in ET.fromstring(xml).iter('node')
            if node.get('package') == PACKAGE]


def login_bounds(xml):
    candidates = []
    for node in stage_nodes(xml):
        label = ' '.join((node.get('text', ''), node.get('content-desc', '')))
        if 'Giriş Yap' not in label or node.get('enabled') == 'false':
            continue
        values = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
        if values:
            x1, y1, x2, y2 = map(int, values.groups())
            if x2 > x1 and y2 > y1:
                candidates.append(((x2-x1)*(y2-y1), (x1, y1, x2, y2)))
    if not candidates:
        raise RuntimeError('STAGING_APK_LOGIN_BUTTON_NOT_ACCESSIBLE')
    return min(candidates)[1]


def normalized(label):
    # Android accessibility can return dotted-I combining marks and newlines.
    text=unicodedata.normalize('NFKD', label.casefold().replace('ı','i'))
    return ' '.join(''.join(c for c in text if not unicodedata.combining(c)).split())


def login_form_visible(xml):
    nodes=stage_nodes(xml)
    labels=normalized(' '.join(node.get('text', '')+' '+node.get('content-desc', '') for node in nodes))
    fields=[node for node in nodes if node.get('class')=='android.widget.EditText']
    password=any(node.get('password')=='true' for node in fields)
    phone=any(node.get('password')!='true' for node in fields)
    return (len(fields)>=2 and password and phone
            and ('telefon numarasi' in labels or '5xx' in labels)
            and 'staging / test ortami' in labels)


def run(device):
    if not re.fullmatch(r'emulator-\d+', device):
        raise RuntimeError('EMULATOR_ONLY')

    def adb(*args):
        return subprocess.check_output(['adb', '-s', device, *args], timeout=30)

    def snapshot():
        adb('shell', 'uiautomator', 'dump', '/sdcard/cepqontag-staging-ui.xml')
        xml=adb('exec-out', 'cat', '/sdcard/cepqontag-staging-ui.xml').decode()
        evidence=Path('staging-evidence');evidence.mkdir(exist_ok=True)
        views=[]
        for node in stage_nodes(xml):
            view={key:node.get(key,'') for key in ('class','bounds','password','enabled','focusable')}
            editable=view['class']=='android.widget.EditText'
            for key in ('text','content-desc'):
                view[key]='[editable value omitted]' if editable else node.get(key,'')[:300]
            views.append(view)
        (evidence/'downloadable-apk-accessibility.json').write_text(json.dumps({'stageNodes':views},ensure_ascii=False))
        return xml

    deadline = time.monotonic()+45
    while True:
        try:
            bounds = login_bounds(snapshot())
            break
        except (RuntimeError, ET.ParseError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(1)
    x1, y1, x2, y2 = bounds
    adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
    print('STAGING_APK_GUEST_LOGIN_BUTTON_TAPPED', flush=True)
    deadline = time.monotonic()+30
    while not login_form_visible(snapshot()):
        if time.monotonic() >= deadline:
            raise RuntimeError('STAGING_APK_LOGIN_FORM_NOT_VISIBLE')
        time.sleep(1)
    evidence = Path('staging-evidence')
    evidence.mkdir(exist_ok=True)
    (evidence/'downloadable-https-apk-login.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    (evidence/'downloadable-apk-login.json').write_text(json.dumps({
        'package': PACKAGE, 'automation': 'Android UI Automator',
        'guestLoginOpened': True, 'stagingBannerVerified': True,
        'credentialsEntered': False,
    }))
    print('DOWNLOADED_STAGING_APK_GUEST_LOGIN_UI_PASSED')


if __name__ == '__main__':
    try:
        run(sys.argv[1])
    except Exception:
        # Empty guest form only; no credentials are entered by this probe.
        # Capture the last screen and Android native crash buffer when reachable.
        evidence = Path('staging-evidence')
        evidence.mkdir(exist_ok=True)
        for name, args in (
            ('downloadable-apk-login-failure.png', ['exec-out', 'screencap', '-p']),
            ('downloadable-apk-native-crash.txt', ['logcat', '-d', '-b', 'crash']),
        ):
            try:
                data=subprocess.check_output(['adb','-s',sys.argv[1],*args],timeout=5)
                (evidence/name).write_bytes(data)
            except (OSError, subprocess.SubprocessError):
                pass
        raise

