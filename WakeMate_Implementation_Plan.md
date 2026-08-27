# WakeMate

## Implementation Plan
*Phased Roadmap & Task Breakdown — v1.0*

## 1. Overview

This plan breaks WakeMate's build into phases with concrete, AI-coding-agent-ready tasks (suitable for feeding to Claude Code / Antigravity in sequence). Estimates assume an AI agent generating ~70–80% of code, with a developer reviewing, testing on real devices/routes, and fixing integration issues.

## 2. Phase 1 — Core UI & Foundation (Days 1–2)

| Task ID | Task | Output |
| --- | --- | --- |
| P1-01 | Scaffold Expo + TypeScript project, folder structure, navigation shell | Runnable app skeleton |
| P1-02 | Build design tokens (colors, typography, spacing) per UI/UX Brief | Theme module |
| P1-03 | Implement Splash, Onboarding (3 slides), Permission screens | 3 functional screens |
| P1-04 | Integrate Google Maps SDK + Places Autocomplete | Working map + search |
| P1-05 | Build Home screen (search bar, favorites row, recents list) with mock data | Home screen UI |
| P1-06 | Build Destination Search + map-pin flow | Search → confirm destination flow |
| P1-07 | Build Set Alarm screen (distance chips, sound picker, volume) | Set Alarm UI |
| P1-08 | Request foreground + background location permissions with rationale screens | Permission flow wired to OS dialogs |

## 3. Phase 2 — Tracking, Background Location & Alarm Engine (Days 3–5)

| Task ID | Task | Output |
| --- | --- | --- |
| P2-01 | Implement foreground service for Android background location tracking | Persistent tracking notification + service |
| P2-02 | Implement geofencing around destination with adaptive-interval location polling | Geofence trigger logic |
| P2-03 | Build on-device distance/ETA calculation (no routing API dependency mid-trip) | Local calc module |
| P2-04 | Build Tracking Screen (live map, distance, ETA, speed, stop button) | Functional tracking UI |
| P2-05 | Implement native alarm trigger (AlarmManager + full-screen intent, max-volume override) | Alarm fires even on silent/DND |
| P2-06 | Build Alarm Screen (dismiss/snooze, animation) | Functional alarm UI |
| P2-07 | Implement battery-optimization detection + OEM-specific settings deep links | In-app warning + settings shortcut |
| P2-08 | Persist trip state locally for process-restart resilience | Crash/kill recovery logic |

## 4. Phase 3 — Backend, History, Favorites & Offline (Days 6–8)

> Superseded: the app uses **Supabase** (Postgres + Auth + Row Level Security), not a hand-built Node/Express/MongoDB API. The table below is kept as the original task breakdown; see Phase 5.5 (§6) for what was actually delivered against it.

| Task ID | Task | Output |
| --- | --- | --- |
| P3-01 | Scaffold Node.js/Express backend with MongoDB connection | Running API server |
| P3-02 | Implement Auth (Google/Apple + Guest mode) with JWT | /auth endpoints |
| P3-03 | Implement Trip endpoints (start/patch/end) per Backend Schema doc | /trip endpoints |
| P3-04 | Implement Favorites CRUD endpoints | /favorite endpoints |
| P3-05 | Implement History endpoint with pagination | /history endpoint |
| P3-06 | Build History screen + Favorites management UI in the app | Functional screens |
| P3-07 | Implement local offline queue — trips sync to backend once connectivity returns | Offline-first sync logic |
| P3-08 | Wire React Query for server-state caching across the app | Cached, resilient data layer |

## 5. Phase 4 — Testing, Battery Optimization & Store Readiness (Days 9–11)

| Task ID | Task | Output |
| --- | --- | --- |
| P4-01 | Field test on real train route(s) — verify alarm accuracy and background survival | Test report + fixes |
| P4-02 | Field test on real bus route(s) | Test report + fixes |
| P4-03 | Battery drain benchmarking across device tiers | Drain report + optimization tuning |
| P4-04 | OEM background-kill testing (Xiaomi/Oppo/Vivo/Samsung) | Compatibility fixes + user guidance copy |
| P4-05 | Wire Firebase Analytics + Crashlytics | Instrumented build |
| P4-06 | Integrate AdMob (banner, interstitial, rewarded) with free/premium gating | Monetization live |
| P4-07 | Prepare Play Store assets (icon, feature graphic, 8 screenshots, promo copy) | In progress — screenshot prompts ready (P5-15); app name/description/category drafted (§8); icon and feature graphic still needed |
| P4-08 | Write Privacy Policy & Terms (background location + data-safety disclosure) | In-app screens done (P5-14); a hosted public-URL copy for Play Console's Data Safety form is still needed |
| P4-09 | Internal testing track → closed beta → staged production rollout | Not started — release signing is done (see P5-16), so the remaining blocker is the Play Console account/testing-track setup itself |

