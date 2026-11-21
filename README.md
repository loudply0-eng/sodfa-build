# SODFA Build Orchestrator

This repository is a **public build orchestrator only**. The Flutter application source must remain in the private `loudply0-eng/sodfa-` repository.

## Source and build flow

- Canonical application source: `loudply0-eng/sodfa-` (private repository).
- Build orchestrator: `loudply0-eng/sodfa-build` (public repository).
- GitHub Actions free hosted build minutes are used through this public repository.
- Production release builds can only be started manually from this repository's `main` branch, with explicit confirmation.
- A protected GitHub Environment approval is required before production secrets are exposed to the release job.
- The workflow checks out only the private source repository's `main` branch using a fine-grained read-only token.
- The workflow runs `flutter pub get`, `flutter analyze`, and `flutter test`; it then builds an obfuscated APK, verifies the Android signing certificate, signs the update manifest with Ed25519, and publishes the APK plus manifest and detached signature.
- Private source build logs, Android signing files, update signing keys, and Dart obfuscation symbols are not uploaded as artifacts.
- The app verifies the detached Ed25519 signature on the exact manifest bytes before parsing update metadata. It also enforces HTTPS, same-origin APK hosting under `/updates/sodfa/`, and SHA-256 verification.

## Required GitHub configuration

Create a GitHub Environment named `sodfa-production` in this public repository:

1. Restrict deployment branches to `main` only.
2. Add at least one required reviewer for production jobs.
3. Add these **environment secrets**:
   - `SODFA_SOURCE_READ_TOKEN`: fine-grained token scoped only to `loudply0-eng/sodfa-`, with **Contents: Read-only** permission.
   - `ANDROID_KEYSTORE_BASE64`
   - `ANDROID_KEYSTORE_PASSWORD`
   - `ANDROID_KEY_ALIAS`
   - `ANDROID_KEY_PASSWORD`
   - `SODFA_UPDATE_PRIVATE_KEY_PEM`: the Ed25519 private signing key in PEM format.
   - `SODFA_DEPLOY_HOST`
   - `SODFA_DEPLOY_USER`
   - `SODFA_DEPLOY_SSH_KEY`
   - `SODFA_DEPLOY_KNOWN_HOSTS`: pre-verified known-hosts line(s) for the deployment server. Do not generate trust at deployment time with `ssh-keyscan`.
4. Add this **environment variable** (not secret):
   - `SODFA_UPDATE_PUBLIC_KEY_BASE64`: Base64 encoding of the 32-byte raw Ed25519 public key paired with `SODFA_UPDATE_PRIVATE_KEY_PEM`.

Never give the source token write access. Do not use a personal token with access to unrelated repositories. Never commit the Ed25519 private key or paste it into a workflow file.

## Generate the Ed25519 update-signing key pair

Generate it on a trusted local machine, not in the public repository and not in a CI log:

```bash
umask 077
openssl genpkey -algorithm ED25519 -out sodfa-update-ed25519.pem
openssl pkey -in sodfa-update-ed25519.pem -pubout -out sodfa-update-public.pem
openssl pkey -pubin -in sodfa-update-public.pem -outform DER -out sodfa-update-public.der
tail -c 32 sodfa-update-public.der | base64 -w0 > sodfa-update-public-key.txt
```

- Put the PEM private-key file contents into the `SODFA_UPDATE_PRIVATE_KEY_PEM` environment secret.
- Put the contents of `sodfa-update-public-key.txt` into the `SODFA_UPDATE_PUBLIC_KEY_BASE64` environment variable.
- Keep the private PEM file offline and backed up securely. Never upload it to GitHub as a file or artifact.
- The release workflow derives the public key from the private key and refuses to proceed if the two do not match.

## Validate a private source branch without production signing keys

Open **Actions → SODFA Private Source Validation → Run workflow**, select the builder's `main` branch, enter the private source branch or commit in `source_ref`, and set `confirm_validation` to `true`.

This workflow uses the read-only source token only for checkout. It does not receive the Android signing key, update-signing private key, or deployment SSH key. It suppresses private source logs, runs dependency install, analysis, tests, a debug build, and an obfuscated Release smoke build with a temporary disposable key. The protected environment approval is still required because the private source read token is used.

## Run a release build

Open **Actions → SODFA Secure Android Release → Run workflow**, select `main`, and set `confirm_release` to `true`. The `sodfa-production` environment approval must also be completed. The signed APK is retained as the `sodfa-android-release` workflow artifact for 14 days.

The workflow publishes:
- `sodfa-{version}+{build}.apk`
- `manifest.json`
- `manifest.json.sig`

The signature file is base64-encoded Ed25519 over the exact UTF-8 bytes of `manifest.json`. The workflow publishes the signature before replacing the manifest, so a brief deployment transition fails closed.

## Public-source history limitation

Removing source files from the proposed current public tree does not erase older public Git commits or copies already cloned by other people. Historical removal requires a separately approved repository-history rewrite and coordination for old clones. This PR does not rewrite Git history.
