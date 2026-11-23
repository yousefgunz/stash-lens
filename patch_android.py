"""Run once after `flutter create`: lets the Android app talk to Stash Lens over plain HTTP on your home network.

    python patch_android.py
"""
import pathlib
import re
import sys

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if not p.exists():
    sys.exit("android/app/src/main/AndroidManifest.xml not found. Run `flutter create` first, from this folder.")

s = p.read_text(encoding="utf-8")
changed = False

if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    changed = True

if "usesCleartextTraffic" not in s:
    s = re.sub(r"<application", '<application\n        android:usesCleartextTraffic="true"', s, count=1)
    changed = True

if "android.permission.USE_BIOMETRIC" not in s:
    s = s.replace("<application", '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>\n    <application', 1)
    changed = True

if changed:
    p.write_text(s, encoding="utf-8")
    print("Patched AndroidManifest.xml")
else:
    print("AndroidManifest.xml already patched")

# App lock (local_auth) needs a FragmentActivity.
for m in pathlib.Path("android/app/src/main").rglob("MainActivity.*"):
    t = m.read_text(encoding="utf-8")
    if "FlutterFragmentActivity" not in t and "FlutterActivity" in t:
        t = t.replace("import io.flutter.embedding.android.FlutterActivity", "import io.flutter.embedding.android.FlutterFragmentActivity")
        t = t.replace(": FlutterActivity()", ": FlutterFragmentActivity()").replace("extends FlutterActivity", "extends FlutterFragmentActivity")
        m.write_text(t, encoding="utf-8")
        print("Patched", m.name)

# ...and an AppCompat launch theme for the biometric dialog.
for st in pathlib.Path("android/app/src/main/res").glob("values*/styles.xml"):
    t = st.read_text(encoding="utf-8")
    n = re.sub(r'parent="@android:style/Theme\.(Light|Black)\.NoTitleBar"', 'parent="Theme.AppCompat.DayNight.NoActionBar"', t)
    if n != t:
        st.write_text(n, encoding="utf-8")
        print("Patched", st)

# Release builds shrink code with R8; keep the media player's native bridge.
rules = pathlib.Path("android/app/proguard-rules.pro")
rules.write_text("-keep class com.alexmercerind.** { *; }\n-keep class com.sun.jna.** { *; }\n-dontwarn com.alexmercerind.**\n", encoding="utf-8")
print("Wrote proguard-rules.pro")