## 6. Phase 5.5 — Reliability & Engagement Features (Flutter/Supabase build)

*Built after Phase 2–3 in the actual Flutter/Supabase implementation (this repo diverged from the original Expo/MongoDB plan above). Status as of 2026-08-26.*

| Task ID | Task | Status | Notes |
| --- | --- | --- | --- |
| P5-01 | Reliability Engine — GPS/battery confidence score | Done | `ReliabilityLevel` (`active_trip.dart`) now scores GPS accuracy + battery-exempt + notification-permission-granted + a 2-min post-start self-test (`AlarmService.selfTest()` — vibration-capability check only, gated by `isRinging`/`phase==tracking` so it can never collide with a real alarm; deliberately skips a real audio probe as unnecessary risk for the same signal). Foreground-service-alive signal still not included. |
| P5-02 | Missed-stop detection + escalation | Done | Closest-approach tracking + distance-regrowth trigger (`tracking_provider.dart`), now escalates once on the false→true transition via `AlarmService.escalate()` (sharper vibration burst layered on the ringing alarm). No 3-min-unacknowledged timer (dropped — `phase == alarm` already means unacknowledged) and no exponential re-escalation (single burst is enough; codebase already recomputes state on every GPS tick if a stronger signal is needed later). Notify-family now fires automatically on dismiss (see P5-11), in addition to the existing manual tap in the missed-stop banner. |
| P5-03 | Motion-confirmed dismiss | Done | 2s hold-to-dismiss (`_HoldButton` in `alarm_screen.dart`). Accelerometer/pickup-gesture version not built — hold-button is the cheaper first rung and sufficient unless it proves inadequate. |
| P5-04 | Journey Guardian status line | Done | Single derived status string in `tracking_screen.dart` (`_GuardianStatusLine`), driven by P5-01/02 state. |
| P5-05 | Sleep Mode confirm screen | Done | `set_alarm_screen.dart` `_SleepModeCard` — destination/wake-trigger/weather + "PROTECTION READY" pill, "Start Sleep" CTA. |
| P5-06 | Travel stats/journal card | Done | `history_screen.dart` `_StatsSummary` — total km, trip count, places, from last 20 trips (existing cap). |
| P5-07 | Weather-at-destination nudge | Done | `weather_service.dart` (Open-Meteo, keyless), surfaced on the Sleep Mode card. |
| P5-08 | Post-arrival quick actions | Done (partially stubbed) | Cab-booking bottom sheet in `alarm_screen.dart`; Uber/Ola buttons remain stubbed (not the current priority). `url_launcher` itself is now an approved, added dependency (see P5-11), so wiring the cab buttons is a small follow-up, not a blocked one. |
| P5-09 | Live ETA share link | Done | `trip_share_service.dart` + `web_viewer/share.html`, deployed to `https://webviewer-nine.vercel.app/share.html` (Vercel, account `lakshay18n`). `trip_shares.sql` run in Supabase. Fully wired end-to-end. |
| P5-10 | Home-screen widget | Done (untested on device) | `home_widget` plugin + `HomeScreenWidgetProvider.kt`. Compiles clean under `flutter analyze`; native Gradle build not yet run on a device/emulator. |
| P5-11 | Automatic family arrival notification | Done | `url_launcher` added as a direct dependency. `alarm_screen.dart` now captures the active trip before `dismiss()` clears it and, if `notifyFamily` was enabled for that trip, opens WhatsApp (`wa.me` link) or SMS with a pre-filled arrival message to the saved contact. Platform limit: the user must still tap Send inside WhatsApp/Messages — no deep link can send on the app's behalf without a paid WhatsApp Business API, which is out of scope. The manual "Notify family" button in the missed-stop banner uses the same code path. |
| P5-12 | Supabase confirmed as sole live backend | Done | The unused Node/Express/MongoDB backend described in the original plan (§4 below) was never built; the app has talked to Supabase directly since Phase 3. A stray empty Express scaffold folder was removed this session. `backend/sql/*.sql` remain as the authoritative schema/migration reference and should stay. |
| P5-13 | Supabase sync bug fix | Done | Trip and family-contact sync were silently failing for signed-in users; root cause was a schema mismatch against the live Supabase tables. Fixed by running the corrected SQL migrations directly in Supabase. |
| P5-14 | In-app Privacy Policy & Terms of Service | Done | New `legal_screen.dart` with `PrivacyPolicyScreen` and `TermsOfServiceScreen`, routed at `/privacy-policy` and `/terms-of-service`, opened from the existing "About" tiles at the bottom of Settings. Covers location/background-tracking data use, Supabase as data processor, the family-notify feature, data retention/deletion, and the "not a safety service" disclaimer. This satisfies the in-app requirement only — Play Console's Data Safety form also needs a *hosted* (public URL) copy, which is still outstanding (see §8 Store Readiness). |
| P5-15 | Play Store screenshot marketing copy | Done | Four brand-matched image-generation prompts prepared (1080×1920 px, WakeMate navy/teal palette) for the Alarm, Tracking, Home, and Set Alarm screens, each with headline/subtext overlay copy — ready to feed to an image generator for the Play Store listing's screenshot set. |
| P5-16 | Release signing + first AAB build | Done | Generated a real upload keystore (`android/app/upload-keystore.jks`, alias `upload`, valid to 2054) and `android/key.properties` (both gitignored, exist only on this machine — must be backed up externally or updates can never be published again under this identity). `android/app/build.gradle.kts` now signs release builds with it, falling back to the debug key only if `key.properties` is absent. First release AAB built and confirmed signed with the new key: `app/build/app/outputs/bundle/release/app-release.aab`. |
| P5-17 | Uber/Ola quick-action deep links | Done | `_bookCab()` in `alarm_screen.dart` now actually launches: Uber via its universal link (`m.uber.com/ul/...` with prefilled drop-off coordinates — opens the Uber app directly via Android/iOS App Links if installed, browser otherwise), Ola via its `olacabs://` app scheme with a Play Store fallback if not installed. Previously a stub. |

