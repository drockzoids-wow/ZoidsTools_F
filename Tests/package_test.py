"""Validate release contents and tags without creating an archive."""
import importlib.util
from pathlib import Path
import re
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('addon_package', root / 'Tools/package.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
toc = (root / 'ZoidsTools_F.toc').read_text()
version = re.search(r'^## Version:\s*(\S+)', toc, re.MULTILINE).group(1)
names = []
class ArchiveRecorder:
    def __init__(self, *args, **kwargs): pass
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def write(self, path, name):
        assert path.is_file()
        names.append(name)

with patch.object(package, 'ZipFile', ArchiveRecorder):
    package.build(root / 'unused-test-output.zip', tag=f'v{version}')
assert all(name.startswith('ZoidsTools_F/') for name in names)
assert not any('Recovery' in name or 'Preset' in name for name in names)
for required in ['ZoidsTools_F.toc', 'Media/ZoidToolsIcon.png', 'LICENSE', 'Locales/README.md']:
    assert f'ZoidsTools_F/{required}' in names
assert not any('/Tests/' in n or '/Tools/' in n or '/build/' in n or '/.git' in n for n in names)
for line in toc.splitlines():
    if line.strip() and not line.startswith('#'):
        assert 'ZoidsTools_F/' + line.strip().replace('\\', '/') in names
with patch.object(package, 'ZipFile', side_effect=AssertionError('Validation must not create an archive')):
    assert 'no archive created' in package.build(tag=f'v{version}', validate_only=True)
    try:
        package.build(tag='v999.0.0', validate_only=True)
    except ValueError:
        pass
    else:
        raise AssertionError('Mismatched release tag was accepted')
print('PASS: main-only release contents, TOC files, exclusions, and release-tag validation; no archive created')
