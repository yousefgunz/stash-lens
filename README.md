# Stash Lens — Flutter app (Android + iOS)

A native mobile client for your Stash server. It talks to Stash's GraphQL API and streams video
straight from it, so nothing is wrapped in a WebView.

> This source was written without a Flutter SDK available, so it has not been compiled yet.
> Expect to fix a typo or two on the first `flutter run`.

## What's in it

- **Home** — Continue watching, Recently added, Highest rated, Something random
- **Scenes** — search, 7 sort modes, infinite scroll
- **People** — search, favourites filter, performer pages with their scenes
- **Scene page** — hero frame, resume button, star rating (saved to Stash), cast, tags
- **Player** — native `video_player`, double-tap ±10 s, speed menu, scrub bar, resume position
  and play duration written back to Stash every 10 s
- **Server** — change the server address / API key

## Build it

```bash
# 1. Generate the android/ and ios/ platform folders in this directory
flutter create --platforms=android,ios --org com.stashlens --project-name stash_lens .

# 2. Install packages
flutter pub get

# 3. Run on a connected device / emulator
flutter run
```

`flutter create .` leaves `lib/` and `pubspec.yaml` alone, so run it **before** anything else.

## Two required platform tweaks (Stash is plain HTTP on your LAN)

**Android** — `android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` and on `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application
    android:usesCleartextTraffic="true"
    ... >
```

**iOS** — `ios/Runner/Info.plist`, add inside the top-level `<dict>`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key><true/>
    <key>NSAllowsArbitraryLoads</key><true/>
</dict>
<key>NSLocalNetworkUsageDescription</key>
<string>Stash Lens connects to your Stash server on the local network.</string>
```

## Connecting

1. In Stash: **Settings → Security → API Key** (generate one if authentication is on).
2. Open the app, enter `http://<your-pc-ip>:9999` and the key.
3. The phone must reach that address — same Wi-Fi, or a VPN such as Tailscale/WireGuard.

## Notes

- Playback uses whatever Stash serves at `/scene/<id>/stream` (direct play). Formats a phone can't
  decode natively (some HEVC/MKV combos) may fail; transcoded streaming can be added by switching to
  the HLS stream URL.
- Library data comes from Stash's own GraphQL API rather than the SQLite file, because a phone
  can't read a database on your PC.

## iPhone without a Mac (free): GitHub Actions + Sideloadly

The workflow in `.github/workflows/ios.yml` builds an unsigned `.ipa` on a GitHub macOS machine.
It creates the `ios/` folder and applies the Info.plist keys itself, so you don't have to.

1. Create a **GitHub** repository and push this folder to it (GitHub Desktop is the easy way:
   File → Add local repository → Publish). A private repo is fine, but macOS build minutes are
   limited on the free plan; a public repo is free.
2. In the repo open **Actions → Build iOS (unsigned IPA) → Run workflow**. It takes ~5–10 minutes.
3. Open the finished run and download the **StashLens-ipa** artifact; unzip it to get `StashLens.ipa`.
4. On Windows install **iTunes** and **iCloud** from Apple's website (not the Microsoft Store
   versions), then install **Sideloadly** from sideloadly.io.
5. Plug in the iPhone, tap **Trust**, and enable **Settings → Privacy & Security → Developer Mode**
   (the phone restarts).
6. In Sideloadly drag in `StashLens.ipa`, enter your Apple ID, click **Start**.
7. On the phone: **Settings → General → VPN & Device Management →** your Apple ID **→ Trust**.
8. Open the app and allow the Local Network prompt.

A free Apple ID signature lasts **7 days**. Re-run Sideloadly with the same `.ipa` to renew it.
