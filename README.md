# WakeMate

**Never miss your stop.** WakeMate is a location-based smart alarm for travellers who fall asleep on trains, buses, cabs, or metros. Unlike time-based alarms, it tracks live GPS position against a chosen destination and fires a loud, unmissable alarm once you're within a configurable distance of arrival — even with the screen locked, the app backgrounded, and battery-saver on.

Built India-first: destination alarms today, with PNR-linked train tracking, regional-language voice alerts, and family arrival notifications on the roadmap.

## Tech stack

| Layer | Choice |
| --- | --- |
| Mobile client | **Flutter / Dart** (Android-first) |
| State | Riverpod |
| Navigation | go_router |
| Location | geolocator (foreground-service background tracking) |
| Alarm | flutter_local_notifications (full-screen intent) + audioplayers on the ALARM stream + native `AudioManager` max-volume channel |
| Geocoding | OpenStreetMap / Nominatim (keyless) |
| Backend (planned) | Node.js + Express + MongoDB |

> Note: the client is Flutter. The original planning docs specify React Native/Expo — that was superseded; only the client framework changed.

## Repository layout

```
WakeMate/
├─ app/                     # Flutter application
│  ├─ lib/
│  │  ├─ core/              # geo math (haversine, ETA)
│  │  ├─ models/            # trip, destination, alarm settings
│  │  ├─ services/          # location, alarm engine, geocoding, ticket parser, share intake
│  │  ├─ state/             # Riverpod providers (trip draft, tracking)
│  │  ├─ features/          # one folder per screen
│  │  ├─ theme/             # design tokens
│  │  └─ routing/           # go_router
│  ├─ android/              # incl. native alarm platform channel (Kotlin)
│  └─ assets/sounds/        # bundled alarm tones (offline-safe)
└─ *.md                     # PRD, TRD, UI/UX, backend schema, implementation plan
```

## Status

- **Phase 1 — Core UI & foundation:** ✅ complete (all screens, design system, navigation).
- **Phase 2 — Tracking + alarm engine:** ✅ complete (background location foreground service, adaptive polling, on-device distance/ETA, full-volume native alarm over silent/DND, trip persistence + restart recovery, battery-optimization detection).
- **Trip intake:** ✅ Share-to-WakeMate (share a ticket → parse PNR/destination/departure → geocode → confirm) and arm-at-departure scheduling. ⏳ PNR live tracking (needs the backend + a rail API).
- **Phase 3 — Backend (Node/Express + MongoDB):** ⏳ planned — auth, trip/favorites/history sync, offline queue, PNR lookup.
- **Phase 4 — Testing, monetization, store readiness:** ⏳ planned.

## Running the app

```bash
cd app
flutter pub get
flutter run
```

Requires Flutter 3.44+ and an Android device/emulator (API 29+). Background location and the full-volume alarm should be validated on a physical device.
