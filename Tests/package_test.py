"""Check ZIP layout, runtime files, exclusions, and release-version validation."""
import importlib.util
from pathlib import Path
import tempfile
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('addon_package', root / 'Tools/package.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)
with tempfile.TemporaryDirectory() as temp:
    output = package.build(Path(temp) / 'addon.zip')
    with ZipFile(output) as archive:
        names = archive.namelist()
        assert archive.testzip() is None
        assert all(name.startswith('ZoidsTools_F/') for name in names)
        assert 'ZoidsTools_F/ZoidsTools_F.toc' in names
        assert 'ZoidsTools_F/Media/ZoidToolsIcon.png' in names
        assert 'ZoidsTools_F/LICENSE' in names
        assert not any('/Tests/' in n or '/Tools/' in n or '/.git' in n for n in names)
        toc = archive.read('ZoidsTools_F/ZoidsTools_F.toc').decode('utf-8-sig')
        for line in toc.splitlines():
            if line.strip() and not line.startswith('#'):
                assert 'ZoidsTools_F/' + line.strip().replace('\\', '/') in names
    try:
        package.build(Path(temp) / 'bad.zip', 'v999.0.0')
    except ValueError:
        pass
    else:
        raise AssertionError('Mismatched release tag was accepted')
print('PASS: installable ZIP, all TOC files, artwork, license, exclusions, and release-tag validation')
