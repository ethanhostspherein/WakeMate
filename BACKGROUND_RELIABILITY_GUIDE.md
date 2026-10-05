# WakeMate — Background Reliability & Execution Guide

This document outlines the initial background execution challenges faced by WakeMate, the exact engineering steps taken to fix background tracking reliability, how the background system currently functions, and the current testing status.

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

## 3. Current Background Execution Workflow

1. **Trip Arming**: When a user starts a trip, WakeMate launches a persistent foreground service and displays an ongoing tracking notification in the system tray.
2. **Background GPS Polling**: As the rider travels, location updates continue running seamlessly in the background with adaptive polling intervals even when the app is backgrounded or removed from recent apps.
3. **Arrival Trigger**: Upon entering the destination alarm radius, WakeMate:
   - Wakes the hardware screen over the lock screen.
   - Forces max volume on `STREAM_ALARM`.
   - Ensures playback routes to hardware speakers even if earphones disconnect.
   - Loops the bundled offline alarm sound and triggers continuous vibration.

---

## 4. Testing & Real-Device Field Verification Status

- **Automated Tests**: Unit tests (`flutter test`) and static analysis (`flutter analyze`) are **100% clean and passing**.
- **Real-Device Field Testing Note**: While simulator and local device tests function as expected, **field testing on physical moving trains/buses across various OEM Android devices (Samsung, Xiaomi, Oppo, Vivo) in real-world travel conditions is pending**. Physical testing on target devices is recommended to verify OEM battery behavior under real transit conditions.
