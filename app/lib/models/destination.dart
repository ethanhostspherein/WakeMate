/// A geographic destination the user is travelling toward.
/// Maps to the `destination` GeoJSON point in the Backend Schema.
class Destination {
  final String placeName;
  final double lat;
  final double lng;
  final String? address;
  final double? distanceFromUserKm;

  const Destination({
    required this.placeName,
    required this.lat,
    required this.lng,
    this.address,
    this.distanceFromUserKm,
  });

  Destination copyWith({
    String? placeName,
    double? lat,
    double? lng,
    String? address,
    double? distanceFromUserKm,
  }) {
    return Destination(
      placeName: placeName ?? this.placeName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
      distanceFromUserKm: distanceFromUserKm ?? this.distanceFromUserKm,
    );
  }

  Map<String, dynamic> toJson() => {
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        if (address != null) 'address': address,
        if (distanceFromUserKm != null) 'distanceFromUserKm': distanceFromUserKm,
      };

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        placeName: json['placeName'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        address: json['address'] as String?,
        distanceFromUserKm: (json['distanceFromUserKm'] as num?)?.toDouble(),
      );
}
