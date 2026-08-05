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
| P4-07 | Prepare Play Store assets (icon, feature graphic, 8 screenshots, promo copy) | Store listing assets |
| P4-08 | Write Privacy Policy & Terms (background location + data-safety disclosure) | Published policy pages |
| P4-09 | Internal testing track → closed beta → staged production rollout | Live Play Store listing |

## 6. Phase 5 — Post-Launch Roadmap (Future)

- V2: Train Mode (PNR lookup + delay tracking + auto-adjusted alarm), Bus Mode, Metro Mode.
- V3: Family/WhatsApp arrival notifications with consent flow.
- V4: AI voice assistant with Hindi/regional-language alerts, offline maps, Wear OS companion.

## 7. Milestone Summary

| Milestone | Target Day | Definition of Done |
| --- | --- | --- |
| M1 — UI Skeleton | Day 2 | All core screens navigable with mock data |
| M2 — Tracking + Alarm Functional | Day 5 | End-to-end trip flow works on a real device |
| M3 — Backend + Sync Live | Day 8 | History/Favorites persist across sessions and devices |
| M4 — Store-Ready Build | Day 11 | Field-tested, monetized, Play Store assets complete |
| M5 — Public Launch | Week 3–4 | Staged rollout reaches 100% |

## 8. Notes for AI-Agent-Assisted Development

- Feed each task row as an individual prompt to the coding agent, referencing the relevant section of the TRD/Backend Schema/UI-UX Brief for context.
- After each phase, run the app on a physical device (not just simulator) before proceeding — background location and alarm behavior cannot be reliably validated on emulators.
- Package recurring fixes (e.g. OEM battery-optimization handling) as reusable master prompts, consistent with the existing LeadForge development workflow.
