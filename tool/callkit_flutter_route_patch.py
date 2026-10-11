#!/usr/bin/env python3
"""Keep Android CallKit notifications while routing their UI into Flutter.

The third-party plugin unconditionally attaches a PendingIntent to its generic
CallkitIncomingActivity even when AndroidParams.isFullScreen=false. On Xiaomi
this brings the gray-circle native activity to the front and masks CepQontag's
OwnerCallPage. Build-time patch only; no changes to WebRTC or call signaling.
"""
from pathlib import Path


OLD_BLOCK = """        notificationBuilder?.setFullScreenIntent(
            getActivityPendingIntent(notificationId, data), true
        )
        notificationBuilder?.setContentIntent(getActivityPendingIntent(notificationId, data))"""

NEW_BLOCK = """        // Retain the system call notification and full-screen intent for
        // supported locked devices, but always open the branded Flutter route
        // rather than the plugin's unbranded native incoming-call Activity.
        // Existing accept/decline PendingIntents and ringtone remain unchanged.
        notificationBuilder?.setFullScreenIntent(
            getAppPendingIntent(notificationId, data), true
        )
        notificationBuilder?.setContentIntent(getAppPendingIntent(notificationId, data))"""


def patch_source(source: str) -> str:
    if NEW_BLOCK in source:
        return source
    if source.count(OLD_BLOCK) != 1:
        raise ValueError("CallKit notification source changed; cannot safely patch")
    return source.replace(OLD_BLOCK, NEW_BLOCK, 1)


def main() -> None:
    matches = sorted(
        Path.home().glob(
            ".pub-cache/hosted/pub.dev/flutter_callkit_incoming-*/android/src/main/kotlin/"
            "com/hiennv/flutter_callkit_incoming/CallkitNotificationManager.kt"
        )
    )
    if not matches:
        raise SystemExit("CallkitNotificationManager.kt not found in pub cache")
    source = matches[-1]
    original = source.read_text(encoding="utf-8")
    try:
        updated = patch_source(original)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
    if original != updated:
        source.write_text(updated, encoding="utf-8")
    print(f"CepQontag native call screen prevented; Flutter route retained: {source}")


if __name__ == "__main__":
    main()
