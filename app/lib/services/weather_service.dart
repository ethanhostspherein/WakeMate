import 'dart:convert';

import 'package:http/http.dart' as http;

/// Current weather at a destination — Weather-at-destination nudge.
/// Open-Meteo (free, keyless), mirrors [GeocodingService]'s plain-class,
/// best-effort pattern: returns null on any failure, never throws.
class WeatherService {
  static const _base = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherInfo?> current(double lat, double lng) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': '$lat',
      'longitude': '$lng',
      'current_weather': 'true',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final cw = data['current_weather'] as Map<String, dynamic>?;
      final temp = (cw?['temperature'] as num?)?.toDouble();
      final code = (cw?['weathercode'] as num?)?.toInt();
      if (temp == null || code == null) return null;
      return WeatherInfo(tempC: temp, condition: _condition(code));
    } catch (_) {
      return null;
    }
  }

  // WMO weather codes, collapsed to a short label.
  static String _condition(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly cloudy';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 80 && code <= 82) return 'Showers';
    if (code >= 95) return 'Thunderstorms';
    return 'Cloudy';
  }
}

class WeatherInfo {
  final double tempC;
  final String condition;
  const WeatherInfo({required this.tempC, required this.condition});
}
