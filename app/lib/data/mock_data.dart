import '../models/destination.dart';
import '../models/favorite.dart';
import '../models/trip.dart';

/// Mock data for Phase 1 (Milestone M1 — all screens navigable with mock data).
/// Replaced by React-Query-style repositories wired to the backend in Phase 3.
class MockData {
  MockData._();

  static const List<Favorite> favorites = [
    Favorite(
      id: 'fav_home',
      placeName: 'Home — Jaipur',
      lat: 26.9124,
      lng: 75.7873,
      defaultAlarmDistanceKm: 3,
    ),
    Favorite(
      id: 'fav_college',
      placeName: 'College — Delhi',
      lat: 28.6139,
      lng: 77.2090,
      defaultAlarmDistanceKm: 5,
    ),
    Favorite(
      id: 'fav_office',
      placeName: 'Office — Gurugram',
      lat: 28.4595,
      lng: 77.0266,
      defaultAlarmDistanceKm: 1,
    ),
  ];

  static const List<Destination> searchSuggestions = [
    Destination(
        placeName: 'Jaipur Junction',
        lat: 26.9196,
        lng: 75.7878,
        address: 'Railway Station Rd, Jaipur, Rajasthan'),
    Destination(
        placeName: 'New Delhi Railway Station',
        lat: 28.6420,
        lng: 77.2194,
        address: 'Paharganj, New Delhi'),
    Destination(
        placeName: 'Kota Junction',
        lat: 25.1936,
        lng: 75.8447,
        address: 'Station Rd, Kota, Rajasthan'),
    Destination(
        placeName: 'Ajmer Junction',
        lat: 26.4691,
        lng: 74.6399,
        address: 'Station Rd, Ajmer, Rajasthan'),
    Destination(
        placeName: 'Mumbai Central',
        lat: 18.9696,
        lng: 72.8194,
        address: 'Mumbai Central, Maharashtra'),
    Destination(
        placeName: 'Pune Junction',
        lat: 18.5286,
        lng: 73.8743,
        address: 'Agarkar Nagar, Pune, Maharashtra'),
  ];

  static List<Trip> recentTrips() {
    final now = DateTime(2026, 7, 9, 8, 30);
    return [
      Trip(
        id: 'trip_1',
        mode: TripMode.destination,
        destination: const Destination(
            placeName: 'Jaipur Junction', lat: 26.9196, lng: 75.7878),
        alarmDistanceKm: 3,
        soundId: 'classic_bell',
        status: TripStatus.completed,
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
        completedAt: now.subtract(const Duration(days: 1, hours: 1)),
        distanceTravelledKm: 262,
        alarmTriggered: true,
      ),
      Trip(
        id: 'trip_2',
        mode: TripMode.destination,
        destination: const Destination(
            placeName: 'New Delhi Railway Station', lat: 28.6420, lng: 77.2194),
        alarmDistanceKm: 5,
        soundId: 'loud_siren',
        status: TripStatus.completed,
        createdAt: now.subtract(const Duration(days: 4, hours: 3)),
        completedAt: now.subtract(const Duration(days: 4)),
        distanceTravelledKm: 268,
        alarmTriggered: true,
      ),
      Trip(
        id: 'trip_3',
        mode: TripMode.destination,
        destination: const Destination(
            placeName: 'Kota Junction', lat: 25.1936, lng: 75.8447),
        alarmDistanceKm: 3,
        soundId: 'classic_bell',
        status: TripStatus.cancelled,
        createdAt: now.subtract(const Duration(days: 8, hours: 2)),
        distanceTravelledKm: 45,
        alarmTriggered: false,
      ),
    ];
  }

  /// Approximate device location for the map preview (Jaipur city centre).
  static const Destination mockCurrentLocation = Destination(
    placeName: 'Current location',
    lat: 26.9124,
    lng: 75.7873,
  );
}
