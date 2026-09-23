from pathlib import Path

candidates = sorted(
    Path.home().glob(
        ".pub-cache/hosted/pub.dev/flutter_callkit_incoming-*/android/src/main/kotlin/"
        "com/hiennv/flutter_callkit_incoming/CallkitSoundPlayerManager.kt"
    )
)
if not candidates:
    raise SystemExit("flutter_callkit_incoming CallkitSoundPlayerManager.kt not found")

p = candidates[-1]
text = p.read_text(encoding="utf-8")

def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        if new in text:
            print(f"{label}: already patched")
            return
        raise SystemExit(f"{label}: expected source block not found in {p}")
    text = text.replace(old, new, 1)
    print(f"{label}: patched")

replace_once(
    "import android.media.AudioManager\nimport android.media.Ringtone",
    "import android.media.AudioManager\nimport android.media.MediaPlayer\nimport android.media.Ringtone",
    "MediaPlayer import",
)
replace_once(
    "import android.os.Bundle\nimport android.os.VibrationEffect",
    "import android.os.Bundle\nimport android.os.PowerManager\nimport android.os.VibrationEffect",
    "PowerManager import",
)
replace_once(
    "    private var ringtone: Ringtone? = null\n",
    "    private var ringtone: Ringtone? = null\n    private var mediaPlayer: MediaPlayer? = null\n",
    "MediaPlayer field",
)

replace_once(
"""    inner class ScreenOffCallkitIncomingBroadcastReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (isPlaying && !keepRingingForFullScreenIntent) {
                stop()
            }
        }
    }""",
"""    inner class ScreenOffCallkitIncomingBroadcastReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            // Some OEMs (notably Xiaomi/HyperOS) emit ACTION_SCREEN_OFF again while
            // presenting a full-screen incoming-call activity. Stopping here can mute
            // the ringtone immediately on an already locked device. Accept/decline,
            // timeout and explicit call end already stop the player, so keep ringing.
        }
    }""",
    "locked-screen screen-off guard",
)

replace_once(
"""        ringtone?.stop()
        vibrator?.cancel()
        ringtone = null
        vibrator = null""",
"""        ringtone?.stop()
        try { mediaPlayer?.stop() } catch (_: Exception) {}
        mediaPlayer?.release()
        vibrator?.cancel()
        ringtone = null
        mediaPlayer = null
        vibrator = null""",
    "stop MediaPlayer",
)

replace_once(
"""        ringtone?.stop()
        vibrator?.cancel()
        ringtone = null
        vibrator = null""",
"""        ringtone?.stop()
        try { mediaPlayer?.stop() } catch (_: Exception) {}
        mediaPlayer?.release()
        vibrator?.cancel()
        ringtone = null
        mediaPlayer = null
        vibrator = null""",
    "destroy MediaPlayer",
)

replace_once(
"""    private fun prepare() {
        ringtone?.stop()
        vibrator?.cancel()
    }""",
"""    private fun prepare() {
        ringtone?.stop()
        try { mediaPlayer?.stop() } catch (_: Exception) {}
        mediaPlayer?.release()
        mediaPlayer = null
        vibrator?.cancel()
    }""",
    "prepare MediaPlayer",
)

old_play = """    private fun playSound(data: Bundle?) {
        val sound = data?.getString(
            CallkitConstants.EXTRA_CALLKIT_RINGTONE_PATH,
            ""
        )
        val uri = sound?.let { getRingtoneUri(it) }
        if (uri == null) {
            // Failed to get ringtone url, can't play sound
            return
        }
        try {
            ringtone = RingtoneManager.getRingtone(context, uri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val attribution = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setLegacyStreamType(AudioManager.STREAM_RING)
                    .build()
                ringtone?.setAudioAttributes(attribution)
            } else {
                ringtone?.streamType = AudioManager.STREAM_RING
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }
            ringtone?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }"""

new_play = """    private fun playSound(data: Bundle?) {
        val sound = data?.getString(
            CallkitConstants.EXTRA_CALLKIT_RINGTONE_PATH,
            ""
        )?.trim().orEmpty()

        // Cepqar ships its own ringtone under res/raw. Prefer MediaPlayer for app
        // resources so we can hold a partial wake lock while the screen is locked.
        // The plugin's RingtoneManager path remains as a fallback for system tones.
        if (sound.isNotEmpty() && !sound.equals("system_ringtone_default", true)) {
            val resId = context.resources.getIdentifier(sound, "raw", context.packageName)
            if (resId != 0) {
                val rawUri = Uri.parse("android.resource://${context.packageName}/$resId")
                try {
                    mediaPlayer = MediaPlayer().apply {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                                    .setLegacyStreamType(AudioManager.STREAM_RING)
                                    .build()
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            setAudioStreamType(AudioManager.STREAM_RING)
                        }
                        setWakeMode(context, PowerManager.PARTIAL_WAKE_LOCK)
                        setDataSource(context, rawUri)
                        isLooping = true
                        prepare()
                        start()
                    }
                    if (mediaPlayer?.isPlaying == true) return
                    mediaPlayer?.release()
                    mediaPlayer = null
                } catch (e: Exception) {
                    e.printStackTrace()
                    try { mediaPlayer?.release() } catch (_: Exception) {}
                    mediaPlayer = null
                }
            }
        }

        val uri = if (sound.isEmpty()) getDefaultRingtoneUri() else getRingtoneUri(sound)
        if (uri == null) return
        try {
            ringtone = RingtoneManager.getRingtone(context, uri)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val attribution = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setLegacyStreamType(AudioManager.STREAM_RING)
                    .build()
                ringtone?.setAudioAttributes(attribution)
            } else {
                ringtone?.streamType = AudioManager.STREAM_RING
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }
            ringtone?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }"""

replace_once(old_play, new_play, "wake-lock ringtone player")
p.write_text(text, encoding="utf-8")
print(f"Cepqar CallKit ringtone patch applied: {p}")
