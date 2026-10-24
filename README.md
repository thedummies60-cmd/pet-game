# Pet Arena

Pet Arena is a pet game for Android. Each themed version is a separate app with its own logo,
so they can all be installed side by side.

| APK | Version | Logo |
|-----|---------|------|
| [`apk/PetArena.apk`](apk/PetArena.apk) | Standard (`Pet_Arena98.html`) | Schattige Pet Arena-hondenmascotte |
| [`apk/PetArena-Halloween.apk`](apk/PetArena-Halloween.apk) | Halloween | Halloweense Pet Arena-logo |
| [`apk/PetArena-Thanksgiving.apk`](apk/PetArena-Thanksgiving.apk) | Thanksgiving | Herfstige Kalkoen Pet Arena-logo |
| [`apk/PetArena-Kerst.apk`](apk/PetArena-Kerst.apk) | Kerst | Sneeuwman in de Pet Arena |

## Installing

Download an `.apk` on your Android phone (Android 5.0 or newer), open it and allow
"install unknown apps" when asked.

## Building

```sh
sudo apt-get install aapt apksigner zipalign android-sdk-platform-23 dalvik-exchange imagemagick openjdk-17-jdk
./android/build.sh
```

The APKs land in `apk/`. GitHub Actions (`.github/workflows/android.yml`) builds them on every
push; pushing a tag like `v1.0` also attaches them to a GitHub release.

The apps are signed with `android/petarena.keystore` (password `petarena`) so updates install
over older versions. It is a public key — make your own private one before publishing to the
Play Store.
