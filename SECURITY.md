# Security Policy

This repository only orchestrates builds. The application source remains in the private `loudply0-eng/sodfa-` repository.

## Reporting

Do not publish credentials, tokens, private keys, user data, exploit details, or unpatched vulnerabilities in public issues. Report security issues privately to the repository owner.

## Build security requirements

- Never commit source credentials, signing keys, deployment keys, or update-signing private keys.
- Keep the source-read token read-only and scoped to the single private source repository.
- Keep production secrets in the `sodfa-production` GitHub Environment with required approval and main-branch restrictions.
- Never expose secrets to untrusted pull-request workflows.
- Never publish Dart obfuscation symbols or private source build logs as artifacts.
- Do not enable OTA publishing until the app verifies a detached Ed25519 signature over the exact update-manifest bytes.
- Keep server-side authorization, rate limits, validation, and secure storage enforced on the server; mobile-client checks are not a security boundary.
