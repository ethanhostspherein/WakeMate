/// A saved frequent destination for one-tap trip start.
/// Maps to the `favorites` collection in the Backend Schema.
class Favorite {
  final String id;
  final String placeName;
  final double lat;
  final double lng;
  final double? defaultAlarmDistanceKm;

  const Favorite({
    required this.id,
    required this.placeName,
    required this.lat,
    required this.lng,
    this.defaultAlarmDistanceKm,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        'defaultAlarmDistanceKm': defaultAlarmDistanceKm,
      };

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        id: json['id'] as String,
        placeName: json['placeName'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        defaultAlarmDistanceKm:
            (json['defaultAlarmDistanceKm'] as num?)?.toDouble(),
      );
}
