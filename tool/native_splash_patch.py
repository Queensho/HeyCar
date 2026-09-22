from pathlib import Path
from PIL import Image

res = Path("android/app/src/main/res")
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "drawable-v21").mkdir(parents=True, exist_ok=True)
(res / "drawable-nodpi").mkdir(parents=True, exist_ok=True)
(res / "values-v31").mkdir(parents=True, exist_ok=True)

source = Image.open("assets/Logoqr.png").convert("RGBA")

# Pre-Android 12: full Cepqar wordmark, centered with comfortable breathing room.
wordmark = Image.new("RGBA", (600, 220), (0, 0, 0, 0))
logo = source.copy()
logo.thumbnail((500, 150), Image.Resampling.LANCZOS)
wordmark.alpha_composite(logo, ((wordmark.width-logo.width)//2, (wordmark.height-logo.height)//2))
wordmark.save(res / "drawable-nodpi" / "cepqar_splash_logo.png", optimize=True)

# Android 12+ constrains splash icons to a system safe area. Put the wordmark
# inside a transparent square so the complete Cepqar logo is never cropped.
icon = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
logo12 = source.copy()
logo12.thumbnail((250, 84), Image.Resampling.LANCZOS)
icon.alpha_composite(logo12, ((icon.width-logo12.width)//2, (icon.height-logo12.height)//2))
icon.save(res / "drawable-nodpi" / "cepqar_splash_icon.png", optimize=True)

launch = """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#07111F" />
        </shape>
    </item>
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/cepqar_splash_logo" />
    </item>
</layer-list>
"""

(res / "drawable" / "launch_background.xml").write_text(launch)
(res / "drawable-v21" / "launch_background.xml").write_text(launch)

v31 = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#07111F</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/cepqar_splash_icon</item>
        <item name="android:windowSplashScreenAnimationDuration">0</item>
        <item name="android:forceDarkAllowed">false</item>
        <item name="android:windowNoTitle">true</item>
    </style>
</resources>
"""
(res / "values-v31" / "styles.xml").write_text(v31)

print("Cepqar native wordmark splash applied")
