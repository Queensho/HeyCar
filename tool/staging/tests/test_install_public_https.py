import contextlib
import importlib.util
import io
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).parents[1] / 'install_public_https.py'
spec = importlib.util.spec_from_file_location('staging_installer', SOURCE)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class InstallerTests(unittest.TestCase):
    def test_non_root_exits_before_any_network_or_mutation(self):
        with patch.object(m.os, 'geteuid', return_value=1000), patch.object(m, 'request') as net:
            with self.assertRaisesRegex(RuntimeError, 'ROOT_REQUIRED'):
                m.main()
            net.assert_not_called()

    def test_only_staging_host_and_upstream_are_rendered(self):
        http, tls = m.render(False), m.render(True)
        self.assertNotIn('listen 443', http)
        self.assertIn('try_files $uri =404', http)
        self.assertIn('proxy_pass http://127.0.0.1:8091;', tls)
        self.assertNotIn('8090', tls)
        self.assertNotIn('default_server', tls)
        self.assertNotIn('heycar-api-', tls)
        self.assertIn(str(m.ACME) + '/live/' + m.HOST, tls)

    def test_atomic_write_refuses_a_symlink(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = Path(tmp) / 'production'
            original.write_text('original')
            link = Path(tmp) / 'staging'
            link.symlink_to(original)
            with self.assertRaisesRegex(RuntimeError, 'REFUSE_SYMLINK'):
                m.atomic(link, 'changed')
            self.assertEqual(original.read_text(), 'original')

    def test_snapshot_excludes_only_owned_staging_and_detects_other_edits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            prod, stage = root / 'production', root / 'staging'
            prod.write_text('original'); stage.write_text('stage')
            before = m.snapshot(root, [stage])
            stage.write_text('new stage')
            self.assertEqual(before, m.snapshot(root, [stage]))
            prod.write_text('changed')
            self.assertNotEqual(before, m.snapshot(root, [stage]))

    def test_certbot_never_uses_nginx_plugin_or_global_cert_store(self):
        with patch.object(m, 'run') as run:
            m.certificate()
            args = run.call_args_list[0].args
            self.assertIn('--webroot', args)
            self.assertIn('--no-directory-hooks', args)
            self.assertIn('--keep-until-expiring', args)
            self.assertNotIn('--nginx', args)
            self.assertNotIn('--standalone', args)
            self.assertEqual(args[args.index('--domain') + 1], m.HOST)
            self.assertEqual(args[args.index('--config-dir') + 1], str(m.ACME))

    def test_reload_requires_a_passing_nginx_test(self):
        with patch.object(m, 'run', side_effect=RuntimeError('bad nginx')) as run:
            with self.assertRaisesRegex(RuntimeError, 'bad nginx'):
                m.reload_nginx()
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args, ('/usr/sbin/nginx', '-t'))

    def test_tls_requests_do_not_disable_certificate_trust(self):
        with patch.object(m.urllib.request, 'urlopen') as open_url:
            m.request('https://' + m.HOST + '/api/environment')
            self.assertNotIn('context', open_url.call_args.kwargs)

    def test_failed_certificate_rolls_back_only_staging_files(self):
        # Entire transaction is confined to a temporary tree. No real sudo,
        # nginx, certbot, network call or /etc mutation is made by this test.
        with tempfile.TemporaryDirectory() as tmp, contextlib.ExitStack() as stack:
            root = Path(tmp)
            paths = {'SITE': root/'nginx/available/staging', 'LINK': root/'nginx/enabled/staging',
                     'NGINX_ROOT': root/'nginx', 'PRODUCTION_CERTS': root/'prod-certs',
                     'STATE': root/'state', 'WEBROOT': root/'webroot', 'ACME': root/'acme',
                     'HELPER': root/'bin/helper', 'SERVICE': root/'systemd/renew.service',
                     'TIMER': root/'systemd/renew.timer'}
            for name, value in paths.items():
                stack.enter_context(patch.object(m, name, value))
                value.parent.mkdir(parents=True, exist_ok=True)
            prod = paths['NGINX_ROOT']/'production.conf'
            prod.write_text('untouched production')
            before = m.MARKER + 'old staging config'
            paths['SITE'].write_text(before)
            paths['LINK'].symlink_to(paths['SITE'])
            stack.enter_context(patch.object(m.os, 'geteuid', return_value=0))
            stack.enter_context(patch.object(m, 'trusted_directory'))
            stack.enter_context(patch.object(m, 'safe_existing'))
            stack.enter_context(patch.object(m.signal, 'signal'))
            stack.enter_context(patch.object(m.os, 'umask'))
            stack.enter_context(patch.object(sys, 'argv', ['installer']))
            real_is_file = Path.is_file
            binaries = {'/usr/sbin/nginx', '/usr/bin/systemctl', '/usr/bin/certbot', '/usr/bin/openssl'}
            stack.enter_context(patch.object(Path, 'is_file', lambda p: True if str(p) in binaries else real_is_file(p)))
            stack.enter_context(patch.object(m.socket, 'getaddrinfo', return_value=[(0,0,0,'',(m.IP,80))]))
            stack.enter_context(patch.object(m, 'identity'))
            def response(url, *args, **kwargs):
                value = m.IP if url.endswith('ipify.org') else url.rsplit('cepqontag-preflight-',1)[-1]
                return io.BytesIO(value.encode())
            stack.enter_context(patch.object(m, 'request', side_effect=response))
            stack.enter_context(patch.object(m, 'run', return_value=''))
            stack.enter_context(patch.object(m.subprocess, 'run', return_value=subprocess.CompletedProcess([],1)))
            reload = stack.enter_context(patch.object(m, 'reload_nginx'))
            stack.enter_context(patch.object(m, 'certificate', side_effect=RuntimeError('ACME_FAILED')))
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaisesRegex(RuntimeError, 'ACME_FAILED'):
                m.main()
            self.assertEqual(paths['SITE'].read_text(), before)
            self.assertEqual(paths['LINK'].resolve(), paths['SITE'])
            self.assertEqual(prod.read_text(), 'untouched production')
            self.assertFalse(paths['HELPER'].exists())
            self.assertFalse(paths['SERVICE'].exists())
            self.assertEqual(reload.call_count, 2)  # bootstrap, then restored original


if __name__ == '__main__':
    unittest.main()
