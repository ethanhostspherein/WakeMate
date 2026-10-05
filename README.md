# WakeMate

**Never miss your stop.** WakeMate is a location-based smart alarm designed for travellers riding trains, buses, cabs, or metros. Unlike traditional time-based alarms, WakeMate continuously tracks your live GPS position against your target destination and fires a loud, unmissable alarm when you enter your arrival radius — even with the screen locked, the app backgrounded, or battery-saver active.

Built India-first with offline-first reliability: distance & time alarms, native hardware geofencing, pure Kotlin lock-screen alarm engine, IRCTC ticket SMS parsing, headphone disconnect safety guards, family arrival notifications, live web ETA share links, and brand-specific background autostart guidance.

---

## Key Features

### ⚡ Native Reliability Core & Hardware Geofencing
- **Hardware Geofences (`GeofenceManager.kt`)**: Registers hardware-level circular geofences (`GeofencingClient` from Google Play Services) at target destination coordinates. Operated directly by Android OS at the hardware level so the alarm triggers even if the Flutter app is force-closed or process-killed.
- **Pure Kotlin Lock-Screen Alarm (`AlarmActivity.kt`)**: Lightweight native Android `Activity` that wakes the screen (`setShowWhenLocked`, `setTurnScreenOn`), forces `STREAM_ALARM` to 100% volume, loops audio, and vibrates instantly with zero reliance on Flutter engine initialization.
- **`AlarmManager` System Watchdog (`WatchdogReceiver.kt`)**: Periodic 15-minute native system watchdog ensuring hardware geofences remain active during extended transit intervals.
- **Reboot Recovery (`BootReceiver.kt`)**: Automatically listens for device reboots (`BOOT_COMPLETED`) and restores active trip geofences without requiring the user to open WakeMate.

### 📍 Location-Based Smart Alarms
- **Distance & Time Triggers**: Set alarms by distance (e.g. wake 2 km before arrival) or estimated time (e.g. wake 15 mins before arrival).
- **Custom Destination Names**: Label map pins or GPS coordinates with custom names (e.g., *"Grandma's House"*, *"My Office"*).
- **Travel Mode Tabs**: Custom presets tailored for **Bus** and **Train** transit.
- **Dynamic Snooze Re-Arming**: Recalculates snooze distance strictly inside current position (`(remaining * 0.5).clamp(0.2, 1.0)`), preventing immediate alarm re-firing on the next GPS fix.

### 🎧 "Headphones / Earphone Disconnect" Safety Guard
- **Automatic Hardware Speaker Routing**: Monitors audio route changes via native Android intent receivers (`ACTION_AUDIO_BECOMING_NOISY`, `ACTION_HEADSET_PLUG`, `BluetoothHeadset.ACTION_CONNECTION_STATE_CHANGED`).
- **Unplug Protection**: If earplugs fall out or Bluetooth disconnects mid-trip or while the alarm is ringing, WakeMate automatically forces full-volume playback directly through the device's hardware speaker (`STREAM_ALARM`).
- **Live Safety Badges**: Visual indicators surface on the Alarm Screen, Tracking Screen, and Set Alarm Preflight Card.

### 🔔 Expanded Offline Ringtones & Live Previews
- **10 Bundled Ringtone Options**: Offline sounds ranging from gentle chimes to urgent sirens (Classic Bell, Radar Alarm, Gentle Chimes, Digital Beacon, Siren Alert, Alarm Beep, Warning Buzzer, Morning Alarm, Emergency Alert, Quick Alarm).
- **Live Previews**: Audition sound options directly within the Set Alarm screen and Settings screen with play/stop toggle controls.

### 📏 Real-Time Metric & Imperial Unit Switching
- **App-Wide Unit Toggle**: Instantly switch between Kilometres (`km`) and Miles (`mi`) via Settings without restarting the app.
- **Dynamic Formatting**: Converts preset chips, custom sliders, tracking distance cards, history logs, search results, and Android home widgets in real time.

### 🛡️ Journey Guardian & Missed-Stop Escalation
- **Status Monitoring**: Live plain-language status feedback on the Tracking Screen summarizing GPS signal quality, battery optimization risk, and proximity.
- **Missed-Stop Detection**: If the vehicle moves $\ge 1.5\text{ km}$ past its closest approach while an alarm is ringing unacknowledged, WakeMate escalates to sharper vibration patterns and fires automated family alerts.

