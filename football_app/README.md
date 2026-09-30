# Touchline — football command center

Flutter app: live scores, Match Center (overview, commentary, stats, lineups, pitch, players, H2H), briefing/recap, player & team profiles, league centre, transfers, search, favourites, local notifications and shareable graphics.

## Run
```bash
flutter pub get
# Real data (API-Football v3, https://www.api-football.com):
flutter run --dart-define=API_FOOTBALL_KEY=your_key
# No key in a debug build → fictional demo data (DEMO badge everywhere).
flutter run
flutter test        # unit tests: data layer, cache/offline, form, "What just happened?", diffs, search
flutter analyze
```
Release builds never contain demo data; without a key they show an "API key needed" state.

## Architecture
```
lib/
  app/        env, router, providers (Riverpod), settings, favourites, polling, personalisation
  core/       theme tokens (tokens.dart, app_theme.dart), design-system widgets, cache, HTTP client, request budget, fuzzy search
  data/       models (provider-agnostic), FootballRepository interface,
              api_football/ (parser + repository), demo/ (debug-only fictional universe)
  domain/     pure logic: form, catch-up summariser, match diff (alerts), commentary, zones/H2H/stat explanations
  features/   home, matches, match (7 tabs + briefing/recap), player, compare, team, league, search,
              transfers, notifications (watcher + inbox), profile/settings, onboarding, share, shell
```
Swap providers by implementing `FootballRepository` and returning it from `repositoryProvider` — no UI changes.

## Data rules
- Labels: CONFIRMED / REPORTED / PREDICTED / APP-GENERATED / DEMO (`ProvenanceTag`).
- Missing stats are hidden or marked "not provided by <provider>" — never estimated.
- Offline: cached responses (Hive) are served as last-known state with a "may be delayed" banner.
- Free tier (100 req/day): one `live=all` call feeds every live surface; match detail is one `fixtures?id=` call; polling interval adapts to remaining quota and pauses near the limit (`RequestBudget`).
