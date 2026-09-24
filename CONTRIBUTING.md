# Contributing

This addon targets WoW: Forever beta. Keep changes focused and retain the restricted-data and protected-frame precautions inherited from ZoidsTools.

## Local checks

With Python 3.12 installed, run from this folder:

```text
python -m pip install -r Tests/requirements.txt
python Tests/smoke.py
python Tests/package_test.py
python Tools/package.py --validate-only
```

Tests use Lua 5.1 via Lupa. They are mocked checks; validate UI and combat behavior in the actual client before describing a change as compatible.

The package builder includes the TOC, its Lua load list, artwork, license, README, and changelog under `ZoidsTools_F`. Local files from `build` are never packaged. Add new runtime Lua files to the appropriate TOC. Extend the builder for new runtime resource types. Generated ZIP files stay in the ignored `dist` folder.

For changes, include a clear description and test results. For bugs, include the addon version, `/ztf status` output, reproduction steps, and any Lua error.

## Releases

Update the matching versions in `Core.lua` and `ZoidsTools_F.toc`, and update `CHANGELOG.md`. Commit changes, then push main and a new matching `v` tag (for example, `git push origin main v0.2.1-beta`). The release workflow runs tests, uploads the addon ZIP to Forever CurseForge project 1700355 using the repository's `CF_API_KEY` secret, and publishes the GitHub release automatically. Tags containing a hyphen are marked prerelease. See `GITHUB_SETUP.md` for setup and retry guidance.

The workflow uses GitHub's automatic token; no personal token or CurseForge secret is needed. CurseForge distribution is not configured for this new addon.
