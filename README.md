# SODFA Build Orchestrator

This repository is intentionally a **public build orchestrator only**. It must not contain the Flutter application source code.

## Source and build flow

- Canonical application source: `loudply0-eng/sodfa-` (private repository).
- Build orchestrator: `loudply0-eng/sodfa-build` (public repository).
- GitHub Actions free hosted build minutes remain in use through this public repository.
- The release workflow can only be started manually from this repository's `main` branch, with explicit confirmation.
- The workflow checks out only the private source repository's `main` branch using a read-only token, builds an obfuscated APK, verifies the registered Android signing certificate, and uploads the APK as a 14-day artifact.
- Private source logs, signing files, and Dart obfuscation symbols are not uploaded as artifacts.
- The workflow does **not** publish to the update server. OTA publishing stays disabled until the app verifies an independent Ed25519 signature on the update manifest.

## Required GitHub configuration

Create a GitHub Environment named `sodfa-production` in this public repository:

1. Restrict deployment branches to `main`.
2. Add at least one required reviewer for production jobs.
3. Add the following as **environment secrets**, not source files:
   - `SODFA_SOURCE_READ_TOKEN`: fine-grained GitHub token scoped only to `loudply0-eng/sodfa-`, with **Contents: Read-only** permission.
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`

Never give the source token write access. Do not use a personal token with access to unrelated repositories.

## Run a release build

Open **Actions → SODFA Secure Android Release → Run workflow**, select `main`, and set `confirm_release` to `true`. The production environment approval must also be completed. The signed APK will be available as the `sodfa-android-release` workflow artifact.

## Important history limitation

Removing source files from the current public branch does not erase earlier public Git commits or copies already cloned by other people. Historical removal requires a separately approved repository-history rewrite and coordination for old clones.
