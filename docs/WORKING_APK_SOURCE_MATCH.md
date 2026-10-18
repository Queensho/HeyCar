# Working APK source verification — 18 October 2026

## Reference APK
- File: `CepQontag-Arac-Sahibi-2437.apk` (user-confirmed working)
- SHA-256: `ece0dbb4650e937443a9788beffe1ef7062bf25b221702f0c444bb85998bb278`
- Flutter debug kernel: `assets/flutter_assets/kernel_blob.bin`; includes original Dart source text.

## Exact source matches
- `lib/owner_home_redesign.dart`: Extracted original Dart text from APK kernel; Git blob SHA-1 **`3b674714b4ea2c6ea815f5ef84d1e60f9e9f8fbf`**. This recovery branch contains the **exact matching blob**, verified after replacing the sole PR42 difference `assets/Qrkod.png` with `assets/CepqarQr.png`.
- `lib/weather_card.dart`: Extracted APK source Git blob SHA-1 **`79df7512b3f34824c470596a915f6ce373e99837`**, exactly matches PR42's GitHub blob.

## Source candidate
- PR #42 commit: `4d3a1c73eecf32a3b0ab1d36c877fc2dd0d58037`
- This branch was forked from PR42; one owner home QR asset reference was corrected to match the working APK.

## Critical limitations
- Other source files, including `owner_chat_page.dart`, `parking_location_card.dart`, `owner_login.dart`, do not yet have matching blob hashes against PR42.
- Therefore the **exact original APK source commit remains unverified**. It may have been built from a different branch or a working tree with uncommitted edits.
- A matching source file does **not** guarantee reproducible APK signing, applicationId, versionCode, Android manifest, Gradle config, plugin set, or backend behavior.
- **Do not merge this recovery branch to main or deploy it as working production code until further comparison and on-device verification.**
- Do not delete or overwrite the known-good APK.
