/// A geographic destination the user is travelling toward.
/// Maps to the `destination` GeoJSON point in the Backend Schema.
class Destination {
  final String placeName;
  final double lat;
  final double lng;
  final String? address;

  const Destination({
    required this.placeName,
    required this.lat,
    required this.lng,
    this.address,
  });

  Destination copyWith({
    String? placeName,
    double? lat,
    double? lng,
    String? address,
  }) {
    return Destination(
      placeName: placeName ?? this.placeName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      address: address ?? this.address,
    );
  }

  Map<String, dynamic> toJson() => {
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        if (address != null) 'address': address,
      };

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        placeName: json['placeName'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        address: json['address'] as String?,
      );
}
