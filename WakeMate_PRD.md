# WakeMate

## Product Requirements Document
*Travel Safety & Smart Arrival Assistant — v1.0*

## 1. Executive Summary

WakeMate is a location-based smart alarm for travellers who fall asleep on trains, buses, cabs, or metros and risk missing their stop. Unlike time-based alarms, WakeMate tracks live GPS position against a chosen destination and triggers a loud, unmissable alarm once the user is within a configurable distance of arrival.

The MVP is scoped to be buildable by a small team (or a single developer working with an AI coding agent) in roughly 3–4 days for a functional build, and 1–2 weeks for a polished, store-ready release. The long-term vision positions WakeMate specifically for Indian rail and bus commuters, with train-PNR integration, Hindi voice alerts, and family arrival notifications as key differentiators against older, stagnant competitors in this category.

## 2. Vision & Goals

### 2.1 Vision Statement

"Never miss your destination again." WakeMate is an intelligent travel companion that wakes users before their destination using GPS — even if they are asleep, offline, or their phone is locked and battery-saving.

### 2.2 Product Goals

- Eliminate missed stops/stations for sleeping or distracted travellers.
- Provide a background-tracking experience reliable enough to trust on every trip.
- Differentiate for the Indian market with train/bus-specific features, not just a generic geofence alarm.
- Build a sustainable freemium revenue model (ads + one-time/lifetime premium).
- Ship an MVP fast (days, not months) using an AI-assisted development workflow.

### 2.3 Business Objectives (Year 1)

| Objective | Target |
| --- | --- |
| Play Store launch | Within 3–4 weeks of PRD sign-off |
| Installs (Month 1) | 1,000–5,000 organic + community-driven |
| Day-7 retention | ≥ 25% |
| Premium conversion | 3–5% of active users |
| Crash-free session rate | ≥ 99% |

## 3. Problem Statement

Millions of people in India travel daily by train, bus, cab, and metro. A large share of long or overnight journeys involve sleeping through part of the trip. Missing a stop has real costs:

- Travelling 20–200+ km past the intended stop.
- Paying extra fare, taking a return trip, or losing a cab/auto booking.
- Missing interviews, meetings, exams, or family events.
- Safety risk when arriving at an unfamiliar or unsafe location late at night.

Traditional alarms are time-based and useless against variable travel speed, delays, or unknown arrival times. Existing location-alarm apps in this category are largely from 2017–2020, have dated UI, unreliable background tracking, and no India-specific features (train mode, PNR tracking, Hindi voice, family alerts).

## 4. Target Users

### 4.1 Primary Personas

| Persona | Description | Key Need |
| --- | --- | --- |
| Commuter College Student | Travels by train/bus regularly between hometown and college, often overnight | Reliable wake-up without draining battery |
| Daily Office Commuter | Uses metro/bus daily, dozes off after a long work day | Quick-set alarm for a fixed, saved route |
| Railway Long-Distance Traveller | Overnight or long-duration train journeys, sleeper class | Train-aware alarm, PNR-based ETA, delay handling |
| Bus Traveller (Intercity) | State/private bus operators, fewer digital signals than rail | Simple stand/stop-based alarm, offline reliability |

### 4.2 Secondary Personas

- Tourists unfamiliar with local stops and announcements.
- Truck drivers / delivery riders needing arrival alerts near destination.
- Cab/auto passengers wanting to be alerted before reaching an unfamiliar drop point.
- Backpackers on multi-leg regional transport.

## 5. Competitive Snapshot

Existing location-alarm apps (Google Play category incumbents) are largely single-purpose, last updated years ago, and carry generic UI with heavy legacy ad formats. None combine train/bus-specific modes with Hindi voice alerts and family notifications. This gap is WakeMate's core wedge: positioning as "Wake Me There, built for India," rather than a generic global geofence alarm.

- Gap 1: No PNR-linked train tracking in incumbent apps.
- Gap 2: No regional-language voice alerts.
- Gap 3: No family/WhatsApp arrival notification.
- Gap 4: Dated UI/UX and poor background-tracking reliability on modern Android versions.

## 6. Scope: MVP Feature Set (V1)

