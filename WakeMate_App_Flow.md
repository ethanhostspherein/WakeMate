# WakeMate

## Application Flow Document
*End-to-End User & System Flows — v1.0*

## 1. Overview

This document describes the end-to-end user flow through WakeMate, including primary paths, decision points, and edge-case handling. It complements the UI/UX Brief (screen-level detail) and the PRD (feature rationale).

## 2. Primary Flow — First-Time User

- Splash Screen — logo + animation (~1.5s).
- Onboarding (3 slides) — 'Never miss your stop', 'Location-based alarm', 'Works offline'.
- Permission Screen — requests Location (foreground), Background Location ('Allow all the time'), Notifications, and prompts for battery-optimization exemption, each with a plain-language explanation of why it's needed.
- Sign-in / Guest Mode — Google or Apple sign-in, or continue as Guest (local-only history, no sync).
- Home Screen — search bar, map preview, Favorites, Recent Trips.
- Destination Search — type a place name or pin on the map directly.
- Set Alarm — choose alarm distance (1/3/5/10km or custom), sound, and volume.
- Start Journey — confirms trip start; foreground tracking service begins.
- Tracking Screen — live map, remaining distance, ETA, speed; user can lock phone here.
- Alarm Trigger — full-screen, full-volume alarm fires once inside the chosen distance.
- Dismiss / Snooze — user dismisses (ends trip) or snoozes (re-arms at a shorter distance).
- Journey Complete — trip marked complete, saved to History.

## 3. Returning User — Fast Path

For a returning user with a saved Favorite destination, the flow compresses to:

- Home Screen — tap a Favorite (e.g. 'Home — Jaipur').
- Set Alarm screen pre-fills the last-used distance/sound for that favorite.
- Start Journey — tracking begins immediately.

This one-tap re-trip path is a key retention lever — daily/weekly commuters should be able to start a trip in under 5 seconds.

## 4. Train Mode Flow (V2)

- Home Screen — select 'Train Mode' toggle.
- Enter PNR — 10-digit PNR input.
- Train Fetched — app resolves train number, route, and scheduled stops via backend PNR lookup.
- Destination Auto-Selected — user confirms or adjusts the alighting station.
- Train Delay Tracked — background job polls live running status periodically.
- Alarm Auto-Adjusted — if the train is running late/early, the distance-based trigger point recalculates against updated ETA.
- Standard tracking → alarm → completion flow continues as in the primary flow.

## 5. Bus / Metro Mode Flow (V2)

- Home Screen — select 'Bus Mode' or 'Metro Mode'.
- Choose Bus Stand / Metro Station from a curated list (no live vehicle tracking dependency).
- Set Alarm — same distance/sound flow as primary path.
- Start Journey → Tracking → Alarm → Complete, identical to the primary flow.

## 6. Family Notification Flow (V3)

- During 'Set Alarm', user optionally enables 'Notify family on arrival' and selects a contact.
- Consent screen explains what will be sent (e.g. 'Lakshay has reached Jaipur') and to whom.
- On Journey Complete, backend triggers a WhatsApp/SMS message via the notification service to the selected contact.

## 7. Edge Cases & Error Handling

| Scenario | Handling |
| --- | --- |
| User denies background location permission | Show a persistent banner explaining the alarm may not fire reliably; offer a re-prompt path to Settings |
| GPS signal lost mid-trip (tunnel, dead zone) | Continue using last known position + speed to estimate progress; re-sync once signal returns; never silently drop the trip |
| App killed by OS mid-trip | Foreground service notification keeps the process alive; on forced kill, geofence broadcast receiver re-triggers tracking on next location update |
| User's device has no data connection | Trip continues on GPS-only; map tiles may not refresh but distance/ETA/alarm logic is unaffected |
| User reaches destination before starting the alarm timer expectations (very short trip) | Alarm can trigger immediately after 'Start Journey' if already inside the radius; show a confirmation dialog to avoid false triggers |
| PNR not found / invalid (V2) | Graceful error state with a manual destination-selection fallback |
| User dismisses alarm accidentally | Show an 'Undo / Re-arm' option for a short grace window (e.g. 30 seconds) |
| Multiple concurrent trips (rare) | V1 restricts to a single active trip at a time; UI blocks starting a second trip while one is active |

## 8. Flow Diagram (Text Form)

```
Splash → Onboarding → Permissions → Sign-in/Guest → Home

Home → [Search Destination | Favorites | Recent Trips] → Set Alarm → Start Journey

Start Journey → Tracking Screen → Alarm Trigger → Dismiss/Snooze → Journey Complete → History

Home → Train Mode → Enter PNR → Train Fetched → Destination Auto-Selected → (joins main tracking flow)
```
