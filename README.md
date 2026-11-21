# SODFA Build Orchestrator

This repository is a **public build orchestrator only**. The Flutter application source must remain in the private `loudply0-eng/sodfa-` repository.

## Source and build flow

- Canonical application source: `loudply0-eng/sodfa-` (private repository).
- Build orchestrator: `loudply0-eng/sodfa-build` (public repository).
- GitHub Actions free hosted build minutes are used through this public repository.
- Production release builds are automatically dispatched when application files change on the private source repository's `main` branch; a manual dispatch remains available for recovery.
- The private source dispatch pins the production build to the exact pushed 40-character source commit SHA, so queued builds cannot silently pick up a newer source revision.
- Automatic dispatch does not bypass the protected `sodfa-production` environment approval; a required reviewer must approve before any production signing/deployment secret is exposed.
- A protected GitHub Environment approval is required before production secrets are exposed to the release job.
- The workflow checks out only the private source repository's `main` branch using a fine-grained read-only token.
- The workflow runs the private API dependency audit, PostgreSQL/Redis migrations and integration tests, then `flutter pub get`, `flutter analyze`, and `flutter test`; it builds an obfuscated APK, verifies the Android signing certificate, signs the update manifest with Ed25519, and publishes the APK plus manifest and detached signature.
- Private source build logs, Android signing files, update signing keys, and Dart obfuscation symbols are not uploaded as artifacts.
- The deployment verifies the APK SHA-256, application ID, platform, channel, manifest version and build number on the Oracle server before publishing. A stale build cannot overwrite a newer manifest; retries of the exact same build are idempotent, while different APK/manifest/signature bytes under the same build number are rejected.
- The remote publication logic is isolated in `scripts/sodfa-remote-publish.sh` and regression-tested by `scripts/test-sodfa-remote-publish.sh` in builder CI (new release, exact retry, same-build tampering and rollback attempts).
- Every external GitHub Action used by this public builder is pinned to a full commit SHA and checked by CI.
- The app verifies the detached Ed25519 signature on the exact manifest bytes before parsing update metadata. It also enforces HTTPS, same-origin APK hosting under `/updates/sodfa/`, and SHA-256 verification.

## Required GitHub configuration

Create **two separate GitHub Environments** in this public repository. Do not put the source-read token in the production environment, and do not put release/deploy secrets in the validation environment.

### `sodfa-validation` — private-source tests only

1. Restrict deployment branches to `main` only.
2. Add at least one required reviewer.
3. Add only this **environment secret**:
   - `SODFA_VALIDATION_SOURCE_READ_TOKEN`: a fine-grained token scoped only to `loudply0-eng/sodfa-`, with **Contents: Read-only** permission.

This environment is used by the source-validation workflow to clone a selected private source ref and run tests. It must not contain Android signing keys, OTA signing keys, or server deployment keys. Validation has no dependency or Gradle cache, so source branches cannot modify a cache used by production releases.

### `sodfa-production` — signed release and deployment

1. Restrict deployment branches to `main` only.
2. Add at least one required reviewer.
3. Add these **environment secrets**:
   - `SODFA_PROD_SOURCE_READ_TOKEN`: a separate fine-grained token scoped only to `loudply0-eng/sodfa-`, with **Contents: Read-only** permission.
   - `SODFA_PROD_ANDROID_KEYSTORE_BASE64`
   - `SODFA_PROD_ANDROID_KEYSTORE_PASSWORD`
   - `SODFA_PROD_ANDROID_KEY_ALIAS`
   - `SODFA_PROD_ANDROID_KEY_PASSWORD`
   - `SODFA_PROD_UPDATE_PRIVATE_KEY_PEM`: the Ed25519 private signing key in PEM format.
   - `SODFA_PROD_DEPLOY_HOST`
   - `SODFA_PROD_DEPLOY_USER`
   - `SODFA_PROD_DEPLOY_SSH_KEY`
   - `SODFA_PROD_DEPLOY_KNOWN_HOSTS`: pre-verified known-hosts line(s) for the deployment server. Do not generate trust at deployment time with `ssh-keyscan`.
4. Add this **environment variable** (not secret):
   - `SODFA_PROD_UPDATE_PUBLIC_KEY_BASE64`: Base64 encoding of the 32-byte raw Ed25519 public key paired with `SODFA_PROD_UPDATE_PRIVATE_KEY_PEM`.

