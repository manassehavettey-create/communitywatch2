# Bible

An offline-first Flutter app for reading, study, saving, prayer and journaling.

Scripture is bundled with the app, so reading, search, highlights, notes, the
journal and prayer all work with no connection. Signing in is optional; it
syncs your data through Supabase.

- Design language: [`DESIGN.md`](DESIGN.md)
- Bible text pipeline and licences: [`tools/bible_data/README.md`](tools/bible_data/README.md)
- Image assets: [`docs/IMAGE_ASSETS.md`](docs/IMAGE_ASSETS.md) and
  [`docs/IMAGE_ASSETS_STATUS.md`](docs/IMAGE_ASSETS_STATUS.md)

## Requirements

- Flutter 3.47 (stable) with Dart 3.13
- Android: Android Studio or the Android SDK (API 34+), JDK 17
- iOS: Xcode 16+ and CocoaPods

## Run it

```sh
cd bible_app
flutter pub get
flutter run                      # local-only: no account or sync
```

To turn on accounts and sync, copy the config template and fill it in:

```sh
cp env/config.example.json env/config.json      # gitignored
flutter run --dart-define-from-file=env/config.json
```

| Key | What it is |
|---|---|
| `SUPABASE_URL` | Project URL, e.g. `https://abcd.supabase.co` |
| `SUPABASE_ANON_KEY` | The project's anon (or publishable) key. Never the service-role key. |
| `GOOGLE_WEB_CLIENT_ID` | OAuth *Web* client id (also configured in Supabase → Auth → Google) |
| `GOOGLE_IOS_CLIENT_ID` | OAuth *iOS* client id (iOS only) |
| `AUTH_REDIRECT_URL` | Deep link for email confirmation and password reset. The default is `app.scripture.bibleapp://auth-callback`. |

If any key is missing, the app runs in local-only mode. Everything is still
saved on the device, and the account screens say that accounts aren't set up.

### Web

```sh
flutter build web --release --no-web-resources-cdn
```

The web build keeps its database in the browser with drift and SQLite
compiled to WebAssembly. It needs two files in `web/`, both committed:

- `sqlite3.wasm`: from the matching `sqlite3` package release.
- `drift_worker.js`: rebuild it with
  `dart compile js -O2 -o web/drift_worker.js tools/web/drift_worker.dart`.

Notifications and installed translations are phone-only.

## Supabase setup

> Nothing has been run against a live project. The plan is to ask for your
> go-ahead first and then give you the exact commands.

1. **Schema:** run `supabase/migrations/20260928120000_initial_schema.sql`.
   It creates the user tables, keyed by `(user_id, id)`, with row-level
   security on every user table. It also adds a last-write-wins trigger, a
   `streaks` view, profiles, and a `delete_my_account()` function.
2. **Reference data:** run `supabase/seed.sql`. It inserts the reading plans
   and prayer categories and is safe to re-run.
3. **Auth → Providers:** enable Email. Enable Google and give it the Web
   client id and secret.
4. **Auth → URL configuration:** add `app.scripture.bibleapp://auth-callback`
   to the redirect URLs.

With the Supabase CLI, steps 1 and 2 are `supabase link --project-ref <ref>`,
then `supabase db push`, then `psql "$DATABASE_URL" -f supabase/seed.sql`.

### Google sign-in

- **Web client:** create one in Google Cloud. It goes in
  `GOOGLE_WEB_CLIENT_ID` and in Supabase's Google provider.
- **Android client:** create one with the package name
  `app.scripture.bible_app` and your signing certificate's SHA-1 fingerprint.
  No key goes in the app.
- **iOS client:** create one, put its id in `GOOGLE_IOS_CLIENT_ID`, and add
  its **reversed** client id as a URL scheme in `ios/Runner/Info.plist`. A
  commented slot marks the place.

## How sync works

- **Local copy:** the device database is the working copy. Every change
  records the row in an outbox, in the same transaction as the change.
- **When it syncs:** after changes (debounced), when the connection returns,
  when the app resumes, and every 5 minutes. Failures back off from 5 seconds
  up to 5 minutes.
- **Order:** each pass pulls, then pushes. Pulling first means an edit made
  offline on two devices is noticed before either overwrites the other.
- **Conflicts:** the newer edit wins. For notes, journal entries and prayers,
  the other version is kept as a "conflict copy", so no writing is lost.
- **Deletes:** deleting marks the row deleted, and that mark syncs.
- **Signing in:** anything written while signed out is attached to the
  account.
- **Signing out:** the account's data is removed from the device.
- **Deleting the account:** removes everything on the server, via cascading
  deletes.

## Tools

| Tool | Purpose |
|---|---|
| `tools/bible_data/build_bible_data.py`, `verify_bible_data.py` | Build and verify the bundled translations |
| `tools/bible_data/gen_dart_canon.py` | Regenerate `lib/bible/canon_data.dart` |
| `tools/plans/generate_plans.py` | Regenerate `assets/plans/plans.json` and `supabase/seed.sql` |
| `tools/images/process_assets.py` | Crop the generated artwork and cut its painted checkerboards |
| `tools/icons/gen_icons.py` | Regenerate `lib/core/icons.dart` (Phosphor icons in use) |
| `dart run flutter_launcher_icons` / `dart run flutter_native_splash:create` | App icon and splash |
| `dart run build_runner build` | Regenerate drift code after changing `lib/data/db/tables.dart` |

## Tests

```sh
flutter analyze
flutter test
python3 tools/bible_data/verify_bible_data.py
```

## Code layout

```
lib/
  app/         providers, router, shell (tab bar), account wiring, debug-only demo data
  bible/       Scripture content layer (no UI): canon, references, parser,
               translation loading, search index
  core/        theme tokens, typography, motion, shared widgets, icons, config
  data/        drift database, repositories, sync engine, Supabase adapter,
               auth, reminders
  domain/      pure logic: days, streaks, plan progress
  features/    one folder per screen area (reader, home, plans, prayer, ...)
```

## Release checklist

- Replace the debug signing config in `android/app/build.gradle.kts` with a
  release keystore.
- Pick the final app name. Update the application id and bundle id
  (currently `app.scripture.bible_app`), the display name ("Bible"), and the
  auth deep-link scheme in both manifests.
- **Apple sign-in:** if you ship Google sign-in on iOS, App Store guideline
  4.8 also requires Sign in with Apple.