### 🎫 IRCTC & SMS Ticket Parser
- **One-Tap Trip Intake**: Automatically extracts 10-digit PNR numbers, travel mode, station names, and departure timestamps from shared booking SMS messages or text snippets.
- **PNR Metadata Capture**: Saves the 10-digit PNR number on train trip records for reference and scheduled departure reminders.
- **System Intent Sharing**: Integrates with Android `ReceiveSharingIntent` to create trips directly from messaging apps.

### ⏰ Scheduled Departure Reminders
- **Arm at Departure**: Schedule a departure prompt (`DepartureScheduler`) that reminds you to arm tracking right when your trip begins, avoiding unnecessary battery usage before departure.

### 🔋 OEM Battery Optimization & Background Autostart Guidance
- **Foreground Service Persistence**: Uses an Android persistent foreground service with adaptive polling (coarse 250m filter far away, fine 15m filter near arrival).
- **Brand-Specific Instructions**: Comprehensive, always-visible background autostart guide on the Permissions screen with step-by-step instructions and deep-links for **Samsung** ("Never sleeping apps"), **Xiaomi / MIUI**, **Oppo / ColorOS**, **Vivo / FunTouchOS**, **Huawei**, and **OnePlus**.

### 👨‍👩‍👧 Family Contact Management & Alerts
- **Quick-Select Contacts**: Save family member details locally and sync to Supabase cloud.
- **Multi-Channel Alerts**: Dispatch pre-filled WhatsApp (`wa.me`) or SMS arrival notifications upon arrival or missed stops.

### 🌐 Live ETA Share Link & Web Viewer
- **No-App Web Tracker**: Generate capability share links (`https://webviewer-nine.vercel.app/share.html?t=<token>`) allowing family to track trip position live on an interactive map.
- **Privacy & RLS**: Read-only access secured via Supabase Row Level Security (RLS) and RPC endpoints, with 12-hour expiration and instant link revocation on arrival.

### 📱 Android Home Screen Widget
- **Glanceable Trip Stats**: Android home screen widget (`HomeScreenWidgetProvider`) displaying active trip destination, remaining alarm distance, or last completed trip summary.

### 🚕 Onward Cab Booking (Uber & Ola)
- **One-Tap Cab Booking**: Quick-action bottom sheet upon arrival pre-fills pickup to your current station while leaving dropoff open for onward travel.

### 💾 Local-First & Supabase Cloud Sync
- **100% Offline Capability**: Runs seamlessly without network connectivity using local `SharedPreferences`.
- **Cloud Backup & Environment Config**: Automatically syncs recent trip history, favorite destinations, and contacts to Supabase when authenticated. Environment credentials configured cleanly at build-time via `--dart-define`.

---

## Tech Stack

| Layer | Technology Choice |
| --- | --- |
| **Mobile Client** | **Flutter / Dart** (Android-first, API 29+) |
| **State Management** | Flutter Riverpod |
| **Navigation** | `go_router` |
| **Native Reliability Core** | Native Kotlin (`GeofencingClient`, `GeofenceManager`, `AlarmActivity`, `WatchdogReceiver`, `BootReceiver`) |
| **Location & Service** | `geolocator` (Foreground Service with `foregroundServiceType="location"`) |
| **Alarm Engine** | Pure Kotlin Lock-Screen `AlarmActivity` + `flutter_local_notifications` (Full-Screen Intent) + `audioplayers` (`STREAM_ALARM`) |
| **Audio Route Guard** | Android `ACTION_AUDIO_BECOMING_NOISY` BroadcastReceiver & `setCommunicationDevice` |
| **Geocoding & Maps** | OpenStreetMap / Nominatim & `flutter_map` |
| **Home Screen Widget** | `home_widget` + Native Kotlin `AppWidgetProvider` |
| **Backend & Sync** | **Supabase** (PostgreSQL + Auth + RLS + RPC Functions) |
| **Web Live Viewer** | HTML5 + Leaflet.js + Supabase REST RPC |
| **Keep-Alive Automation** | GitHub Actions (`supabase-keepalive.yml`) |

---

## Repository Structure

