# Folio

A premium, local-first PDF reader that turns your PDFs into a calm personal
library. No account, no cloud library, no sync, no tracking.

* **Design system:** [`DESIGN.md`](DESIGN.md) (tokens live in `lib/core/theme/`)
* **Image assets:** [`ASSET_PROMPTS.md`](ASSET_PROMPTS.md); raw renders in
  `assets/source/`, processed by `tool/prepare_assets.py`

## Requirements

* Flutter **3.47.5** stable (Dart 3.13), the version Folio was built and tested with
* Android: Android Studio / SDK, a device or emulator on Android 7.0 (API 24) or newer
* iOS: Xcode 16+, iOS 13+
* Linux desktop (development and testing only): `libgtk-3-dev libsecret-1-dev`
  and a running Secret Service (e.g. gnome-keyring)

## Run

```bash
cd folio
flutter pub get
flutter run                 # picks a connected device / emulator
flutter run -d <device-id>  # or pick one explicitly
```

Build release artifacts:

```bash
flutter build apk --release        # Android APK
flutter build appbundle --release  # Play Store bundle (set your own signing key first)
flutter build ipa --release        # iOS (needs signing in Xcode)
```

Native libraries (PDFium, SQLite3 Multiple Ciphers) are downloaded by build
hooks the first time you build, so the first build needs network access.

## Test

```bash
flutter analyze
flutter test                                   # unit + PDF pipeline tests
FOLIO_LARGE_PDF=/path/to/big.pdf flutter test test/data/import_indexing_test.dart
```

Generate test PDFs, including a 1,200-page ~25 MB book:

```bash
pip install reportlab pillow
python3 tool/make_test_pdfs.py /tmp/folio-pdfs --large
```

## Regenerating assets

After replacing any render in `assets/source/`:

```bash
pip install pillow numpy scipy
python3 tool/prepare_assets.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Architecture

```
lib/
  app/          app widget, router (go_router), Riverpod providers
  core/
    db/         drift schema, encrypted connection (SQLite3 Multiple Ciphers)
    pdf/        library storage, PDFium metadata reader
    theme/      tokens, typography, app + reader themes, icons
    motion/     motion tokens (respect "reduce motion")
    utils/
  data/
    logic/      pure logic: streaks, FTS query building, reading tracker
    repositories/
    services/   import, indexing, notifications
  features/     one folder per screen area (home, library, book, reader, …)
  shared/       reusable widgets
```

* **PDF engine:** pdfrx (PDFium). Pages render lazily in tiles on PDFium's
  worker isolate; the whole PDF is never loaded into memory.
* **Storage:** each imported PDF is copied into app-private storage
  (`library/books/<sha256>.pdf`); duplicates are detected by content hash.
  Removing a book deletes only Folio's copy, never the original file.
* **Search:** page text is extracted once at import (in the background) into an
  SQLite FTS5 index. Searches never re-read the PDF.
* **Security:** the database is encrypted (SQLite3 Multiple Ciphers); its key is
  generated on first launch and kept in Android Keystore / iOS Keychain.
  Android cloud backup is disabled for app data.

## AI features

Explain / Summarize / Key points / Simplify / Define, Ask This Page, Ask This
Book and chapter summaries are wired into the UI but **off** until an AI
provider is configured. While off, every entry point explains why and links to
Settings → AI. No AI requests can be made in that state.
