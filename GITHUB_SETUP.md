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

After pushing the main branch, tag the current version:

```text
git tag v0.2.0-beta
git push origin v0.2.0-beta
```

The workflow validates the version, tests, packages, and creates a **draft prerelease** with the installable ZIP. Open **Releases**, review the draft, and publish it when ready. Users should download the attached `ZoidsTools_F-<version>.zip`; GitHub's automatic source-code ZIP has a different folder layout.

No extra secrets are required for the GitHub draft release. If Actions is disabled by your account or organization, enable the workflows in repository settings. See `CONTRIBUTING.md` for local testing and future releases.

## CurseForge uploads

1. In this GitHub repository, open **Settings > Secrets and variables > Actions > New repository secret**. Name it `CF_API_KEY` and enter your CurseForge upload API token. The same account's retail token can be reused, but the secret must be added to this repository separately. Never commit the token.
2. Commit these workflow changes in GitHub Desktop and click **Push origin**. Ordinary branch pushes run checks only.
3. To release the current version, create the tag `v0.2.0-beta` on the latest commit in Desktop's History tab, then push the tag. Future tags must match the version in both the TOC and Core.lua.
4. Wait for **Draft addon release** to finish in GitHub Actions. Open the resulting draft in **Releases**, review it, and click **Publish release**. Publishing the prerelease also triggers uploading.
5. Watch **Upload Forever release to CurseForge** in Actions. It tests and packages the tagged code, then uploads to project **1700355**. Review the file status on CurseForge; upload success does not bypass moderation.

The upload script checks the TOC project ID and resolves its exact game version (currently `1.60.1`) using CurseForge's version list. It stops if that version is unavailable or ambiguous rather than choosing another client. Beta tags upload as Beta, alpha tags as Alpha, and plain version tags as Release.

Do not rerun a successful upload workflow: it could create a duplicate file. After a timeout, check CurseForge's Files page before retrying. The first tag must include the new workflow and upload script; publishing a tag from before these changes will not work.
