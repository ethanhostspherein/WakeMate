# WakeMate

## Technical Requirements Document
*Architecture, Stack & Engineering Approach — v1.0*

## 1. Purpose & Scope

This Technical Requirements Document (TRD) defines the architecture, technology choices, and engineering approach needed to build WakeMate — with special focus on the hardest engineering problem in the product: reliable background location tracking and alarm triggering on Android when the screen is locked, the app is backgrounded, and OEM battery optimization is active.

## 2. High-Level Architecture

WakeMate follows a mobile-first architecture with a lightweight backend for auth, trip history sync, favorites, and (in V2+) train-delay lookups. The alarm-trigger logic itself runs entirely on-device so that it works without a live network connection.

- Client: React Native (Expo) app — owns location tracking, geofencing, alarm engine, and local persistence.
- Backend: Node.js + Express REST API — owns user accounts, trip history sync, favorites, and push notifications.
- Database: MongoDB — stores users, trips, favorites, history.
- Push/Notification layer: Firebase Cloud Messaging — used for family-notification (V3) and non-critical alerts; NOT used for the core alarm trigger, which must work offline.
- Maps/Geo: Google Maps SDK + Places API for search, pinning, and route/ETA display; OpenStreetMap as a fallback data source consideration for cost control.

Text-flow diagram:

```
React Native Client  →  REST API (Express)  →  MongoDB

React Native Client  →  Firebase Cloud Messaging  →  Family contact's WhatsApp/SMS (V3)

On-device: Expo Location + Background Task + Geofencing  →  Local Alarm Engine (works fully offline)
```

## 3. Technology Stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Mobile framework | React Native + Expo (managed/dev-client) | Fast iteration; eject to bare workflow if a needed native module requires it |
| Language | TypeScript | Type safety across app and API contracts |
| Navigation | React Navigation | Stack + tab navigators |
| Data fetching/cache | React Query | Server state caching, retries, offline queueing |
| Maps | react-native-maps + Google Maps SDK | Map rendering, route polyline, marker pins |
| Location | expo-location + expo-task-manager | Foreground + background location updates, geofencing |
| Notifications/Alarm | expo-notifications + native alarm module | Full-volume alarm requires a native module or bare workflow (see §5) |
| Backend framework | Node.js + Express | REST API |
| Database | MongoDB (Atlas) | Document store fits flexible trip/favorite schemas |
| Auth | Firebase Auth (Google/Apple) + Guest mode | Low-friction onboarding |
| Analytics/Crash | Firebase Analytics + Crashlytics | Track alarm success rate, crash-free sessions |
| Ads | AdMob (banner, interstitial, rewarded) | Free-tier monetization |

## 4. Background Location Tracking — Core Engineering Challenge

This is the highest-risk, highest-effort part of the system (est. ~70% of total engineering effort). The goal: keep tracking a user's GPS position accurately enough to trigger an alarm, even when:

- The phone screen is locked.
- The app is in the background or recently killed by the OS.
- Battery saver / data saver mode is active.
- The OEM (Xiaomi/MIUI, Oppo/ColorOS, Vivo/FuntouchOS, etc.) applies aggressive background-process killing beyond stock Android behavior.

### 4.1 Approach

- Use a persistent foreground service (Android) with a visible, low-priority notification ("WakeMate is tracking your trip") — this is the single most reliable way to avoid being killed by Doze/App Standby.
- Register a geofence around the destination point using expo-location's geofencing API (backed by Android's Geofencing API) as a coarse trigger, combined with continuous fine-grained location polling once the user enters a wider outer radius (e.g. 2× the alarm distance).
- Request the 'Allow all the time' background location permission with a clear, honest pre-permission explanation screen (required for Play Store policy compliance and for the OS to allow background updates at all).
- Detect and prompt for battery-optimization exemption (Settings → Battery → Unrestricted) for the app, with OEM-specific deep links/instructions where feasible (MIUI Autostart, Oppo Startup Manager, etc.).
- Use adaptive location update intervals: infrequent (60–90s) when far from destination, frequent (5–15s) inside the outer radius, to balance battery drain against accuracy.
- Persist trip state (destination, alarm distance, last known position) to local storage so tracking can resume correctly if the process is restarted by the OS.

### 4.2 Fallback & Resilience

