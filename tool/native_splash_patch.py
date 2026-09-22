from pathlib import Path

res = Path("android/app/src/main/res")
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "drawable-v21").mkdir(parents=True, exist_ok=True)
(res / "values-v31").mkdir(parents=True, exist_ok=True)

launch = """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="#07111F" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@mipmap/ic_launcher" />
    </item>
</layer-list>
"""

(res / "drawable" / "launch_background.xml").write_text(launch)
(res / "drawable-v21" / "launch_background.xml").write_text(launch)

v31 = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#07111F</item>
        <item name="android:windowSplashScreenAnimatedIcon">@mipmap/ic_launcher</item>
        <item name="android:windowSplashScreenAnimationDuration">0</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:windowNoTitle">true</item>
    </style>
</resources>
"""
(res / "values-v31" / "styles.xml").write_text(v31)

print("Cepqar native splash applied")
