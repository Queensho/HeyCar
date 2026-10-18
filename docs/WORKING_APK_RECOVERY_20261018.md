# CepQontag working APK recovery — 2026-10-18

## Verified reference
- User-confirmed working APK: `CepQontag-Arac-Sahibi-2437.apk` (17 October 2026, user's working copy).
- Bytes: `261134967`.
- SHA-256: `ece0dbb4650e937443a9788beffe1ef7062bf25b221702f0c444bb85998bb278`.
- APK ZIP integrity: passes.
- Flutter app asset files: 18.

## Current PR201 debug APK
- Bytes: `253829243`.
- SHA-256: `0a29cc862fe7d2b82498197b1b93513741f43eae79e47ad3d3f9e5f8600e7f7d`.
- Flutter app asset files: 114; 96 extra vs working APK.

## Critical limitations
- This comparison **does not identify a source commit**.
- The absence of a Dart symbol or asset does not prove that source file did not exist.
- The working APK was not built reproducibly from the current repository during this investigation.
- Do not merge a guessed rollback to `main`, overwrite the known-good APK, or claim a new APK is identical without hash comparison.
- GitHub source snapshot safety branch: `safety/main-snapshot-before-apk-recovery-20261018`.

## Required next evidence
1. Identify the successful GitHub Actions run that generated the APK downloaded 17 Oct 2026 at ~15:43 Türkiye time, noting that file download time may not equal build time.
2. Capture the run's exact `head_sha`, workflow file and Flutter/Android build inputs.
3. Build from that SHA and compare package ID, version, signer, asset manifest and functionality with the reference APK.
4. Keep all work on recovery branches until user confirms on-device operation.

## Current status
**Exact source commit: NOT VERIFIED.**
