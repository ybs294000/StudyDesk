# Security Policy

## Supported Versions

StudyDesk is in active alpha development. Security fixes are applied on the active mainline rather than through backports to multiple maintained versions.

## Reporting a Vulnerability

If you discover a security issue, please report it privately to the maintainer instead of opening a public issue with exploit details.

Include:

- A clear description of the issue
- Affected files, screens, or features
- Reproduction steps
- Expected impact
- Any suggested mitigation if you have one

Until a dedicated security contact or disclosure channel is published, use the repository owner contact path associated with the Git hosting profile.

## Security Principles for This Repo

- No hardcoded API keys, signing secrets, or service credentials
- User study data should remain local by default
- AI integrations must be explicit and opt-in
- HTTPS-only for future network features
- Sensitive settings belong in secure device storage when implemented
- Dependencies and platform configuration should be kept current enough for store compliance

## Current Caveats

- The app is not release-ready yet
- Some planned hardening work is still open
- Web support exists for development/testing convenience, but Android-first release quality remains the primary target

## What Not to Commit

Do not commit:

- `.env` files with real credentials
- API keys
- private certificates or signing keys
- exported personal study data that is not intended as sample content

## Security-Related Future Work

- Secure storage for BYOK AI credentials
- Network security configuration for Android release builds
- Privacy-policy-ready data inventory
- Release checklist for Play Store readiness
