"""Select only an unexpired staging web build of this exact ref and SHA."""
import json
import os
import urllib.parse
import urllib.request

ALLOWED_REFS = {'main', 'release/car-wash-main-regression', 'feature/car-wash-phase-1'}

def select_candidate(runs, artifacts_for, ref, sha):
    if ref not in ALLOWED_REFS or len(sha) != 40 or any(c not in '0123456789abcdef' for c in sha):
        raise ValueError('UNAPPROVED_STAGING_SOURCE')
    for run in runs:
        if (run.get('head_branch') != ref or run.get('head_sha') != sha
                or run.get('event') != 'workflow_dispatch' or run.get('conclusion') != 'success'):
            continue
        if any(a.get('name') == 'cepqontag-car-wash-staging-web' and not a.get('expired', True)
               for a in artifacts_for(run['id'])):
            return run
    raise ValueError('NO_EXACT_SOURCE_STAGING_ARTIFACT')

def main():
    repo, ref, sha = os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_REF_NAME'], os.environ['GITHUB_SHA']
    headers = {'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'}
    def get(path):
        with urllib.request.urlopen(urllib.request.Request('https://api.github.com/repos/'+repo+path, headers=headers), timeout=25) as response:
            return json.load(response)
    runs = get('/actions/workflows/pages.yml/runs?'+urllib.parse.urlencode({'branch':ref,'event':'workflow_dispatch','status':'success','per_page':30}))['workflow_runs']
    selected = select_candidate(runs, lambda run_id: get(f'/actions/runs/{run_id}/artifacts?per_page=100')['artifacts'], ref, sha)
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f"run_id={selected['id']}\nsource_sha={selected['head_sha']}\n")
    print(f"Using exact-source staging build {selected['id']} at {sha}")

if __name__ == '__main__':
    main()
