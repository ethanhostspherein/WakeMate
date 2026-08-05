# WakeMate

## Backend Architecture & Schema
*Database Design & API Reference — v1.0*

## 1. Overview

MongoDB is used as the primary data store, chosen for schema flexibility across trip/favorite variants (V1 destination-based trips vs. V2 PNR-linked trips). This document defines collections, fields, relationships, and the REST API contract.

## 2. Collections

### 2.1 users

| Field | Type | Notes |
| --- | --- | --- |
| _id | ObjectId | Primary key |
| name | String | |
| email | String | Unique, indexed |
| photoUrl | String | Optional, from OAuth provider |
| authProvider | String | 'google' \| 'apple' \| 'guest' |
| isPremium | Boolean | Default false |
| premiumPurchasedAt | Date | Null until upgrade |
| defaultAlarmDistanceKm | Number | User preference, default 3 |
| defaultSound | String | Sound file identifier |
| createdAt | Date | |
| updatedAt | Date | |

### 2.2 trips

| Field | Type | Notes |
| --- | --- | --- |
| _id / tripId | ObjectId | Primary key |
| userId | ObjectId (ref: users) | Indexed |
| mode | String | 'destination' \| 'train' \| 'bus' \| 'metro' |
| startLocation | GeoJSON Point | { lat, lng } captured at trip start |
| destination | GeoJSON Point | { lat, lng, placeName } |
| alarmDistanceKm | Number | Selected trigger distance |
| soundId | String | Selected alarm sound |
| pnr | String | V2 only, nullable |
| trainNumber | String | V2 only, nullable |
| status | String | 'active' \| 'alarm_triggered' \| 'completed' \| 'cancelled' |
| distanceTravelledKm | Number | Computed at completion |
| alarmTriggeredAt | Date | Nullable |
| completedAt | Date | Nullable |
| familyNotifyContactId | ObjectId (ref: contacts) | V3 only, nullable |
| createdAt | Date | |

### 2.3 favorites

| Field | Type | Notes |
| --- | --- | --- |
| _id | ObjectId | Primary key |
| userId | ObjectId (ref: users) | Indexed |
| placeName | String | |
| lat | Number | |
| lng | Number | |
| defaultAlarmDistanceKm | Number | Optional override |
| createdAt | Date | |

### 2.4 history (denormalized read view of completed trips)

| Field | Type | Notes |
| --- | --- | --- |
| tripId | ObjectId (ref: trips) | Primary key / unique |
| userId | ObjectId (ref: users) | Indexed |
| destinationName | String | |
| completed | Boolean | |
| alarmTriggered | Boolean | |
| arrivalTime | Date | |
| distanceTravelledKm | Number | |

### 2.5 contacts (V3 — family notification)

| Field | Type | Notes |
| --- | --- | --- |
| _id | ObjectId | Primary key |
| userId | ObjectId (ref: users) | Owner |
| name | String | |
| phone | String | E.164 format |
| channel | String | 'whatsapp' \| 'sms' |
| consentGiven | Boolean | Recipient consent flag |

## 3. Indexes

- users.email — unique index.
- trips.userId + trips.status — compound index for fast 'active trip' lookups.
- history.userId + history.arrivalTime (descending) — for paginated history queries.
- favorites.userId — index for quick favorites list retrieval.

## 4. API Reference (OpenAPI-style Summary)

### 4.1 Auth

- `POST /auth/login` — body: `{ provider, idToken }` → returns `{ user, accessToken, refreshToken }`
- `POST /auth/refresh` — body: `{ refreshToken }` → returns `{ accessToken }`

### 4.2 Trips

| Method & Path | Body | Response |
| --- | --- | --- |
| POST /trip/start | { mode, destination, alarmDistanceKm, soundId, pnr? } | { tripId, status: 'active' } |
| PATCH /trip/:id | { status, alarmTriggeredAt? } | { tripId, status } |
| POST /trip/end | { tripId, distanceTravelledKm } | { tripId, status: 'completed' } |
| GET /history?page=&limit= | — | { trips: [...], totalCount } |

### 4.3 Favorites

| Method & Path | Body | Response |
| --- | --- | --- |
| POST /favorite | { placeName, lat, lng, defaultAlarmDistanceKm? } | { favoriteId } |
| GET /favorite | — | { favorites: [...] } |
| DELETE /favorite/:id | — | { success: true } |

### 4.4 Train Mode (V2)

| Method & Path | Body | Response |
| --- | --- | --- |
| GET /train/:pnr | — | { trainNumber, route: [...], scheduledStops: [...] } |
| GET /train/:trainNumber/status | — | { delayMinutes, currentStation, lastUpdated } |

### 4.5 Family Notification (V3)

| Method & Path | Body | Response |
| --- | --- | --- |
| POST /contact | { name, phone, channel } | { contactId, consentGiven: false } |
| POST /notify/family | { tripId, contactId } | { success: true } |

## 5. Data Retention & Privacy Notes

- Trip location coordinates (startLocation/destination) retained for 90 days by default, then anonymized/aggregated for analytics only.
- Users can delete their full history and account on request (Settings → Delete Account), cascading deletes across trips, history, favorites, and contacts.
- PNR and trainNumber fields are excluded from analytics event payloads.
