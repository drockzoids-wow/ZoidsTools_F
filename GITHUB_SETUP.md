# Uploading to GitHub

This folder is a standalone Git repository. No GitHub repository or remote is created automatically.

Publish as a **new repository**, separate from retail ZoidsTools. Do not point its remote at the retail repository. Packages install into `ZoidsTools_F`, use separate saved settings, and target the Forever client. CurseForge uploads target only Forever project **1700355**.

## GitHub Desktop

1. Sign in to GitHub Desktop.
2. Choose **File > Add local repository** and select this `ZoidsTools_F` folder.
3. Choose **Publish repository**, use `ZoidsTools_F` as the name, and choose public or private.
4. Publish. GitHub's **Actions** tab will show the first automated checks.

## Command line alternative

Create an empty repository on GitHub named `ZoidsTools_F`. Do not add a README, license, or gitignore there because this folder already contains them. Then run these commands from this folder, replacing `YOUR-USERNAME` with your GitHub username:

```text
git remote add origin https://github.com/YOUR-USERNAME/ZoidsTools_F.git
git push -u origin main
```

Use Git's browser sign-in if prompted. The connected GitHub account in Codex and your local Git credentials are separate; one does not guarantee the other is signed in.

## Creating a downloadable release

Update the version in both `ZoidsTools_F.toc` and `Core.lua`, then enter your summary and description in GitHub Desktop and click **Commit to main**. Open Command Prompt from Desktop. For example, if both files have been updated to `0.2.1-beta`:

```text
git tag v0.2.1-beta
git push origin main v0.2.1-beta
```

Pushing the new tag starts **Release Forever addon**. It validates the version, runs tests, uploads to CurseForge project **1700355**, and publishes a GitHub release with the installable ZIP. Beta tags produce GitHub prereleases. No manual **Publish release** step is needed. Users should download the attached `ZoidsTools_F-<version>.zip`; GitHub's automatic source-code ZIP has a different folder layout.

The `CF_API_KEY` secret below is required. GitHub publishing uses its automatic token. If Actions is disabled by your account or organization, enable the workflows in repository settings. Use a new version/tag for each release; do not reuse `v0.2.0-beta`. See `CONTRIBUTING.md` for local testing and future releases.

## CurseForge uploads

1. In this GitHub repository, open **Settings > Secrets and variables > Actions > New repository secret**. Name it `CF_API_KEY` and enter your CurseForge upload API token. The same account's retail token can be reused, but the secret must be added to this repository separately. Never commit the token.
2. Commit these workflow changes in GitHub Desktop and click **Push origin**. Ordinary branch pushes run checks only.
3. Update both version fields, commit, and push a new matching tag as shown above.
4. Watch **Release Forever addon** in GitHub Actions. It uploads automatically; publishing or editing a GitHub release separately does not trigger another upload.
5. Review the file status on CurseForge; upload success does not bypass moderation.

The upload script checks the TOC project ID and resolves its exact game version (currently `1.60.1`) using CurseForge's version list. It stops if that version is unavailable or ambiguous rather than choosing another client. Beta tags upload as Beta, alpha tags as Alpha, and plain version tags as Release.

Do not rerun after a successful CurseForge upload: it could create a duplicate file, even if the later GitHub release step failed. After a timeout, check CurseForge's Files page before retrying. The new tag must include these workflow changes; existing tags retain their old workflow behavior.
