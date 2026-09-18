# ZoidsTools Forever project instructions

## Version management

- The user wants Codex to manage release versions automatically, without reminders.
- Always keep `ns.version` in `Core.lua` and `## Version` in `ZoidsTools_F.toc` identical. File values omit the leading `v`; release tags include it.
- The user's latest released version is `v0.2.0-beta`. The next planned release is `v0.2.1-beta`, now set in both files. Treat this as the initial baseline, not a permanent version to reset to.
- When preparing changes after a release, inspect current versions and local/retrieved release tags, then advance the patch version for the next release, retaining `-beta` unless the user requests a different version or release stage.
- Keep the same pending version across edits intended for that release; do not increment it on every conversation turn. If release state is unavailable, preserve an already prepared next version rather than guessing another bump.
- Update `CHANGELOG.md` to describe release changes and give the user matching tag/push commands when discussing publishing.
- Validate that packaging accepts the planned tag. Do not create tags, commit, push, or publish merely because version maintenance was requested.
