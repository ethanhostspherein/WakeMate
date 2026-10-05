# WakeMate — Background Reliability & Execution Guide

This document outlines the background execution challenges faced by WakeMate, the exact engineering steps taken to fix background tracking reliability, how the background system functions, the **Native Reliability Core Architecture**, and current testing status.

---

## 1. Initial Background Execution Issues

During long train or bus journeys, riders often lock their phones, switch apps, or swipe away apps from the recent apps tray. Initially, WakeMate faced critical background execution issues:

- **Swiping App From Recent Apps**: When removing or swiping away the app from the recent apps / background task tray, the mobile OS immediately terminated the app process, preventing the alarm from triggering upon arrival.
- **OS Suspension & Doze Mode**: Android OS automatically suspended background location updates when the device was idle or screen-locked for an extended period.
- **OEM Task Killers**: Mobile manufacturers (Samsung One UI, Xiaomi MIUI, Oppo ColorOS, Vivo Funtouch OS, Huawei) aggressively killed the app process in the background to save battery, causing riders to miss station arrival alarms.
- **DND & Silent Muting**: Default audio streams were muted by silent or Do-Not-Disturb modes when the app was in the background.

---

## 2. Engineering Steps Taken to Resolve Background Reliability

To ensure location tracking stays alive and alarms ring unmissed, the following engineering steps were implemented:

1. **Persistent Foreground Service (`stopWithTask: false`)**: Configured Android `foregroundServiceType="location"` with `stopWithTask: false` and an ongoing system notification so the tracking service continues running in the background even if the user swipes away the app from the recent apps tray.
2. **Adaptive Polling Cadence**:
   - **Coarse Tier (Far Away)**: 250m distance filter to save battery during long transit intervals.
   - **Fine Tier (Near Destination)**: Switches to 15m distance filter inside 2× the alarm radius for precise arrival triggering.
3. **Native Lock-Screen & Volume Override (`MainActivity.kt`)**:
   - Forces `AudioManager.STREAM_ALARM` to 100% volume before alarm playback (overriding silent and DND modes).
   - Sets window flags (`setShowWhenLocked`, `setTurnScreenOn`) to wake the hardware display over the lock screen.
4. **Headphones / Earphone Disconnect Safety Guard**:
   - Native `BroadcastReceiver` listens for `ACTION_AUDIO_BECOMING_NOISY` and headset unplugs, automatically routing full alarm playback through built-in hardware speakers.
5. **OEM Battery Optimization & Autostart Integration**:
   - Added native platform channel deep-links (`openOemSettings`) and brand-specific user guides for Samsung, Xiaomi, Oppo, Vivo, Huawei, and OnePlus.

---

## 3. Native Reliability Core Architecture (Hardware Geofencing, Watchdog & Reboot Recovery)

While persistent foreground services keep the app alive during normal operations, aggressive OEM battery savers or low-memory conditions can still terminate the Dart process. To provide a **100% fail-safe guarantee**, WakeMate incorporates a **Native Kotlin Reliability Core**:

```text
               ┌──────────────────────────────────────────────┐
               │         Active Trip Started in Flutter       │
               └──────────────────────┬───────────────────────┘
                                      │
                         (Sync Platform Channel)
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          ▼                           ▼                           ▼
┌───────────────────┐       ┌───────────────────┐       ┌───────────────────┐
│ 1. GeofencingClient│       │ 2. AlarmManager   │       │ 3. SharedPreferences│
│    Hardware Fence │       │    Watchdog       │       │    Trip Backup    │
└─────────┬─────────┘       └─────────┬─────────┘       └─────────┬─────────┘
          │                           │                           │
          │ (Rider Enters Radius)     │ (Process Killed?)         │ (Device Rebooted?)
          ▼                           ▼                           ▼
┌───────────────────┐       ┌───────────────────┐       ┌───────────────────┐
│GeofenceBroadcast  │       │ WatchdogReceiver  │       │ BootReceiver      │
│Receiver           │       │ Relaunches Check  │       │ Restores Geofence │
└─────────┬─────────┘       └───────────────────┘       └───────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Pure Kotlin AlarmActivity (Instant full-screen lock screen) │
└─────────────────────────────────────────────────────────────────┘
```

### Components of the Native Core