| # | Feature | Description | Priority |
| --- | --- | --- | --- |
| 1 | Destination Search & Map Pin | Google Places search or manual map pin for destination | P0 |
| 2 | Alarm Distance Selector | 1 / 3 / 5 / 10 km presets + custom slider | P0 |
| 3 | Background Location Tracking | Works with screen locked, app minimized, battery saver on | P0 |
| 4 | Full-Volume Alarm | Overrides silent/vibrate mode; custom ringtone support | P0 |
| 5 | Live Tracking Screen | Remaining distance, ETA, current speed, route line | P0 |
| 6 | Trip History | Past trips with date, distance, completion status | P1 |
| 7 | Favorites | Saved frequent destinations for one-tap trip start | P1 |
| 8 | Offline Alarm Trigger | GPS-only alarm trigger without active internet | P1 |
| 9 | Basic Settings | Sound, vibration, units, permissions management | P0 |

## 7. Post-MVP Roadmap (V2–V4)

### 7.1 Version 2 — Transit Modes

- Train Mode: enter PNR → auto-fetch train, route and scheduled destination → track real-time delay → auto-adjust alarm trigger point.
- Bus Mode: select bus stand/stop from a curated list; simplified alarm flow for operators without live tracking APIs.
- Metro Mode: station-list based alarm, reusing the bus-mode flow with metro-specific station data.

### 7.2 Version 3 — Family Tracking

Opt-in automatic WhatsApp/SMS notification to a chosen contact when the user reaches their destination (e.g. "Lakshay has reached Jaipur"), with an explicit consent and privacy flow.

### 7.3 Version 4 — AI Travel Assistant

Voice-based alerts ("Wake up. Your station arrives in 12 minutes."), Hindi/regional language support, and proactive trip guidance.

## 8. User Stories

| ID | As a... | I want to... | So that... |
| --- | --- | --- | --- |
| US-01 | commuter | search and pin my destination before I sleep | I don't have to stay awake to track my stop |
| US-02 | user | set a custom alarm distance | the alarm gives me enough time to wake up and get ready |
| US-03 | user | have the alarm ring at full volume even on silent mode | I don't sleep through the alert |
| US-04 | frequent traveller | save favorite destinations | I can start a trip in one tap next time |
| US-05 | train traveller | enter my PNR | the app tracks my train and adjusts the alarm if it's delayed |
| US-06 | user's family member | get a WhatsApp message when they arrive | I know they reached safely without calling |
| US-07 | user | see remaining distance and ETA live | I can gauge how much longer I have before arrival |
| US-08 | budget-conscious user | use the app for free with ads | I can try it before paying for premium |

## 9. Non-Functional Requirements

| Category | Requirement |
| --- | --- |
| Reliability | Alarm must trigger with ≥ 99% success rate across the tested distance range, even with app killed by OS |
| Battery | Background tracking should not exceed ~5–10% battery drain per hour of active trip on average devices |
| Performance | Tracking screen updates location/ETA at least every 10–15 seconds |
| Offline | Core alarm trigger must work on GPS alone without an active data connection |
| Privacy | Location data stored only for active/recent trips; family notification is strictly opt-in |
| Accessibility | Large tap targets and high-contrast alarm screen usable by half-asleep users |
| Compatibility | Android 10+ (API 29+), with graceful handling of OEM battery-optimization restrictions (Xiaomi, Oppo, Vivo, etc.) |

## 10. Risks & Assumptions

### 10.1 Key Risks

- Android background location restrictions (OS-level and OEM-level) are the single biggest engineering risk — estimated as ~70% of total engineering effort.
- Google Maps API costs could scale with usage; needs quota monitoring and caching strategy.
- PNR data provider reliability/availability for Version 2 train mode is an external dependency.
- Play Store policy on background location usage requires a clear in-app disclosure and privacy policy.

### 10.2 Assumptions

- Target users are Android-first (India smartphone market skew); iOS is out of scope for V1.
- Users are willing to grant "Allow all the time" location permission when the value proposition is clear.
- A freemium model with a low-cost lifetime unlock (₹99) fits the target demographic better than a subscription.

## 11. Success Metrics

| Metric | Definition | Target |
| --- | --- | --- |
| Alarm Success Rate | % of trips where alarm triggered within the selected distance window | ≥ 98% |
| D1 / D7 / D30 Retention | % of users returning after install | 40% / 25% / 12% |
| Avg. Trips per Active User / Month | Engagement depth | ≥ 4 |
| Premium Conversion Rate | % of MAU purchasing lifetime premium | 3–5% |
| Crash-Free Sessions | Stability | ≥ 99% |

## 12. Release Plan Summary

V1 (MVP) targets a 3–4 day functional build followed by 1–2 weeks of polish, testing on real train/bus routes, and Play Store asset preparation. See the Implementation Plan document for the detailed phased roadmap and task breakdown.
