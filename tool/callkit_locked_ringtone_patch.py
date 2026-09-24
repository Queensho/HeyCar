from pathlib import Path

sound_candidates = sorted(
    Path.home().glob(
        ".pub-cache/hosted/pub.dev/flutter_callkit_incoming-*/android/src/main/kotlin/"
        "com/hiennv/flutter_callkit_incoming/CallkitSoundPlayerManager.kt"
    )
)
if not sound_candidates:
    raise SystemExit("flutter_callkit_incoming CallkitSoundPlayerManager.kt not found")

p = sound_candidates[-1]
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
    """    private var ringtone: Ringtone? = null
    private var mediaPlayer: MediaPlayer? = null
    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { }
    private var previousAudioMode: Int? = null

    private fun requestRingtoneAudioFocus() {
        try {
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            previousAudioMode = audioManager?.mode
            audioManager?.mode = AudioManager.MODE_RINGTONE
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(
                audioFocusListener,
                AudioManager.STREAM_RING,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseRingtoneAudioFocus() {
        try {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(audioFocusListener)
            val previous = previousAudioMode
            if (previous != null && audioManager?.mode == AudioManager.MODE_RINGTONE) {
                audioManager?.mode = previous
            }
        } catch (_: Exception) {
        } finally {
            previousAudioMode = null
        }
    }
""",
    "MediaPlayer and audio focus fields",
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
            // Xiaomi/HyperOS may emit ACTION_SCREEN_OFF again while the incoming
            // full-screen activity is being presented. Do not stop the ringtone here.
            // Accept/decline, timeout and explicit call end already stop playback.
        }
    }""",
    "locked-screen screen-off guard",
)

stop_old = """        ringtone?.stop()
        vibrator?.cancel()
        ringtone = null
        vibrator = null"""
stop_new = """        ringtone?.stop()
        try { mediaPlayer?.stop() } catch (_: Exception) {}
        mediaPlayer?.release()
        releaseRingtoneAudioFocus()
        vibrator?.cancel()
        ringtone = null
        mediaPlayer = null
        vibrator = null"""
replace_once(stop_old, stop_new, "stop MediaPlayer and focus")
replace_once(stop_old, stop_new, "destroy MediaPlayer and focus")

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
        releaseRingtoneAudioFocus()
        vibrator?.cancel()
    }""",
    "prepare MediaPlayer and focus",
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

        requestRingtoneAudioFocus()

        // Prefer the packaged Cepqar ringtone under res/raw and loop it using
        // STREAM_RING. Keep RingtoneManager as a fallback for OEM-specific cases.
        if (sound.isNotEmpty() && !sound.equals("system_ringtone_default", true)) {
            val resId = context.resources.getIdentifier(sound, "raw", context.packageName)
            if (resId != 0) {
                val rawUri = Uri.parse("android.resource://\${context.packageName}/$resId")
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
                        setVolume(1.0f, 1.0f)
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

replace_once(old_play, new_play, "wake-lock ringtone player with ring audio focus")
p.write_text(text, encoding="utf-8")
print(f"Cepqar CallKit ringtone patch applied: {p}")

notification_candidates = sorted(
    Path.home().glob(
        ".pub-cache/hosted/pub.dev/flutter_callkit_incoming-*/android/src/main/kotlin/"
        "com/hiennv/flutter_callkit_incoming/CallkitNotificationManager.kt"
    )
)
if not notification_candidates:
    raise SystemExit("flutter_callkit_incoming CallkitNotificationManager.kt not found")

np = notification_candidates[-1]
notification_text = np.read_text(encoding="utf-8")
old_channel = 'const val NOTIFICATION_CHANNEL_ID_INCOMING = "callkit_incoming_channel_id_v2"'
new_channel = 'const val NOTIFICATION_CHANNEL_ID_INCOMING = "cepqar_callkit_incoming_channel_v7"'
if old_channel in notification_text:
    notification_text = notification_text.replace(old_channel, new_channel, 1)
    np.write_text(notification_text, encoding="utf-8")
    print(f"Fresh Cepqar CallKit channel id applied: {np}")
elif new_channel in notification_text:
    print("Fresh Cepqar CallKit channel id: already patched")
else:
    raise SystemExit(f"Incoming CallKit channel id block not found in {np}")
