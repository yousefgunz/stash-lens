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

if changed:
    p.write_text(s, encoding="utf-8")
    print("Patched AndroidManifest.xml")
else:
    print("AndroidManifest.xml already patched")