```text
WakeMate/
├─ app/                     # Flutter mobile application
│  ├─ lib/
│  │  ├─ core/              # Geo math (Haversine formula, speed & ETA calculation)
│  │  ├─ models/            # Trip, ActiveTrip, PendingTrip, Destination, FamilyContact, Favorite
│  │  ├─ services/          # Location, AlarmEngine, Geocoding, BatteryOptimization, UserTrips, FamilyContacts, TripShare, TicketParser, DepartureScheduler, HomeWidget
│  │  ├─ state/             # Riverpod providers (tripDraftProvider, trackingProvider)
│  │  ├─ features/          # UI Feature screens (alarm, tracking, set_alarm, search, settings, history, auth, permissions, onboarding, legal)
│  │  ├─ theme/             # App typography, spacing, and curated dark/vibrant colors
│  │  └─ routing/           # go_router configuration
│  ├─ android/              # Native Kotlin MainActivity, AlarmActivity, GeofenceManager, Receivers & AndroidManifest
│  │  └─ src/main/kotlin/com/wakemate/wakemate/
│  │     ├─ AlarmActivity.kt            # Pure Kotlin lock-screen alarm display
│  │     ├─ BootReceiver.kt             # Restores geofences on phone reboot
│  │     ├─ GeofenceBroadcastReceiver.kt # Native hardware geofence transition handler
│  │     ├─ GeofenceManager.kt          # Play Services GeofencingClient & Watchdog scheduler
│  │     ├─ HomeScreenWidgetProvider.kt # Android home screen widget
│  │     ├─ MainActivity.kt             # Platform channels for alarm & geofencing sync
│  │     └─ WatchdogReceiver.kt         # Periodic AlarmManager watchdog ticker
│  ├─ assets/sounds/        # 10 bundled offline alarm ringtones (.wav)
│  └─ test/                 # Unit & widget test suite (geo_math_test, ticket_parser_test, widget_test)
├─ backend/sql/             # Idempotent Supabase database migration scripts & RLS setup
├─ web_viewer/              # Static web viewer (share.html) for live ETA share links
└─ .github/workflows/       # GitHub Action workflow for Supabase free-tier keep-alive
```

---

## Background Autostart Setup Guide

> For a deep technical analysis of Android Doze mode, OEM task killers, and WakeMate's multi-layered background defense architecture (including native hardware geofences and watchdog receivers), see [BACKGROUND_RELIABILITY_GUIDE.md](file:///d:/projects/WakeMate/BACKGROUND_RELIABILITY_GUIDE.md).

To ensure alarms trigger reliably when your phone screen is locked or the app is backgrounded, WakeMate provides brand-specific configuration shortcuts:

1. **Samsung (One UI)**: Settings → Battery → Background usage limits → *Never auto-sleeping apps* → Add WakeMate.
2. **Xiaomi / Redmi / POCO (MIUI / HyperOS)**: Settings → Apps → Manage Apps → WakeMate → Toggle *Autostart* ON. Set Battery Saver to *No restrictions*.
3. **Oppo / Realme (ColorOS / Realme UI)**: Settings → Battery → App battery management → WakeMate → Allow *Auto-launch* and *Background activity*.
4. **Vivo / iQOO (Funtouch OS / OriginOS)**: Settings → Battery → High background power consumption → Enable WakeMate.
5. **Huawei**: Settings → Apps → App launch → WakeMate → Toggle *Manage manually* (Enable Auto-launch, Secondary launch, Run in background).
6. **OnePlus (OxygenOS)**: Settings → Battery → Advanced settings → Optimize battery use → WakeMate → Select *Don't optimize*.

---

## Getting Started

### Prerequisites
- Flutter SDK (`^3.12.1` / Dart SDK `^3.12.1`)
- Android Studio & Android SDK (Min API 29 / Target API 34)
- Physical Android device (recommended for testing native hardware geofences and lock-screen alarm waking)

### Installation & Execution

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ethanhostspherein/WakeMate.git
   cd WakeMate/app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run static analysis and test suite**:
   ```bash
   flutter analyze
   flutter test
   ```

4. **Launch the application**:
   ```bash
   flutter run --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
   ```

5. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```

---

## Verification & Test Results

- **Static Analysis (`flutter analyze`)**: `0 issues found`
- **Unit & Widget Tests (`flutter test`)**: `11/11 tests passing`
  - `GeoMath`: Haversine distance calculations, m/s to km/h conversion, ETA calculation.
  - `TicketParser`: PNR extraction, 12h/24h time formatting, station arrow parsing.
  - `SplashScreen`: Wordmark and tagline rendering.
- **APK Build Output**: Verified release build [`app-release.apk`](file:///d:/projects/WakeMate/app/build/app/outputs/flutter-apk/app-release.apk).

---

## License

Copyright © 2026 WakeMate. All rights reserved.
