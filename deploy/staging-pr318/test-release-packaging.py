#!/usr/bin/env python3
"""Exercise actual pinned archive packaging and npm tests, without a VPS or DB.
Uses the checkout's installed Node dependencies. Never runs a deploy shell script.
"""
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('staging_deploy', Path(__file__).with_name('deploy-staging-pr318.py'))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


def counts(text):
    return {key: int(value) for key, value in re.findall(r'(?m)^(?:# |ℹ )(tests|pass|fail|skipped) (\d+)\s*$', text)}


class PackagedRelease(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='pr318-packaging-')
        cls.addClassCleanup(cls.temp.cleanup)
        folder = Path(cls.temp.name)
        cls.release = deploy.Deployment()
        cls.release.work = folder / 'archive'
        cls.release.work.mkdir()
        cls.release.build_root = folder / 'repository'
        cls.release.candidate = cls.release.build_root / 'server'
        cls.release.uid, cls.release.gid = os.getuid(), os.getgid()
        # This calls the same git archive + extractor as prepare_source, pinned
        # to the approved application commit. No fetch, service or DB operation.
        cls.release.stage_source(['git', '-C', str(ROOT)])
        modules = ROOT / 'server/node_modules'
        if not modules.is_dir():
            raise RuntimeError('Install checkout dependencies with npm ci first')
        (cls.release.candidate / 'node_modules').symlink_to(modules, target_is_directory=True)
        cls.environment = {k: v for k, v in os.environ.items()
                           if not (k.startswith(('DB_', 'PG', 'FIREBASE_', 'WEB_PUSH_'))
                                   or k in ('TEST_DATABASE_URL', 'DATABASE_URL', 'GOOGLE_APPLICATION_CREDENTIALS'))}
        cls.environment.update(NODE_ENV='test', APP_ENV='staging', STAGING_DISABLE_EXTERNAL_SERVICES='true')

    def command(self, args, expect_success=True):
        result = subprocess.run([str(x) for x in args], cwd=self.release.candidate,
                                env=self.environment, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=120)
        if result.returncode and expect_success:
            print(result.stdout)
        return result

    def test_missing_context_still_fails_all_five_contract_tests(self):
        context = self.release.build_root / 'deploy'
        hidden = self.release.build_root / 'hidden-deploy'
        context.rename(hidden)
        try:
            result = self.command(['node', '--test', '--test-reporter=tap', 'tests/marketplace-deploy-dependencies.test.js'], expect_success=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(counts(result.stdout), {'tests':5, 'pass':0, 'fail':5, 'skipped':0})
            self.assertEqual(len(re.findall(r"code: 'ENOENT'", result.stdout)), 5)
            print('EXPECTED_MISSING_CONTEXT_REPRODUCED: all five original contract tests fail with ENOENT')
        finally:
            hidden.rename(context)

    def test_pinned_package_passes_check_and_all_npm_tests(self):
        for name in deploy.DEPLOY_TEST_INPUTS:
            self.assertTrue((self.release.build_root / name).is_file())
        # Deploy helpers are test inputs beside server/, not runtime payload.
        self.assertFalse((self.release.candidate / 'deploy').exists())
        for command in ('check', 'test'):
            result = self.command(['npm', 'run', command])
            self.assertEqual(result.returncode, 0, result.stdout)
            if command == 'test':
                self.assertEqual(counts(result.stdout), {'tests':148, 'pass':146, 'fail':0, 'skipped':2})
                print('PACKAGED_NPM_TESTS: 148 total, 146 passed, 0 failed, 2 PostgreSQL suites require isolated TEST_DATABASE_URL')
        # These are still the original, approved safety tests and shell inputs.
        for name in ['server/tests/marketplace-deploy-dependencies.test.js', *deploy.DEPLOY_TEST_INPUTS]:
            source = subprocess.check_output(['git', '-C', str(ROOT), 'show', deploy.TARGET + ':' + name])
            self.assertEqual((self.release.build_root / name).read_bytes(), source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
