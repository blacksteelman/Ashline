#!/usr/bin/env python3
"""Publish verified PC ZIPs from an authenticated GitHub Actions runner."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def gh(*args, check=True):
    result = subprocess.run(['gh', *args], text=True, capture_output=True)
    if check and result.returncode:
        raise SystemExit(f'GitHub command failed: {result.stderr.strip()}')
    return result


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def find_release(repo, tag):
    page = 1
    while True:
        items = json.loads(gh('api', f'repos/{repo}/releases?per_page=100&page={page}').stdout)
        for item in items:
            if item['tag_name'] == tag:
                return item
        if len(items) < 100:
            return None
        page += 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', required=True)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--packages', type=Path, default=Path('build/packages'))
    args = parser.parse_args()
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', args.repo) or not re.fullmatch(r'[0-9a-f]{40}', args.revision):
        raise SystemExit('Invalid repository or full commit SHA')
    tag = 'dev-' + args.revision[:7]
    files = [args.packages / f'ASHLINE-{platform}-{args.revision[:7]}.zip' for platform in ['Windows', 'Linux']]
    sums = {path.name: digest(path) for path in files}
    checksum = args.packages / 'SHA256SUMS.txt'
    checksum.write_text(''.join(f'{sums[path.name]}  {path.name}\n' for path in files))
    files.append(checksum)
    sums[checksum.name] = digest(checksum)
    # Drafts are not reliably addressable by tag before publication.
    release = find_release(args.repo, tag)
    if release and not release['draft']:
        # A retry must never silently replace an already published binary.
        assets = {asset['name']: asset for asset in release['assets']}
        if not all(path.name in assets for path in files):
            raise SystemExit('Published release is incomplete; refusing to overwrite it')
        print(release['html_url'])
        return
    if not release:
        notes = args.packages / 'RELEASE_NOTES.md'
        notes.write_text(
            f'Промежуточная PC-сборка ASHLINE, ревизия `{args.revision}`.\n\n'
            'Скачайте ZIP своей платформы, полностью распакуйте и запустите '
            'ASHLINE.exe (Windows) либо ASHLINE.x86_64 (Linux). '
            'Инструкция находится в START_HERE_RU.txt.\n\n'
            'Сборка прошла автоматические проверки и тестовый матч Linux. '
            'Windows кросс-компилирован и не запускался на Windows. '
            'Это версия в разработке. Контрольные суммы архивов: SHA256SUMS.txt.\n'
        )
        gh('release', 'create', tag, '--repo', args.repo, '--target', args.revision,
           '--draft', '--prerelease', '--latest=false', '--title', f'ASHLINE PC — {args.revision[:7]}',
           '--notes-file', str(notes))
    # Only our unfinished draft may be repaired/retried.
    gh('release', 'upload', tag, *(str(path) for path in files), '--repo', args.repo, '--clobber')
    release = find_release(args.repo, tag)
    assets = {asset['name']: asset for asset in release['assets']}
    for path in files:
        asset = assets.get(path.name)
        if not asset or asset['state'] != 'uploaded' or asset['size'] != path.stat().st_size:
            raise SystemExit(f'Incomplete release asset: {path.name}')
        if asset.get('digest') != 'sha256:' + sums[path.name]:
            # Older GitHub responses may omit digests; verify downloaded bytes.
            with tempfile.TemporaryDirectory() as directory:
                gh('release', 'download', tag, '--repo', args.repo, '--pattern', path.name, '--dir', directory)
                if digest(Path(directory) / path.name) != sums[path.name]:
                    raise SystemExit(f'Uploaded asset hash mismatch: {path.name}')
    gh('release', 'edit', tag, '--repo', args.repo, '--draft=false', '--prerelease', '--latest=false')
    release = json.loads(gh('api', f"repos/{args.repo}/releases/{release['id']}").stdout)
    (args.packages / 'published-release.json').write_text(json.dumps(release, indent=2) + '\n')
    print(release['html_url'])


if __name__ == '__main__':
    main()