The `SODFA_VALIDATION_SOURCE_READ_TOKEN` and `SODFA_PROD_SOURCE_READ_TOKEN` must be separate least-privilege tokens. Never give either token write access.

The `SODFA_PROD_` and `SODFA_VALIDATION_` prefixes are deliberate: the workflows no longer reference legacy unprefixed repository-secret names, preventing silent fallback to older repository-level secrets. Do not use a personal token with access to unrelated repositories. Never commit the Ed25519 private key or paste it into a workflow file.

## Generate the Ed25519 update-signing key pair

Generate it on a trusted local machine, not in the public repository and not in a CI log:

```bash
umask 077
openssl genpkey -algorithm ED25519 -out sodfa-update-ed25519.pem
openssl pkey -in sodfa-update-ed25519.pem -pubout -out sodfa-update-public.pem
openssl pkey -pubin -in sodfa-update-public.pem -outform DER -out sodfa-update-public.der
tail -c 32 sodfa-update-public.der | base64 -w0 > sodfa-update-public-key.txt
```

- Put the PEM private-key file contents into the `SODFA_PROD_UPDATE_PRIVATE_KEY_PEM` environment secret.
- Put the contents of `sodfa-update-public-key.txt` into the `SODFA_PROD_UPDATE_PUBLIC_KEY_BASE64` environment variable.
- Keep the private PEM file offline and backed up securely. Never upload it to GitHub as a file or artifact.
- The release workflow derives the public key from the private key and refuses to proceed if the two do not match.

## Validate a private source branch without production signing keys

Open **Actions → SODFA Private Source Validation → Run workflow**, select the builder's `main` branch, enter the private source branch or commit in `source_ref`, and set `confirm_validation` to `true`.

This workflow uses only the read-only source token stored in the separate `sodfa-validation` environment. It does not receive the Android signing key, update-signing private key, or deployment SSH key. It starts disposable PostgreSQL 18 and Redis 8 services, installs private API dependencies, audits production dependencies for high-severity advisories, applies database migrations, and runs API unit and integration tests. It then runs Flutter dependency installation, analysis, tests, a debug build, and an obfuscated Release smoke build with a temporary disposable key. Private source logs are suppressed and removed during cleanup. The protected environment approval is still required because the private source read token is used.

## Run a release build

For normal application changes, merging the approved app update into the private source repository's `main` branch automatically dispatches **SODFA Secure Android Release** for that exact source commit. A required reviewer must approve the `sodfa-production` environment before the signed APK and update manifest are uploaded to Oracle. For recovery/manual release, open **Actions → SODFA Secure Android Release → Run workflow**, select `main`, keep `source_ref=main` (or enter a full 40-character source commit SHA), and set `confirm_release` to `true`. The signed APK is retained as the `sodfa-android-release` workflow artifact for 14 days.

The automatic trigger covers Android app source/configuration, assets, dependency files, and `docs/CHANGELOG.json`. It does not deploy changes to the backend API service; API server deployment remains a separate controlled operation.

The workflow publishes:
- `sodfa-{version}+{build}.apk`
- `manifest.json`
- `manifest.json.sig`

The signature file is base64-encoded Ed25519 over the exact UTF-8 bytes of `manifest.json`. The workflow publishes the signature before replacing the manifest, so a brief deployment transition fails closed.

## Private source repository note

The private `loudply0-eng/sodfa-` repository remains private on the GitHub Free-compatible configuration. GitHub Free does not provide Environments or environment secrets for private repositories. Its three manual Oracle workflows use the uniquely named private repository secrets `SODFA_PROD_ORACLE_SSH_KEY` and `SODFA_PROD_ORACLE_KNOWN_HOSTS`. The automatic Android release dispatcher additionally requires `SODFA_BUILDER_RELEASE_DISPATCH_TOKEN`, a fine-grained token scoped only to this public builder with **Actions: Read and write** permission and no Contents write permission. It dispatches the protected release workflow for the exact source commit; it does not receive Android signing or server SSH keys. Do not add legacy unprefixed repository secret names.

## Public-source history limitation

Removing source files from the proposed current public tree does not erase older public Git commits or copies already cloned by other people. Historical removal requires a separately approved repository-history rewrite and coordination for old clones. This PR does not rewrite Git history.