- If continuous background updates are killed by the OS, fall back to periodic significant-location-change wakeups to at least keep the geofence check alive.
- On app resume/relaunch, immediately re-check position against the active trip and trigger the alarm retroactively if the user already passed the threshold while backgrounded.
- Show an in-app 'tracking health' indicator and warn the user pre-trip if battery optimization is not yet disabled for the app.

## 5. Alarm Engine

The alarm must be able to override Do Not Disturb, silent, and vibrate-only modes — this requires either a native Android AlarmManager + full-screen intent notification, or a bare-workflow native module, since Expo's standard notification API alone cannot guarantee full-volume override on all devices.

- Trigger source: geofence entry event or distance-threshold check on a location update.
- Trigger action: AlarmManager.setExactAndAllowWhileIdle + a full-screen intent Activity that wakes the screen and plays a looping alarm sound at max volume via AudioManager (STREAM_ALARM).
- Dismiss/Snooze: large touch targets on the alarm screen; snooze re-arms a shorter-distance re-trigger (e.g. re-alert at 1km if snoozed at 3km).
- Custom sounds: user-selectable ringtone list, stored locally; default sound bundled with the app for reliability without network.

## 6. Offline Support

Because the app must work in low/no-connectivity zones common on Indian train routes, the following must not require network access:

- GPS position acquisition.
- Distance/ETA calculation against the stored destination coordinates (calculated on-device, not via a routing API, once trip has started).
- Alarm trigger logic and playback.

Network is only required for: initial destination search (Places API), account sync, PNR lookups (V2), and family notifications (V3). Trip data queues locally and syncs to the backend once connectivity returns.

## 7. Backend API Overview

See the Backend Schema document for full field-level detail. Endpoint summary:

| Method | Endpoint | Purpose |
| --- | --- | --- |
| POST | /auth/login | Google/Apple sign-in exchange, returns session token |
| POST | /trip/start | Create a trip record when tracking begins |
| PATCH | /trip/:id | Update trip status (in-progress, alarm-triggered, completed, cancelled) |
| POST | /trip/end | Mark trip complete, record arrival time |
| GET | /history | Fetch past trips for the authenticated user |
| POST | /favorite | Save a favorite destination |
| DELETE | /favorite/:id | Remove a favorite destination |
| GET | /train/:pnr | (V2) Resolve PNR to train, route, and scheduled stops |
| POST | /notify/family | (V3) Trigger WhatsApp/SMS arrival notification |

## 8. Security & Privacy

- All API traffic over HTTPS/TLS; auth via short-lived JWT + refresh token.
- Location data associated with a trip is retained only as long as needed for history (configurable retention, default 90 days) and is deletable by the user at any time.
- Family notification (V3) requires explicit opt-in per trip, not a default-on setting; recipient consent messaging shown at setup.
- PNR (V2) is treated as sensitive personal travel data — not logged in analytics events, stored encrypted at rest.
- Play Store data-safety disclosure must accurately reflect background location usage, purpose, and retention.

## 9. Performance & Scalability

- Target: support tens of thousands of concurrent tracked trips without backend bottlenecks — backend load is light since core tracking is on-device; backend mainly handles history sync and periodic pings.
- Google Maps API usage optimized via caching of place lookups and minimizing repeated routing calls; monitor quota via Google Cloud Console billing alerts.
- MongoDB indexes on userId, tripId, and status fields for fast history queries.

## 10. Testing Strategy

| Test Type | Focus |
| --- | --- |
| Field testing — train | Real overnight/day train routes; verify alarm fires within selected distance despite tunnels, signal loss, speed variation |
| Field testing — bus | Intercity bus routes; verify behavior with more frequent stops and slower average GPS refresh |
| Battery drain testing | Measure %/hour drain across device tiers (budget, mid, flagship) and OEM skins |
| OEM background-kill testing | Xiaomi, Oppo, Vivo, Samsung — verify tracking survives with recommended settings applied |
| Offline testing | Airplane mode with GPS-only; confirm alarm still triggers correctly |
| Regression/unit tests | Distance calculation, geofence math, alarm state machine |

## 11. Deployment & Release

- CI: lint + type-check + unit tests on every push; EAS Build for Android APK/AAB generation.
- Crashlytics + Firebase Analytics wired before first public beta.
- Staged rollout on Play Store (internal testing → closed beta → production staged rollout 10% → 50% → 100%).