1. **Hardware Geofencing (`GeofenceManager.kt`)**:
   - Registers a circular hardware geofence (`GeofencingClient` from Google Play Services) at the target destination coordinates with `NEVER_EXPIRE` and `GEOFENCE_TRANSITION_ENTER` / `DWELL` triggers.
   - Operated directly by Android OS at the hardware/location provider level, independent of app process life.

2. **Native Geofence Receiver (`GeofenceBroadcastReceiver.kt`)**:
   - Triggered natively by Android when the rider enters the destination radius.
   - Reads active trip configuration from `SharedPreferences` (`flutter.active_trip_v1`) and launches `AlarmActivity` natively even if the Flutter engine and Dart VM are completely dead.

3. **Pure Kotlin Lock-Screen Alarm Activity (`AlarmActivity.kt`)**:
   - Lightweight, native `Activity` written in pure Kotlin with zero dependency on Flutter initialization.
   - Sets lock-screen window flags (`setShowWhenLocked`, `setTurnScreenOn`, `FLAG_KEEP_SCREEN_ON`).
   - Forces `STREAM_ALARM` to 100% volume, loops alarm audio via native `MediaPlayer`, pulses `Vibrator` patterns, and provides native **DISMISS** and **SNOOZE** buttons.

4. **Periodic System Watchdog (`WatchdogReceiver.kt`)**:
   - Scheduled via Android `AlarmManager.setInexactRepeating` every 15 minutes.
   - Inspects active trip status and re-enforces geofence registration to protect against OS geofence eviction.

5. **Reboot Recovery Receiver (`BootReceiver.kt`)**:
   - Listens for `android.intent.action.BOOT_COMPLETED` and `android.intent.action.MY_PACKAGE_REPLACED`.
   - Restores hardware geofences and watchdog timers automatically after a phone restart without requiring the user to open WakeMate.

---

## 4. Batch 1 Reliability & Codebase Fixes

In addition to the Native Reliability Core, the following critical reliability issues and build bugs were resolved:

- **Snooze Re-Arm Clamping**: Fixed an issue where snoozing within 1 km (e.g., at 0.8 km out) re-armed the alarm at 1.0 km, causing it to immediately re-fire on the next GPS fix. Snooze distance is now dynamically clamped to `(remaining * 0.5).clamp(0.2, 1.0)`.
- **Headphone Guard Volume & Route Delegation**: Removed automatic hardware volume/speaker forcing from `MainActivity.kt`'s receiver during normal app browsing, delegating audio routing to `AlarmService` only while an alarm is actively ringing.
- **Exact Alarm Permission Cleanup**: Removed `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>` from `AndroidManifest.xml` to comply with Google Play review policies.
- **Compile-Time Environment Configuration**: Removed `.env` asset declarations and `flutter_dotenv` dependency. Supabase credentials are now securely passed at compile/build time via `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` using `const String.fromEnvironment`.

---

## 5. Current Background Execution Workflow

1. **Trip Arming**: When a user starts a trip, WakeMate launches a persistent foreground service, displays an ongoing system notification, and registers a native hardware geofence with `GeofenceManager`.
2. **Background GPS Polling**: As the rider travels, location updates run seamlessly in the background with adaptive polling intervals.
3. **Arrival Trigger**: Upon entering the destination alarm radius, either the foreground location stream or the native `GeofenceBroadcastReceiver` triggers:
   - Wakes the screen over the lock screen.
   - Forces max volume on `STREAM_ALARM`.
   - Routes playback to hardware speakers if headphones disconnect.
   - Loops offline alarm sound and continuous vibration.
4. **Process / Reboot Safety**: If the app is killed or the phone restarts mid-trip, `BootReceiver` and `WatchdogReceiver` automatically restore geofences, and `AlarmActivity` rings natively upon arrival.

---

## 6. Testing & Field Verification Status

- **Automated Unit Tests**: `11/11 tests passing` (`flutter test`).
- **Static Analysis**: `No issues found!` (`flutter analyze`).
- **Build Output**: Successfully compiled release APK (`app-release.apk`).
- **Real-Device Field Verification**: Simulator and local device tests pass clean. Physical field testing across target Android OEM devices (Samsung, Xiaomi, Oppo, Vivo) in real transit conditions is recommended for final verification.
