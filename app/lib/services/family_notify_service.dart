import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

import '../models/active_trip.dart';

/// Shared WhatsApp/SMS deep-link builder for alerting a trip's family
/// contact. Used both for the manual "Notify family" tap (alarm_screen.dart)
/// and the automatic missed-stop alert (tracking_provider.dart).
class FamilyNotifyService {
  FamilyNotifyService._();
  static final FamilyNotifyService instance = FamilyNotifyService._();

  /// Returns false if there's no saved contact, or if no app could handle
  /// the deep link. Message wording is fixed — no UI context is assumed, so
  /// this never shows a snackbar; callers surface feedback themselves.
  Future<bool> notifyMissedStop(ActiveTrip trip) async {
    final phone = trip.familyContactPhone?.trim();
    if (phone == null || phone.isEmpty) return false;

    final destName = trip.destination.placeName;
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final message =
        'WakeMate alert: I may have missed my stop near $destName. Please check on me.';

    // wa.me / sms: deep links only pre-fill the message — the platform
    // requires a final manual tap inside WhatsApp/Messages to actually send.
    final uri = trip.familyChannel == 'sms'
        ? (Platform.isIOS
            ? Uri.parse('sms:$digits&body=${Uri.encodeComponent(message)}')
            : Uri(scheme: 'sms', path: digits, queryParameters: {'body': message}))
        : Uri.parse(
            'https://wa.me/${digits.replaceAll('+', '')}?text=${Uri.encodeComponent(message)}');

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
