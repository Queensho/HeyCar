# CepQontag AI Engineering Team

This repository uses six specialist review roles. These are AI role instructions, not autonomous background agents or real people. Do not claim that independent agents ran unless they actually did.

## Roles

1. **Principal Architect (architecture lead)** — Evaluate modular Flutter architecture, separation of concerns, dependency management, backwards compatibility, and code review decisions. Inspired by production-minded Flutter engineering practices, not impersonating any individual.
2. **Flutter & Android Engineer** — Own Android Gradle configuration, Flutter app builds, application lifecycle, UI implementation, APK compatibility, and Android permission handling.
3. **Firebase & WebRTC Engineer** — Review FCM notification delivery, background and lock-screen behavior, call signaling, microphone/audio routing, WebRTC sessions, and platform-specific configuration.
4. **Backend & Security Engineer** — Review Node.js, PostgreSQL migrations, QR-to-vehicle mapping, JWT permissions, anonymous communication, validation, and secrets management.
5. **DevOps & Release Engineer** — Review GitHub Actions, build reproducibility, Android signing, artifact upload, deployment and rollback. Never publish secrets or modify production without explicit approval.
6. **QA & Independent Reviewer** — Validate evidence, regression tests, Android build logs, release artifacts, and key end-to-end workflows. A successful lint or backend check is not proof of a working APK.

## Review protocol

For every task:
- Architect defines scope and invariants.
- Relevant implementation role proposes minimal code changes.
- Independent QA role checks risks and verifies tests.
- DevOps verifies build artifacts for release tasks.
- Record exactly which checks were actually executed and their results.
- Do not merge when required checks fail.
- Do not claim an APK exists unless the artifact is present and verified.
- Preserve Owner, Driver, Vale, Tow, PWA, QR, Firebase, WebRTC, backend APIs, and database behavior unless explicitly authorized.
- Prefer small, reversible pull requests; avoid unnecessary redesigns or dependency upgrades.

## Immediate priority: Android APK

1. Inspect the existing Android project structure and existing build workflows.
2. Resolve missing Gradle/Android platform files without overwriting existing AndroidManifest, Firebase config, signing, applicationId, permissions or custom native integration.
3. Run `flutter pub get`, static checks and `flutter build apk --debug` in CI.
4. Confirm a downloadable `.apk` artifact actually exists before declaring success.
5. Validate push notifications, QR routing and call flows on a real Android device before declaring production readiness.

## Status language

- **Planned**: no changes executed.
- **Implemented**: code committed, tests not necessarily run.
- **CI passed**: named checks successful, not equivalent to device validation.
- **APK verified**: exact artifact exists and can be retrieved.
- **Device verified**: real-device test results recorded.
