# WakeMate

## UI/UX Specification Brief
*Design System, Screens & Components — v1.0*

## 1. Design Principles

- Half-asleep usability first — every critical action (dismiss, snooze, start trip) must be reachable with large, unmistakable touch targets, since users will interact with this app while drowsy or just woken up.
- Glanceable tracking — remaining distance and ETA should be readable in under a second, from across a train berth.
- Trust through visibility — always show tracking status clearly ('Tracking active', battery-optimization warnings) so users don't wonder if the app is working.
- Minimal taps to start — favorites and recents exist specifically to cut the 'set an alarm' flow to one or two taps.
- Calm, modern, travel-forward visual language — differentiate from dated 2017-era competitor apps.

## 2. Visual Identity

### 2.1 Color Palette

| Role | Color | Usage |
| --- | --- | --- |
| Primary | Deep Navy Blue (#1B2A4A) | Headers, primary text, key icons |
| Accent / Action | Teal (#0F7C82) | Primary buttons, active states, links |
| Success / Arrival | Green (#2E9E5B) | Trip complete, success confirmations |
| Alert / Alarm | Warm Amber–Red gradient | Alarm screen only — high-urgency visual treatment |
| Background | Off-white / Light Grey (#F7F8FA) | Base app background |
| Surface | White | Cards, sheets, modals |

### 2.2 Typography

- Primary typeface: a rounded, highly legible geometric sans (e.g. Inter or Poppins).
- Distance/ETA numerals on the tracking screen use a larger, tabular-figure weight for at-a-glance reading.
- Minimum body text size 16sp; alarm-screen text minimum 24sp for drowsy readability.

### 2.3 Iconography & Motion

- Custom icon set themed around transit (train, bus, pin, bell) rather than generic map-pin stock icons.
- Subtle motion on the splash and onboarding; tracking screen avoids distracting animation to conserve battery and attention.
- Alarm screen uses a strong pulsing animation to reinforce urgency without being visually harsh.

## 3. Screen-by-Screen Specification

### 3.1 Splash Screen

- Logo centered, subtle scale-in animation.
- Duration ~1.5s, auto-advances to Onboarding (first launch) or Home (returning user).

### 3.2 Onboarding (3 slides)

- Slide 1: 'Never miss your stop' — illustration of a sleeping traveller on a train.
- Slide 2: 'Location-based alarm' — illustration of a map pin + distance ring.
- Slide 3: 'Works offline' — illustration of a signal-off icon with GPS still active.
- Skip option always visible; final slide CTA → Permissions.

### 3.3 Permission Screen

- Sequential, single-purpose permission requests (not a single dump) — Location → Background Location → Notifications → Battery optimization.
- Each step has a one-line plain-language reason before the system dialog fires, to improve grant rates.
- Battery-optimization step links directly to the relevant OS/OEM settings screen where possible.

### 3.4 Home Screen

- Top: search bar ('Where are you headed?').
- Mid: compact map preview showing current location.
- Favorites row — horizontally scrollable chips with place name + icon.
- Recent Trips list — destination, date, distance, status badge.
- Prominent primary CTA if a Favorite/Recent is tapped — skips straight to Set Alarm pre-filled.

### 3.5 Destination Search

- Google Places autocomplete list with recents pinned at top.
- Map view toggle to drop a manual pin for places without a formal address.
- Confirm button shows the selected place name + a mini map preview before proceeding.

### 3.6 Set Alarm Screen

- Distance presets as large selectable chips: 1km / 3km / 5km / 10km / Custom (slider 0.5–50km).
- Sound picker with preview-play button.
- Volume slider with a 'max volume override' toggle explanation.
- Primary CTA: 'Start Journey' — full-width, high-contrast button.

### 3.7 Tracking Screen

- Full-bleed map with route line (blue) from current position to destination pin.
- Bottom sheet: Remaining distance (large numerals) — e.g. '48 km', ETA — '42 min', current speed.
- Persistent 'Tracking active' status chip; warning chip if battery optimization is not yet disabled.
- Stop/Cancel trip button, secondary styling to avoid accidental taps.

### 3.8 Alarm Screen

- Full-screen takeover, wakes the device, bypasses lock screen where OS allows.
- Huge pulsing animation + 'Wake Up — Station Near' headline.
- Two large buttons: Dismiss (ends trip) and Snooze (re-arms shorter-distance re-trigger).
- No small tap targets — minimum 64dp touch height on both buttons.

### 3.9 History Screen

- List of past trips: destination, date, distance travelled, 'Reached Successfully' / 'Cancelled' status badge.
- Tap a trip to view a read-only summary (route, time taken).

### 3.10 Settings / Profile

- Account info (or Guest mode indicator), sign-out.
- Default alarm sound/volume, units (km/mi), permission status shortcuts.
- Premium upgrade entry point, privacy policy and terms links.

## 4. Component Inventory

| Component | Used On |
| --- | --- |
| Primary Button (full-width, teal) | Start Journey, Confirm Destination, Upgrade |
| Distance Chip Selector | Set Alarm |
| Trip Status Badge | Home (Recents), History |
| Favorite Chip | Home |
| Bottom Sheet (tracking stats) | Tracking Screen |
| Full-Screen Alert Overlay | Alarm Screen |
| Map View w/ Pin + Route Line | Search, Set Alarm, Tracking |
| Permission Rationale Card | Permission Screen |

## 5. Accessibility Considerations

- High color-contrast ratios (WCAG AA minimum) throughout, especially on the alarm and tracking screens.
- All primary actions reachable via large touch targets (≥ 48dp, ≥ 64dp on the alarm screen).
- Sound + haptic feedback paired with every visual alert, not visual-only.
- Text scaling support for users with larger system font settings.
