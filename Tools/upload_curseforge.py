"""Upload a validated Forever package to its dedicated CurseForge project."""
import json
import os
import re
import sys
import uuid
from urllib.error import HTTPError, URLError
from urllib.request import Request, build_opener, HTTPRedirectHandler

from package import ROOT, build

PROJECT_ID = '1700355'
API = 'https://wow.curseforge.com/api'
# Forever beta uses interface 160001 for client 1.60.1; do not infer retail numbering.
GAME_VERSIONS = {160001: '1.60.1'}


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def metadata(toc, tag, versions):
    project = re.search(r'^## X-Curse-Project-ID:\s*(\d+)\s*$', toc, re.M)
    if not project or project.group(1) != PROJECT_ID:
        raise ValueError('TOC must target Forever CurseForge project 1700355')
    interface = int(re.search(r'^## Interface:\s*(\d+)\s*$', toc, re.M).group(1))
    if interface not in GAME_VERSIONS:
        raise ValueError('Update the verified Forever game version mapping before releasing this interface')
    version = GAME_VERSIONS[interface]
    matches = [v['id'] for v in versions if v['name'] == version]
    if len(matches) != 1:
        raise ValueError(f'CurseForge must list exactly one game version {version}; refusing to guess')
    return {
        'displayName': f'ZoidsTools Forever {tag}',
        'gameVersions': matches,
        'releaseType': 'alpha' if '-alpha' in tag else 'beta' if '-' in tag else 'release',
        'changelog': (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8'),
        'changelogType': 'markdown',
    }


def upload(tag):
    token = os.environ.get('CF_API_KEY', '').strip()
    if not token:
        raise ValueError('Add the CF_API_KEY Actions secret in the ZoidsTools_F GitHub repository')
    archive = build(tag=tag)
    opener = build_opener(NoRedirects())
    headers = {'X-Api-Token': token, 'User-Agent': 'ZoidsTools-Forever-release'}
    with opener.open(Request(f'{API}/game/versions', headers=headers), timeout=60) as response:
        versions = json.load(response)
    data = metadata((ROOT / 'ZoidsTools_F.toc').read_text(encoding='utf-8-sig'), tag, versions)
    boundary = uuid.uuid4().hex
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
        'Content-Type: application/json\r\n\r\n'
    ).encode() + json.dumps(data).encode() + (
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\n'
        'Content-Type: application/zip\r\n\r\n'
    ).encode() + archive.read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    headers['Content-Type'] = f'multipart/form-data; boundary={boundary}'
    request = Request(f'{API}/projects/{PROJECT_ID}/upload-file', data=body, headers=headers)
    # Do not retry POSTs automatically: a timed-out upload may already have succeeded.
    with opener.open(request, timeout=120) as response:
        result = json.load(response)
    if not isinstance(result.get('id'), int):
        raise ValueError('Upload response did not contain a file ID; check CurseForge before retrying')
    print(f"Uploaded to Forever project {PROJECT_ID}: CurseForge file {result['id']}")


if __name__ == '__main__':
    try:
        upload(os.environ['RELEASE_TAG'])
    except HTTPError as error:
        sys.exit(f'CurseForge returned HTTP {error.code}. Check project access, token, and approval status in CurseForge.')
    except (URLError, TimeoutError):
        sys.exit('Could not confirm the upload. Check CurseForge Files before retrying to avoid duplicates.')
    except (ValueError, KeyError) as error:
        sys.exit(str(error))
