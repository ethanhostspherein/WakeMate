# WakeMate

**Never miss your stop.** WakeMate is a location-based smart alarm designed for travellers who fall asleep on trains, buses, cabs, or metros. Unlike traditional time-based alarms, WakeMate continuously tracks live GPS position against a chosen destination and fires a loud, unmissable alarm when you enter your arrival radius — even with the screen locked, the app backgrounded, or battery-saver active.

Built India-first: destination alarms today, with PNR-linked train tracking, regional-language alerts, family arrival notifications, and live ETA sharing.

---

## Key Features

- **Location-Based Smart Alarms**: Distance-based (e.g., wake within 2 km) or time-based (e.g., wake 15 mins before arrival) alarms.
- **Reliable Background Tracking**: Android persistent foreground service with adaptive polling (coarse tier far away, fine tier when near arrival) to save battery.
- **Samsung & OEM Battery Optimization**: Built-in instructions and deep links for OEM autostart managers (Samsung One UI "Never sleeping apps", Xiaomi, Oppo, Vivo, Huawei).
- **Lock Screen Full-Volume Alarm**: Native Kotlin channel (`MainActivity.kt`) forces max volume on `STREAM_ALARM` over silent/DND and turns on the screen over the lock screen.
- **Custom Destination Names**: Rename map-pinned or GPS locations with custom labels (e.g., *"Grandma's House"*, *"My Office"*).
- **Onward Cab Deep Links (Uber & Ola)**: Single-tap cab booking upon arrival at a station with pickup automatically set to your current location.
- **Family Arrival Notifications**: Pre-filled WhatsApp/SMS arrival alerts to family contacts upon alarm trigger.
- **Live ETA Share Link**: Web viewer link (`web_viewer/share.html`) allowing family to track trip progress live via Supabase RPC without needing an account.
- **Local-First & Supabase Cloud Sync**: Operates 100% offline with local `SharedPreferences`; syncs trip history and family contacts to Supabase when signed in.

---

## Tech Stack

| Layer | Technology Choice |
| --- | --- |
| **Mobile Client** | **Flutter / Dart** (Android-first, API 29+) |
| **State Management** | Riverpod |
| **Navigation** | `go_router` |
| **Location & Service** | `geolocator` (Foreground Service with `foregroundServiceType="location"`) |
| **Alarm Engine** | `flutter_local_notifications` (Full-Screen Intent) + `audioplayers` (ALARM stream) + Native Kotlin `AudioManager` & Window flags |
| **Geocoding & Maps** | OpenStreetMap / Nominatim (keyless) & `flutter_map` |
| **Backend & Sync** | **Supabase** (Postgres + Auth + Row Level Security + RPC) |
| **Keep-Alive Automation** | GitHub Actions (`supabase-keepalive.yml`) |

---

## Repository Structure

```text
WakeMate/
├─ app/                     # Flutter mobile application
│  ├─ lib/
│  │  ├─ core/              # Geo math (Haversine formula, ETA calculation)
│  │  ├─ models/            # Trip, ActiveTrip, PendingTrip, Destination, FamilyContact
│  │  ├─ services/          # Location, AlarmEngine, Geocoding, BatteryOptimization, UserTrips, FamilyContacts, TripShare
│  │  ├─ state/             # Riverpod providers (tripDraftProvider, trackingProvider)
│  │  ├─ features/          # Feature screens (alarm, tracking, set_alarm, search, settings, history, auth, permissions)
│  │  ├─ theme/             # Design tokens and app styling
│  │  └─ routing/           # go_router configuration
│  ├─ android/              # Native Kotlin MainActivity platform channel & AndroidManifest
│  ├─ assets/sounds/        # Bundled offline alarm ringtones
│  └─ test/                 # Unit & widget test suite (geo_math_test, ticket_parser_test, widget_test)
├─ backend/sql/             # Supabase database schema & RLS migration SQL scripts
├─ web_viewer/              # Static HTML page (share.html) for live ETA share links
└─ .github/workflows/       # GitHub Action workflow for Supabase keep-alive
```

---

## Project Status & Recent Improvements

- **Phase 1 — Core UI & Navigation**: ✅ Complete (all screens, Riverpod state, design system).
- **Phase 2 — Tracking & Alarm Engine**: ✅ Complete (persistent foreground service, adaptive polling, lock screen waking, native volume override).
- **Phase 3 — Supabase Backend & Data Layer**: ✅ Complete (guest mode fallback, local-first storage, cloud sync for trips/contacts/favorites, RLS security policies, capability-token live share RPC).
- **Background & OEM Reliability Enhancements**:
  - ✅ Configured `stopWithTask: false` and `foregroundServiceType="location"` for Android 14 (API 34) background persistence.
  - ✅ Added native Samsung One UI "Never sleeping apps" deep-link and OEM background-kill guidance.
- **Custom Destination Naming**: ✅ Users can assign custom names to map pins and current GPS locations.
- **Cab Deep Links**: ✅ Uber & Ola deep links updated to prefill pickup at arrival station while leaving destination open for onward transit.
- **Settings Persistence**: ✅ Unit & vibration preferences persist across app restarts via `SharedPreferences`.
- **Testing & Verification**: ✅ 11/11 automated unit and widget tests passing (`flutter test`), 0 static analysis issues (`flutter analyze`).
- **Supabase Keep-Alive**: ✅ Automated GitHub Action pings Supabase every 3 days to prevent free-tier auto-pausing.

---

## Getting Started

### Prerequisites
- Flutter SDK (3.22+ recommended)
- Android Studio / Android SDK (Min API 29 / Target API 34)
- Physical Android device (recommended for testing background location and lock screen alarm waking)

### Setup & Execution

1. Clone the repository:
   ```bash
   git clone https://github.com/ethanhostspherein/WakeMate.git
   cd WakeMate/app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run static analysis and test suite:
   ```bash
   flutter analyze
   flutter test
   ```

4. Run the app:
   ```bash
   flutter run
   ```

---

## License

Copyright © 2026 WakeMate. All rights reserved.
