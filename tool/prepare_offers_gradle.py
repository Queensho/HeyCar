"""Use a SHA-256 verified official Gradle release when browser URLs return 504.

Requires gh (GH_TOKEN in CI). Does not change Gradle's version or use a mirror.
Only rewrites the generated wrapper to a verified local distribution archive.
"""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def prepare(wrapper, cache):
    content = wrapper.read_text()
    match = re.search(r'gradle-(\d+(?:\.\d+)+)-(?:all|bin)\.zip', content)
    if not match:
        raise SystemExit('Generated Gradle distribution version not found')
    version = match.group(1)
    release = json.loads(subprocess.check_output([
        'gh', 'api', f'repos/gradle/gradle-distributions/releases/tags/v{version}'
    ]))
    name = f'gradle-{version}-bin.zip'
    assets = [a for a in release['assets'] if a['name'] == name]
    if len(assets) != 1 or not re.fullmatch(r'sha256:[0-9a-f]{64}', assets[0].get('digest') or ''):
        raise SystemExit('Official Gradle binary with SHA-256 digest required')
    asset = assets[0]
    expected = asset['digest'].split(':')[1]
    cache.mkdir(parents=True, exist_ok=True)
    archive = cache / name
    if not archive.exists() or digest(archive) != expected:
        temporary = archive.with_suffix('.download')
        with temporary.open('wb') as output:
            subprocess.run(['gh', 'api', '-H', 'Accept: application/octet-stream',
                            f"repos/gradle/gradle-distributions/releases/assets/{int(asset['id'])}"],
                           stdout=output, check=True)
        if digest(temporary) != expected:
            temporary.unlink()
            raise SystemExit('Official Gradle distribution checksum mismatch')
        temporary.replace(archive)
    content = re.sub(r'^distributionUrl=.*$',
                     'distributionUrl=' + archive.resolve().as_uri(), content, flags=re.M)
    content = re.sub(r'^distributionSha256Sum=.*\n?', '', content, flags=re.M)
    content += '\ndistributionSha256Sum=' + expected + '\n'
    wrapper.write_text(content)
    print(f'Using official Gradle {version} binary; SHA-256 verified')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--wrapper', type=Path,
                        default=Path('android/gradle/wrapper/gradle-wrapper.properties'))
    parser.add_argument('--cache-dir', type=Path, default=Path(tempfile.gettempdir()) / 'offers-gradle')
    args = parser.parse_args()
    prepare(args.wrapper, args.cache_dir)