## 7. Phase 5 — Post-Launch Roadmap (Future)

- V2: Train Mode (PNR lookup + delay tracking + auto-adjusted alarm), Bus Mode, Metro Mode.
- V3: Automatic WhatsApp/SMS arrival notifications shipped this session (P5-11); still open — a dedicated consent flow for the saved contact.
- V4: AI voice assistant with Hindi/regional-language alerts, offline maps, Wear OS companion.

## 8. Play Store Listing & Store Readiness

Draft listing content, prepared this session so the store listing can be filled in directly once assets are ready.

| Field | Draft value |
| --- | --- |
| App name | WakeMate: Travel Alarm |
| Category | Travel & Local |
| Content rating | Everyone (location data collection disclosed via the Data Safety form) |
| Support contact | support@wakemate.app |
| Short description (80 char max) | GPS alarm that wakes you before your bus, train, or cab stop arrives. |

**Full description (draft):**

> Never sleep past your stop again. WakeMate is a location-based travel alarm for anyone who dozes off on a train, bus, cab, or metro. Instead of a fixed time, it tracks your live GPS position against your chosen destination and wakes you with a loud, unmissable alarm as you approach — even with the screen locked, the app in the background, and the phone on silent or Do Not Disturb.
>
> **Key features**
> - Set an alarm by distance or time from your stop, with an on-device ETA that keeps working without a constant network connection.
> - A reliability engine checks GPS accuracy and battery settings when your trip starts, so you know your alarm is armed before you fall asleep.
> - Missed-stop detection escalates the alarm if you don't respond in time.
> - Optional automatic family notification sends an arrival check-in message if you might have missed your stop.
> - Live ETA sharing lets a friend or family member follow your trip on a map link, no app required on their end.
> - Trip history, favorite destinations, and a home-screen widget for your next journey.
>
> WakeMate is a convenience tool, not a safety service — always confirm your stop yourself, especially on unfamiliar routes. Core alarm functionality is free; an optional one-time purchase removes ads.

**Still outstanding for submission** (not part of this session's work, tracked here for visibility):

- Release build signed with a real Play App Signing key (currently signs with the debug key — see P4-09).
- App icon (512×512) and feature graphic (1024×500).
- Screenshots rendered from the four prompts in P5-15.
- A hosted, publicly reachable copy of the Privacy Policy for the Data Safety form (the in-app screen from P5-14 does not satisfy this by itself).
- Permission-justification forms in Play Console for `ACCESS_BACKGROUND_LOCATION`, `SCHEDULE_EXACT_ALARM`, and `USE_FULL_SCREEN_INTENT`.
- A Google Play developer account and its one-time $25 registration fee.
- 12+ opted-in closed testers for 14 continuous days, required before a new developer account gets production access.

## 9. Milestone Summary

| Milestone | Target Day | Definition of Done |
| --- | --- | --- |
| M1 — UI Skeleton | Day 2 | All core screens navigable with mock data |
| M2 — Tracking + Alarm Functional | Day 5 | End-to-end trip flow works on a real device |
| M3 — Backend + Sync Live | Day 8 | History/Favorites persist across sessions and devices |
| M4 — Store-Ready Build | Day 11 | Field-tested, monetized, Play Store assets complete |
| M5 — Public Launch | Week 3–4 | Staged rollout reaches 100% |

## 10. Notes for AI-Agent-Assisted Development

- Feed each task row as an individual prompt to the coding agent, referencing the relevant section of the TRD/Backend Schema/UI-UX Brief for context.
- After each phase, run the app on a physical device (not just simulator) before proceeding — background location and alarm behavior cannot be reliably validated on emulators.
- Package recurring fixes (e.g. OEM battery-optimization handling) as reusable master prompts, consistent with the existing LeadForge development workflow.
