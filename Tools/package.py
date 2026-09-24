"""Build an installable ZIP from the TOC load list and explicit supporting files."""
import argparse
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
ADDON = 'ZoidsTools_F'


def build(output=None, tag=None, validate_only=False):
    toc_path = ROOT / f'{ADDON}.toc'
    toc = toc_path.read_text(encoding='utf-8-sig')
    version = re.search(r'^## Version:\s*(\S+)\s*$', toc, re.MULTILINE).group(1)
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?', version):
        raise ValueError(f'Invalid addon version: {version}')
    if tag is not None and tag != f'v{version}':
        raise ValueError(f'Tag {tag!r} must match TOC version v{version}')
    core = (ROOT / 'Core.lua').read_text(encoding='utf-8-sig')
    if f'ns.version = "{version}"' not in core:
        raise ValueError('Core.lua and TOC versions must match')
    files = {toc_path, ROOT / 'LICENSE', ROOT / 'README.md', ROOT / 'CHANGELOG.md', ROOT / 'Locales' / 'README.md'}
    for line in toc.splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            path = (ROOT / line.replace('\\', '/')).resolve()
            if not path.is_relative_to(ROOT):
                raise ValueError(f'TOC path escapes addon folder: {line}')
            files.add(path)
    files.update(p for p in (ROOT / 'Media').rglob('*') if p.is_file())
    for path in files:
        if not path.is_file():
            raise FileNotFoundError(path)
    if validate_only:
        return f'Validated {ADDON} v{version} ({len(files)} files); no archive created'
    destination = Path(output) if output else ROOT / 'dist' / f'{ADDON}-{version}.zip'
    destination.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(destination, 'w', compression=ZIP_DEFLATED) as archive:
        for path in sorted(files):
            archive.write(path, f'{ADDON}/{path.relative_to(ROOT).as_posix()}')
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', help='Validate a release tag, e.g. v0.2.0-beta')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--validate-only', action='store_true', help='Check versions and manifest without creating a ZIP')
    args = parser.parse_args()
    print(build(args.output, args.tag, args.validate_only))
