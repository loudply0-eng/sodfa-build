# Security Policy

## Supported release

Security fixes are prioritized for the latest stable SODFA Android release.

## Reporting a vulnerability

Do not publish exploit details, credentials, access tokens, private keys, personal data, or an unpatched vulnerability in a public issue. Contact the project maintainer privately through the repository's private contact channel and include:
- affected release/build and component;
- impact and realistic reproduction steps;
- proof-of-concept only when it does not access another person's data or disrupt service.

## Security design requirements

- Treat every mobile client as untrusted. Never embed server credentials, database passwords, signing keys, or privileged API secrets in the APK.
- Enforce authorization on the server for every user, post, conversation, message, and media object. Client-side checks are not security boundaries.
- Require HTTPS/WSS in production; do not enable cleartext traffic in release builds.
- Store session credentials only in platform-backed secure storage. Never log tokens, passwords, verification codes, or message contents.
- Rotate refresh tokens, detect refresh-token reuse, revoke sessions on logout/password reset, and rate-limit authentication and verification endpoints.
- Keep signing and deployment private keys in GitHub Actions secrets. Never commit them or print them in workflow logs.
- Keep Dart obfuscation symbol files private; they can reverse obfuscation and must not be included in public release artifacts.
- Validate uploaded files by content, size, and type; store user media outside the executable web root and serve it with safe content headers.
- Back up production data, restrict database/network access, use least-privilege service accounts, and require MFA for infrastructure administration.

## Important limitations

Obfuscation raises the cost of reverse engineering but does not prevent APK extraction or copying. HTTPS and client-side validation do not replace server-side authorization, rate limits, or input validation.

The current message API accepts encrypted-looking payload fields, but that alone does not prove end-to-end encryption. Do not advertise end-to-end encryption until a reviewed client-side cryptographic protocol, key verification, and safe key lifecycle are implemented.
