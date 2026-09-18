# ZoidsTools Forever project instructions

## Version management

- The user wants Codex to manage release versions automatically, without reminders.
- Always keep `ns.version` in `Core.lua`, `## Version` in `ZoidsTools_F.toc`, and `## Version` in `Recovery/ZoidsTools_F_Recovery.toc` identical. File values omit the leading `v`; release tags include it.
- The user confirmed pushing `v0.2.1-beta`, and the local release tag exists. The pending release is now `v0.2.2-beta`, prepared in all three version fields. Keep that version for further edits until it is released. Treat this as the current baseline, not a permanent version to reset to.
- When preparing changes after a release, inspect current versions and local/retrieved release tags, then advance the patch version for the next release, retaining `-beta` unless the user requests a different version or release stage.
- Keep the same pending version across edits intended for that release; do not increment it on every conversation turn. If release state is unavailable, preserve an already prepared next version rather than guessing another bump.
- Update `CHANGELOG.md` to describe release changes and give the user matching tag/push commands when discussing publishing.
- Validate that packaging accepts the planned tag. Do not create tags, commit, push, or publish merely because version maintenance was requested.
