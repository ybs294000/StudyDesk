# Contributing to StudyDesk

Thanks for contributing. This repository is still in active product shaping, so the most helpful contributions are the ones that keep the codebase clearer, more honest, and more production-ready.

## Ground Rules

- Keep user-facing behavior concrete. Avoid stub features presented as finished work.
- Prefer small, reviewable changes over large speculative rewrites.
- Keep docs aligned with implementation.
- Do not commit secrets, tokens, private keys, or generated machine-local files.

## Project Structure

Most work happens inside [`flutter_app`](./flutter_app/). Supporting product and engineering docs live in [`docs`](./docs/).

## Local Setup

```powershell
cd flutter_app
flutter pub get
```

Typical local commands:

```powershell
flutter test
flutter analyze
flutter run -d chrome
```

## Branch Naming

Use short-lived branches with clear intent:

- `feat/quiz-engine`
- `fix/web-persistence`
- `docs/readme-refresh`
- `chore/dependency-updates`

## Commit Style

Conventional-style commits are preferred:

- `feat: add deck import validation`
- `fix: use web-safe study session repository`
- `docs: rewrite repository readme`
- `test: cover scheduler interval transitions`

## Coding Expectations

- Follow the feature-first structure already in place
- Use Riverpod consistently for state
- Keep platform differences explicit and testable
- Prefer portable data models and migrations over throwaway shortcuts
- Update or add docs when behavior or architecture changes materially

## Documentation Expectations

If you change architecture, public behavior, storage, or data format, update the relevant docs:

- `README.md`
- `CHANGELOG.md`
- `docs/ARCHITECTURE.md`
- `docs/DATABASE_SCHEMA.md`
- `docs/JSON_FORMAT_SPEC.md`
- `docs/PROJECT_STATUS.md`

## Pull Request Checklist

Before opening a PR, make sure:

- The change has a clear user or engineering purpose
- Docs are updated if the change affects behavior or architecture
- New code is not pretending incomplete work is complete
- Tests are added or updated where practical
- Generated and ephemeral files are not included unintentionally

## Scope Notes

StudyDesk is intentionally local-first and avoids accidental backend scope. If a change introduces accounts, cloud sync, background network jobs, or app-owned AI secrets, it should be treated as a major design change and documented first.
