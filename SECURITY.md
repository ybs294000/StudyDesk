# Security Policy

## Supported Versions

StudyDesk is currently maintained on the active `main` branch. Security fixes are applied to the latest repository state rather than backported across multiple release lines.

## Reporting a Vulnerability

Please report security issues privately to the repository owner rather than opening a public issue with exploit details.

Include:

- affected screen, workflow, or file format
- reproduction steps
- expected impact
- platform used
- any logs or sample payloads needed to reproduce the issue safely

## Security Posture

StudyDesk follows these baseline security rules:

- study content remains local by default
- no provider credentials are bundled with the app
- no hidden network calls are part of normal study flows
- imports are validated before persistence
- native persistence uses SQLite with foreign keys enabled
- native startup performs SQLite integrity checks before normal app use

## Current Hardening Measures

The repository currently includes these defensive controls:

- import size limits for JSON, CSV, and Markdown files
- strict UTF-8 decoding for imported text assets
- top-level JSON object validation for StudyDesk import payloads
- normalized text sanitation before persistence for notes, Q&A items, decks, cards, quizzes, units, and subjects
- sanitized export filenames to avoid unsafe path characters
- SQLite startup checks using `PRAGMA quick_check` and `PRAGMA foreign_key_check`
- `WAL`, `busy_timeout`, and `secure_delete` configuration on native SQLite startup

## Current Limitations

StudyDesk is still a local-first desktop and mobile application in active development. It is not yet positioned as a hardened cloud service or a multi-user platform.

The following items remain future work:

- secure storage for bring-your-own-key AI credentials
- explicit certificate and network security configuration for release Android builds
- documented retention and deletion expectations for future AI request logs
- automated regression tests for malformed import payloads and corrupted persistence states

## AI Bring-Your-Own-Key Requirements

Any future AI integration must follow these rules:

- API keys must be user-supplied
- API keys must be stored in platform-appropriate secure storage, not in SQLite or plain preferences
- off-device submission must be explicit, user-triggered, and attributable to a selected provider
- StudyDesk must remain fully usable when AI is disabled or unconfigured

## What Must Not Be Committed

Do not commit:

- API keys
- signing keys or certificates
- local environment files with credentials
- personal study exports that are not intended as sample content
- private planning notes or internal assistant instructions
