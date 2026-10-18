package com.example.heycar_app

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.cepqar.app/system_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            try {
                val opened = when (call.method) {
                    "openAutoStart" -> openFirstAvailable(
                        Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
                        Intent("miui.intent.action.OP_AUTO_START"),
                        appDetailsIntent()
                    )
                    "openMiuiPermissions" -> openFirstAvailable(
                        Intent("miui.intent.action.APP_PERM_EDITOR").setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity").putExtra("extra_pkgname", packageName),
                        Intent("miui.intent.action.APP_PERM_EDITOR").setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.AppPermissionsEditorActivity").putExtra("extra_pkgname", packageName),
                        appDetailsIntent()
                    )
                    "openBatterySettings" -> openFirstAvailable(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS) else Intent(Settings.ACTION_SETTINGS),
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
                        appDetailsIntent()
                    )
                    "openAppDetails" -> openFirstAvailable(appDetailsIntent())
                    "openNotificationSettings" -> openFirstAvailable(
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                        appDetailsIntent()
                    )
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }
                if (opened) result.success(true)
                else result.error("SETTINGS_UNAVAILABLE", "No supported settings activity", null)
            } catch (error: Exception) {
                result.error("SETTINGS_OPEN_FAILED", error.message, null)
            }
        }
    }

    private fun appDetailsIntent() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))

    private fun openFirstAvailable(vararg intents: Intent): Boolean {
        for (intent in intents) {
            try {
                startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: ActivityNotFoundException) {
                // Try the next available Android settings screen.
            } catch (_: SecurityException) {
                // Some OEM settings screens are not exported.
            }
        }
        return false
    }
}
