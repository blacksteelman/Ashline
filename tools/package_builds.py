"""Package actual Godot PC exports with revision/hash metadata and launch instructions."""
import argparse
import hashlib
import json
import shutil
import struct
import zipfile
from datetime import datetime, timezone
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--linux-dir', type=Path, required=True)
    parser.add_argument('--windows-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('build/packages'))
    parser.add_argument('--revision', required=True)
    parser.add_argument('--no-archives', action='store_true')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True, exist_ok=True)
    for platform, folder, executable in [('Linux', args.linux_dir, 'ASHLINE.x86_64'), ('Windows', args.windows_dir, 'ASHLINE.exe')]:
        binary = folder / executable
        with binary.open('rb') as handle:
            header = handle.read(64)
            if platform == 'Linux':
                assert header[:5] == b'\x7fELF\x02' and struct.unpack_from('<H', header, 18)[0] == 62, 'Expected Linux x86-64 ELF'
            else:
                assert header[:2] == b'MZ', 'Expected Windows executable'
                handle.seek(struct.unpack_from('<I', header, 60)[0])
                assert handle.read(6) == b'PE\x00\x00\x64\x86', 'Expected Windows x86-64 PE'
        for name in ['README.md', 'LICENSES.md', 'START_HERE_RU.txt']:
            shutil.copy2(source / name, folder / name)
        payload = sorted(path for path in folder.iterdir() if path.is_file() and path.name != 'BUILD_INFO.json')
        manifest = {'game': 'ASHLINE', 'revision': args.revision, 'godot': '4.6.3', 'platform': platform,
                    'created_utc': datetime.now(timezone.utc).isoformat(),
                    'files': {path.name: {'bytes': path.stat().st_size, 'sha256': hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()} for path in payload}}
        (folder / 'BUILD_INFO.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        if args.no_archives:
            print(platform, 'export metadata ready')
            continue
        archive = args.output / f'ASHLINE-{platform}-{args.revision[:7]}.zip'
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=1) as package:
            for path in [*payload, folder / 'BUILD_INFO.json']:
                package.write(path, path.name)
        with zipfile.ZipFile(archive) as package:
            assert package.testzip() is None, 'Archive CRC validation failed'
        print(archive, archive.stat().st_size, 'bytes; CRC verified')


if __name__ == '__main__':
    main()
