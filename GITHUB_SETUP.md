# Uploading to GitHub

This folder is a standalone Git repository. No GitHub repository or remote is created automatically.

Publish as a **new repository**, separate from retail ZoidsTools. Do not point its remote at the retail repository. Packages install into `ZoidsTools_F`, use separate saved settings, and target the Forever client. There is no retail CurseForge project ID or upload workflow here.

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

No extra secrets are required under standard GitHub Actions settings. If Actions is disabled by your account or organization, enable the workflows in repository settings. See `CONTRIBUTING.md` for local testing and future releases.
