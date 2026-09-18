"""Offline checks: uploads must select the Forever project and exact game version."""
from pathlib import Path
import io
import json
import re
import sys
from unittest.mock import patch, MagicMock

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'Tools'))
import upload_curseforge as cf

toc = (root / 'ZoidsTools_F.toc').read_text(encoding='utf-8-sig')
current_version = re.search(r'^## Version:\s*(\S+)', toc, re.M).group(1)
versions = [{'id': 123, 'name': '1.60.1'}, {'id': 456, 'name': '12.0.1'}]
assert cf.metadata(toc, 'v0.2.0-beta', versions)['gameVersions'] == [123]
for tag, expected in [('v0.2.0-beta', 'beta'), ('v0.2.0-alpha.1', 'alpha'), ('v0.2.0', 'release')]:
    assert cf.metadata(toc, tag, versions)['releaseType'] == expected
for bad_toc, bad_versions in [
    (toc.replace('1700355', '999'), versions),
    (toc.replace('160001', '120001'), versions),
    (toc, versions[1:]),
    (toc, versions + [versions[0]]),
]:
    try:
        cf.metadata(bad_toc, 'v0.2.0-beta', bad_versions)
    except ValueError:
        pass
    else:
        raise AssertionError('Accepted wrong project or unavailable/ambiguous game version')
with patch.dict('os.environ', {}, clear=True), patch.object(cf, 'build_opener') as network:
    try:
        cf.upload('v0.2.0-beta')
    except ValueError as error:
        assert 'CF_API_KEY' in str(error)
    else:
        raise AssertionError('Accepted missing token')
    network.assert_not_called()
opener = MagicMock()
opener.open.side_effect = [io.BytesIO(json.dumps(versions).encode()), io.BytesIO(b'{"id": 987}')]
with patch.dict('os.environ', {'CF_API_KEY': 'test-token'}), patch.object(cf, 'build_opener', return_value=opener):
    cf.upload('v' + current_version)
request = opener.open.call_args_list[1].args[0]
assert request.full_url == 'https://wow.curseforge.com/api/projects/1700355/upload-file'
assert request.get_method() == 'POST'
assert request.get_header('X-api-token') == 'test-token'
assert b'"gameVersions": [123]' in request.data
assert f'filename="ZoidsTools_F-{current_version}.zip"'.encode() in request.data
assert b'PK\x03\x04' in request.data
print('PASS: Forever destination, game version, release types, missing secret, and mocked upload')
