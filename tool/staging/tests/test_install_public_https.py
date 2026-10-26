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
            self.assertEqual(args[args.index('--work-dir') + 1], str(m.ACME_WORK))
            self.assertEqual(args[args.index('--logs-dir') + 1], str(m.ACME_LOG))
            self.assertEqual(args[args.index('--server') + 1], 'https://acme-v02.api.letsencrypt.org/directory')

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
        self.assert_failed_transaction(False)

    def test_rollback_refuses_reload_after_external_production_edit(self):
        self.assert_failed_transaction(True)

    def test_unchanged_valid_certificate_and_config_do_not_reload_nginx(self):
        self.assert_failed_transaction(False, unchanged=True)

    def assert_failed_transaction(self, concurrent, unchanged=False):
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
            before = m.render(True) if unchanged else m.MARKER + 'old staging config'
            if unchanged:
                chain = paths['ACME']/'live'/m.HOST/'fullchain.pem'
                chain.parent.mkdir(parents=True)
                chain.write_bytes(b'unchanged-cert')
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
            stack.enter_context(patch.object(m, 'inspect_machine', return_value='panel-hash'))
            def response(url, *args, **kwargs):
                value = m.IP if url.endswith('ipify.org') else url.rsplit('cepqontag-preflight-',1)[-1]
                return io.BytesIO(value.encode())
            stack.enter_context(patch.object(m, 'request', side_effect=response))
            commands = stack.enter_context(patch.object(m, 'run', return_value=''))
            stack.enter_context(patch.object(m.subprocess, 'run', return_value=subprocess.CompletedProcess([],1)))
            def failed_acme():
                if concurrent:
                    prod.write_text('external production edit')
                raise RuntimeError('ACME_FAILED')
            stack.enter_context(patch.object(m, 'certificate', side_effect=(lambda: None) if unchanged else failed_acme))
            stack.enter_context(patch.object(m, 'verify_https'))
            stack.enter_context(patch.object(m, 'production_readonly'))
            expected = 'STAGING_ROLLBACK_RELOAD_BLOCKED' if concurrent else 'ACME_FAILED'
            if unchanged:
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    m.main()
                self.assertIn('"nginxReloads": 0', output.getvalue())
            else:
                with contextlib.redirect_stderr(io.StringIO()), self.assertRaisesRegex(RuntimeError, expected):
                    m.main()
            self.assertEqual(paths['SITE'].read_text(), before)
            self.assertEqual(paths['LINK'].resolve(), paths['SITE'])
            self.assertEqual(prod.read_text(), 'external production edit' if concurrent else 'untouched production')
            self.assertEqual(paths['HELPER'].exists(), unchanged)
            self.assertEqual(paths['SERVICE'].exists(), unchanged)
            reloads = [call for call in commands.call_args_list if call.args == ('/usr/bin/systemctl', 'reload', 'nginx')]
            self.assertEqual(len(reloads), 0 if unchanged else (1 if concurrent else 2))


    def test_check_mode_has_no_mutations(self):
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(m.os, 'geteuid', return_value=0))
            stack.enter_context(patch.object(m.signal, 'signal'))
            stack.enter_context(patch.object(m.os, 'umask'))
            stack.enter_context(patch.object(sys, 'argv', ['installer', '--check']))
            stack.enter_context(patch.object(m, 'inspect_machine', return_value='panel-hash'))
            stack.enter_context(patch.object(m, 'inspect_config', return_value={}))
            mkdir = stack.enter_context(patch.object(Path, 'mkdir'))
            atomic = stack.enter_context(patch.object(m, 'atomic'))
            reload = stack.enter_context(patch.object(m, 'reload_nginx'))
            cert = stack.enter_context(patch.object(m, 'certificate'))
            with contextlib.redirect_stdout(io.StringIO()) as output:
                m.main()
            self.assertIn('"readOnly": true', output.getvalue())
            for mutation in [mkdir, atomic, reload, cert]:
                mutation.assert_not_called()

    def test_concurrent_production_config_change_blocks_reload(self):
        with patch.object(m, 'run') as run, patch.object(m, 'production_config_snapshot', return_value={'prod': 'changed'}):
            with self.assertRaisesRegex(RuntimeError, 'UNRELATED_NGINX_CHANGED_RELOAD_REFUSED'):
                m.reload_nginx({'prod': 'original'})
            self.assertEqual(run.call_args_list[0].args, ('/usr/sbin/nginx', '-t'))
            self.assertEqual(run.call_count, 1)

    def test_external_nginx_include_change_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)/'nginx'; root.mkdir()
            external = Path(tmp)/'ssl-options.conf'; external.write_text('ssl_session_timeout 1d;')
            dump = '# configuration file ' + str(external) + ':\n' + external.read_text()
            with patch.object(m, 'NGINX_ROOT', root), patch.object(m, 'EXTRA_CONFIGS', set()), patch.object(m, 'run', return_value=dump):
                before = m.inspect_config()
                external.write_text('ssl_session_timeout 2d;')
                with self.assertRaisesRegex(RuntimeError, 'UNRELATED_NGINX_CHANGED'):
                    m.require_unchanged(before)

    def test_existing_webroot_permissions_are_never_relaxed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)/'webroot'; root.mkdir(mode=0o700)
            with patch.object(m, 'WEBROOT', root), patch.object(m, 'trusted_directory'), patch.object(m.os, 'chmod') as chmod:
                with self.assertRaisesRegex(RuntimeError, 'EXISTING_WEBROOT_NOT_PUBLICLY_TRAVERSABLE'):
                    m.ensure_webroot()
                chmod.assert_not_called()
            self.assertEqual(root.stat().st_mode & 0o777, 0o700)

    def test_production_panel_change_is_detected_without_writes(self):
        def response(url):
            result = io.BytesIO(b'{"ok":true}' if url == m.PRODUCTION_API else b'changed panel')
            result.status = 200
            result.geturl = lambda: url
            return result
        with patch.object(m, 'request', side_effect=response):
            with self.assertRaisesRegex(RuntimeError, 'PRODUCTION_PANEL_CONTENT_CHANGED'):
                m.production_readonly('original-hash')

    def test_identity_rejects_production_database_and_non_object_payload(self):
        for data in [b'{"environment":"production","database":"heycar"}', b'[]']:
            with patch.object(m, 'request', return_value=io.BytesIO(data)):
                with self.assertRaisesRegex(RuntimeError, 'STAGING_IDENTITY_MISMATCH'):
                    m.identity('http://127.0.0.1:8091/api/environment')

    def test_stored_certbot_hooks_are_rejected(self):
        import os
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root/'renewal').mkdir()
            (root/'renewal'/(m.HOST+'.conf')).write_text('deploy_hook = /some/production-hook')
            real_stat = Path.stat
            def root_stat(path, *args, **kwargs):
                values = list(real_stat(path, *args, **kwargs)); values[4] = 0
                return os.stat_result(values)
            with patch.object(m, 'ACME', root), patch.object(Path, 'stat', root_stat):
                with self.assertRaisesRegex(RuntimeError, 'ACME_STORED_HOOK_FORBIDDEN'):
                    m.inspect_acme()

    def test_writable_parent_is_rejected(self):
        import os
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            real_stat = Path.stat
            def root_stat(path, *args, **kwargs):
                values = list(real_stat(path, *args, **kwargs)); values[4] = 0
                return os.stat_result(values)
            with patch.object(Path, 'stat', root_stat):
                with self.assertRaisesRegex(RuntimeError, 'REFUSE_UNTRUSTED_DIRECTORY: /tmp'):
                    m.trusted_directory(root)



    def test_default_tls_fingerprint_is_inspected_without_sni(self):
        import hashlib
        import ssl
        der = b'public-certificate-bytes'
        with patch.object(m, 'run', return_value=ssl.DER_cert_to_PEM_cert(der)) as run:
            self.assertEqual(m.default_tls_fingerprint(), hashlib.sha256(der).hexdigest())
            self.assertIn('-noservername', run.call_args.args)
            self.assertIn(m.IP + ':443', run.call_args.args)

    def test_changing_implicit_default_certificate_is_rejected(self):
        import hashlib
        def response(url):
            result = io.BytesIO(b'{"ok":true}' if url == m.PRODUCTION_API else b'panel')
            result.status = 200; result.geturl = lambda: url
            return result
        baseline = {'panelSha256': hashlib.sha256(b'panel').hexdigest(), 'defaultTlsSha256': 'old-cert'}
        with patch.object(m, 'request', side_effect=response), patch.object(m, 'default_tls_fingerprint', return_value='new-cert'):
            with self.assertRaisesRegex(RuntimeError, 'PRODUCTION_DEFAULT_TLS_CERTIFICATE_CHANGED'):
                m.production_readonly(baseline)
        self.assertEqual(m.LINK.name, 'zz-cepqontag-staging.conf')

    def test_pages_origin_alone_is_not_sufficient_for_jwt_cors(self):
        response = io.BytesIO()
        response.status = 204
        response.headers = {'Access-Control-Allow-Origin': 'https://queensho.github.io', 'Access-Control-Allow-Methods': 'POST'}
        with patch.object(m, 'identity'), patch.object(m, 'request', return_value=response):
            with self.assertRaisesRegex(RuntimeError, 'STAGING_CORS_JWT_HEADERS_OR_METHOD_MISSING'):
                m.verify_https()



    def test_external_production_certificate_change_blocks_reload(self):
        with tempfile.TemporaryDirectory() as tmp:
            cert = Path(tmp)/'production-fullchain.pem'
            cert.write_bytes(b'externally changed cert')
            with patch.object(m, 'run') as run:
                with self.assertRaisesRegex(RuntimeError, 'PRODUCTION_PUBLIC_CERTIFICATE_CHANGED_RELOAD_REFUSED'):
                    m.reload_nginx(certificates={str(cert): 'previous-hash'})
                self.assertEqual(run.call_args_list[0].args, ('/usr/sbin/nginx', '-t'))
                self.assertEqual(run.call_count, 1)


if __name__ == '__main__':
    unittest.main()
