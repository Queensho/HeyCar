import importlib.util
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('selector',Path(__file__).with_name('select-artifact.py'))
selector=importlib.util.module_from_spec(spec);spec.loader.exec_module(selector)
class ArtifactSelectionTest(unittest.TestCase):
    def test_exact_source_only(self):
        ref='release/car-wash-main-regression';sha='a'*40
        good={'id':3,'head_branch':ref,'head_sha':sha,'event':'workflow_dispatch','conclusion':'success'}
        runs=[{**good,'id':1,'head_branch':'feature/car-wash-phase-1'},{**good,'id':2,'head_sha':'b'*40},good]
        self.assertEqual(selector.select_candidate(runs,lambda _: [{'name':'cepqontag-car-wash-staging-web','expired':False}],ref,sha)['id'],3)
    def test_expired_failed_or_other_ref_is_blocked(self):
        good={'id':1,'head_branch':'main','head_sha':'a'*40,'event':'workflow_dispatch','conclusion':'success'}
        for run,artifacts in [(good,[{'name':'cepqontag-car-wash-staging-web','expired':True}]),({**good,'conclusion':'failure'},[]),({**good,'head_sha':'b'*40},[])]:
            with self.assertRaises(ValueError):selector.select_candidate([run],lambda _:artifacts,'main','a'*40)
        with self.assertRaises(ValueError):selector.select_candidate([],lambda _:[],'other','a'*40)
if __name__=='__main__':unittest.main()
