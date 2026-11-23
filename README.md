# Stash Lens — mobile app (Android + iOS)

A native Flutter client for **Stash Lens**. It talks to your Stash Lens server (the Flask app), never to
Stash directly, so it shows exactly what the web app shows: same data, same hero rules, same filters.

> The Dart code passes the Dart parser but has not been compiled yet (no Flutter SDK was available
> where it was written). Expect to fix a typo or two on the first `flutter run`, and send the error.

## What's in it

| Area | Features |
|---|---|
| **Home** | Auto-rotating hero (custom hero images first, then top-rated), Continue watching, Performer of the day, On this day, Birthdays today, New from your favourites, Recently added, Top 10 most played, Highest rated, Performers you watch most, 8K / 6K / 4K rails, Browse by studio, Fan favourites, Browse by tag, Still unwatched, Feature length, Shuffle, library stats band |
| **Feed** | TikTok-style vertical feed: swipe up for the next scene, autoplays muted from a random point, filters (For you, Favourites, Unwatched, Top rated, New, 4K+), tap to pause, drag the bottom bar to seek, double-tap Fit/Fill, sound toggle, tap the avatar for the performer or Open for the scene page |
| **Scenes** | Search, 10 sort modes with direction, filters for resolution, 12 library flags, minimum rating, organized, release year, infinite scroll |
| **Performers** | Search by name or alias, sort (name, scenes, favourites, rating, age, height, shuffle), gender / country / minimum-scenes filters, favourites only |
| **Performer page** | Portrait, age, country, stats (scenes, plays, favourites, footage, size, active years), details, aliases, tags, top studios, most common tags, scenes-by-year chart, frequent co-stars, all their scenes with the full scene browser |
| **Browse** (More → Studios & tags) | Studios (search, sort, favourites) and Tags (heat-coloured, search, sort) |
| **Search** | One box over scenes, performers, studios and tags |
| **Scene page** | Hero frame, Play / Resume / Start over, file versions, cast with face-aware portraits, details, chapters (markers), tags, More like this, play and favourite history, file info (codec, bitrate, hashes, path), links |
| **Player** | libmpv engine (plays MKV, AVI, WMV, FLV, TS, HEVC, AV1, VP9, DivX …, hardware decoding with software fallback), double-tap ±10 s, scrub bar with chapter ticks and thumbnail preview, speed, chapters list, version switch, rotate lock, Up next + autoplay, resume, progress sent back to Stash Lens |
| **App lock** | Optional fingerprint / Face ID / phone PIN lock (More → App lock), locks on start and after leaving the app (immediately, 1 or 5 minutes), hides the screen in the app switcher |
| **Library** | Statistics dashboard (resolutions, ratings, years, months, codecs, genders, top lists) |
| **Library health** | Every health check with counts, tap to open the affected scenes, duplicate finder, missing-files check |

Ratings, play counts and the database are **read-only** from the phone, like the web app's own views.
Watching still saves your position locally and, if "Sync with Stash" is on in Stash Lens, back to Stash.

## 1. Make the Stash Lens server reachable from your phone

On the computer running Stash Lens, open its **Settings → Network access**, switch on
**Allow other computers on my network**, set an **access password**, and click **Apply**. It shows the
address to use, for example `http://192.168.1.20:8765`. The first time, Windows asks whether Python may use
the network: choose **Private networks**.

## 2. Android

```bat
cd C:\path\to\stash_lens_app
flutter create --platforms=android,ios --org com.stashlens --project-name stash_lens .
python patch_android.py
flutter pub get
flutter run                      :: phone plugged in with USB debugging, or an emulator
flutter build apk --release      :: APK at build\app\outputs\flutter-apk\app-release.apk
```

`patch_android.py` adds the INTERNET permission and `usesCleartextTraffic` to the manifest (needed
because Stash Lens is plain HTTP on your LAN).

If Gradle says *"this and base files have different roots"*, keep the project and Flutter's caches on the
same drive: `setx PUB_CACHE A:\pub_cache` and `setx GRADLE_USER_HOME A:\gradle_home`, open a new
terminal, `flutter clean`, then build again.

## 3. iPhone without a Mac (free): GitHub Actions + Sideloadly

`.github/workflows/ios.yml` builds an unsigned `.ipa` on a GitHub macOS machine. It creates the `ios/`
folder and adds the local-network permissions itself.

1. Put this folder in a **public** GitHub repository.
2. **Actions → Build iOS (unsigned IPA) → Run workflow** (5–10 minutes).
3. Download the **StashLens-ipa** artifact and unzip it to get `StashLens.ipa`.
4. On Windows install **iTunes** and **iCloud** from Apple's website (not the Microsoft Store), then
   **Sideloadly** from sideloadly.io.
5. Connect the iPhone (USB-C iPhones need a USB-C to USB-A cable or adapter for an older PC), tap
   **Trust**, and enable **Settings → Privacy & Security → Developer Mode**.
6. Drag `StashLens.ipa` into Sideloadly, sign in with your Apple ID, **Start**.
7. On the phone: **Settings → General → VPN & Device Management →** your Apple ID **→ Trust**.
8. Open the app, allow the Local Network prompt, enter the address and password from step 1.

A free Apple ID signature lasts **7 days**. Run Sideloadly again with the same `.ipa` to renew it.

## Notes

- Playback streams the original file from `/api/stream/<id>`. The player uses libmpv, so it handles
  nearly every format and falls back to software decoding when the phone's hardware can't. Very heavy files
  (8K, high-bitrate AV1 on an older phone) may stutter in software. If a file won't open, the player says
  so, and the scene page's version picker can switch to another file when a scene has several.
- Release APK size grows by ~20 MB per architecture because of the player engine; `flutter build apk --release --split-per-abi` makes smaller per-phone files.
- Images and video send the access password as an HTTP Basic header, exactly like the browser does.
- Watch progress for "Continue watching" is also stored on the phone, so it works even with sync off.
