"""Preserve the currently deployed Pages artifact; only overlay isletme-staging/."""
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tarfile
import time
import urllib.request
import urllib.error
import zipfile

REPO = 'Queensho/HeyCar'
SITE = 'https://queensho.github.io/HeyCar/'
STAGE = 'isletme-staging'
CRITICAL = ['index.html', 'isletme/index.html', 'owner/index.html', 'admin/index.html',
            'cekici/index.html', 'vale/index.html', 'flutter_bootstrap.js', 'isletme/flutter_bootstrap.js']


def api(path):
    request = urllib.request.Request('https://api.github.com/repos/' + REPO + path,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError('GitHub read failed HTTP ' + str(error.code) + ' at ' + path.split('?')[0]) from None


def active_source():
    deployments = api('/deployments?environment=github-pages&per_page=30')
    candidates = []
    for deployment in deployments:
        statuses = api('/deployments/' + str(deployment['id']) + '/statuses?per_page=15')
        success = next((s for s in statuses if s['state'] == 'success'), None)
        if not success:
            continue
        # Environment records identify the exact Actions run, never assume that
        # an arbitrary latest workflow artifact is the currently deployed site.
        link = success.get('log_url', '')
        match = re.search(r'/actions/runs/(\d+)', link)
        if not match:
            candidates.append({'deployment': deployment, 'status': success})
            continue
        run_id = int(match.group(1))
        run = api('/actions/runs/' + str(run_id))
        if run['head_sha'] != deployment['sha']:
            raise RuntimeError('PAGES_DEPLOYMENT_RUN_SHA_MISMATCH')
        if run.get('path') not in ('.github/workflows/heycar-pages.yml', '.github/workflows/staging-public-release.yml'):
            raise RuntimeError('ACTIVE_PAGES_FROM_ANOTHER_WORKFLOW_REQUIRES_REVIEW')
        artifacts = api('/actions/runs/' + str(run_id) + '/artifacts')['artifacts']
        artifact = next((a for a in artifacts if a['name'] == 'github-pages' and not a['expired']), None)
        if not artifact:
            raise RuntimeError('ACTIVE_PAGES_ARTIFACT_MISSING_OR_EXPIRED')
        return {'deploymentId': deployment['id'], 'runId': run_id, 'sha': run['head_sha'],
                'artifactId': artifact['id'], 'artifactDigest': artifact.get('digest')}
    raise RuntimeError('EXACT_ACTIVE_PAGES_RUN_NOT_IDENTIFIABLE; no site will be replaced')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def download_artifact(artifact_id, output):
    # Never forward the GitHub bearer token through the signed storage redirect.
    opener = urllib.request.build_opener(NoRedirect)
    req = urllib.request.Request('https://api.github.com/repos/' + REPO + '/actions/artifacts/' + str(artifact_id) + '/zip',
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN']})
    try:
        response = opener.open(req, timeout=30)
    except urllib.error.HTTPError as error:
        if error.code not in (301, 302, 303, 307, 308):
            raise RuntimeError('PAGES_ARTIFACT_DOWNLOAD_HTTP_' + str(error.code)) from None
        location = error.headers['Location']
        if not location.startswith('https://'):
            raise RuntimeError('PAGES_ARTIFACT_REDIRECT_REQUIRES_HTTPS')
        response = urllib.request.urlopen(location, timeout=60)
    with response, open(output, 'wb') as stream:
        shutil.copyfileobj(response, stream)


def unpack_tar(tar_path, output):
    output.mkdir(parents=True, exist_ok=False)
    total = 0
    with tarfile.open(tar_path, 'r:*') as archive:
        members = archive.getmembers()
        if len(members) > 100000:
            raise RuntimeError('PAGES_TOO_MANY_FILES')
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not (member.isdir() or member.isfile()):
                raise RuntimeError('UNSAFE_PAGES_ARCHIVE_MEMBER')
            total += member.size
            if total > 2 * 1024 ** 3:
                raise RuntimeError('PAGES_ARCHIVE_TOO_LARGE')
            target = output.joinpath(*path.parts)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as source, open(target, 'xb') as dest:
                    shutil.copyfileobj(source, dest)


def inventory(root, include_stage=False):
    result = {}
    for path in root.rglob('*'):
        if path.is_symlink():
            raise RuntimeError('PAGES_SYMLINK_FORBIDDEN')
        relative = path.relative_to(root)
        if path.is_file() and (include_stage or relative.parts[0] != STAGE):
            result[relative.as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def overlay(root, panel):
    if not (panel / 'index.html').is_file() or not (panel / 'main.dart.js').is_file():
        raise RuntimeError('STAGING_PANEL_PAYLOAD_INCOMPLETE')
    before = inventory(root)
    target = root / STAGE
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(panel, target)
    after = inventory(root)
    if before != after:
        raise RuntimeError('PRODUCTION_PAGES_FILES_CHANGED')
    return before


def live_matches(proof, stage=False):
    paths = dict(proof['critical'])
    if stage:
        paths[STAGE + '/index.html'] = proof['stagingIndexSha256']
    for name, digest in paths.items():
        good = False
        for attempt in range(12 if stage else 3):
            try:
                with urllib.request.urlopen(SITE + name, timeout=20) as response:
                    good = response.status == 200 and hashlib.sha256(response.read()).hexdigest() == digest
            except (urllib.error.URLError, TimeoutError):
                good = False
            if good:
                break
            time.sleep(5)
        if not good:
            raise RuntimeError('LIVE_PAGES_BYTES_MISMATCH: ' + name)


def main():
    mode = sys.argv[1]
    if mode == 'inspect':
        source = active_source()
        Path('pages-source.json').write_text(json.dumps(source, indent=2))
        print(json.dumps(source, indent=2))
    elif mode == 'prepare':
        source = active_source()
        download_artifact(source['artifactId'], 'pages-original.zip')
        with zipfile.ZipFile('pages-original.zip') as archive:
            if archive.namelist() != ['artifact.tar']:
                raise RuntimeError('UNEXPECTED_PAGES_ARTIFACT_ZIP')
            with archive.open('artifact.tar') as reader, open('pages-original.tar', 'wb') as dest:
                shutil.copyfileobj(reader, dest)
        unpack_tar('pages-original.tar', Path('pages-preserved'))
        root = Path('pages-preserved')
        for name in CRITICAL:
            if not (root / name).is_file():
                raise RuntimeError('PRODUCTION_PAGES_PAYLOAD_MISSING: ' + name)
        critical = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in CRITICAL}
        proof = {**source, 'critical': critical}
        live_matches(proof)
        protected = overlay(root, Path(sys.argv[2]))
        proof.update({'protectedFiles': protected, 'stagingIndexSha256': hashlib.sha256((root / STAGE / 'index.html').read_bytes()).hexdigest()})
        Path('pages-preservation.json').write_text(json.dumps(proof, indent=2))
        print('PAGES_PRODUCTION_FILES_PRESERVED count=' + str(len(protected)))
    elif mode == 'predeploy':
        proof = json.loads(Path('pages-preservation.json').read_text())
        if active_source()['deploymentId'] != proof['deploymentId']:
            raise RuntimeError('ACTIVE_PAGES_CHANGED; rebuild preservation payload before deploy')
        if inventory(Path('pages-preserved')) != proof['protectedFiles']:
            raise RuntimeError('PRODUCTION_PAGES_PAYLOAD_CHANGED_BEFORE_DEPLOY')
        live_matches(proof)
    elif mode == 'verify':
        proof = json.loads(Path('pages-preservation.json').read_text())
        live_matches(proof, stage=True)
        print('PUBLISHED_STAGING_AND_PROTECTED_PAGES_VERIFIED')
    else:
        raise RuntimeError('UNKNOWN_PAGES_MODE')


if __name__ == '__main__':
    main()
