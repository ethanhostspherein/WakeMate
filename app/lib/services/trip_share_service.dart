import 'supabase_auth_service.dart';

/// Live ETA share link — generates a capability-URL (the token is the
/// secret, same "anyone with the link" model as a Google Docs share) so
/// family can watch a trip's live position with no account and no app on
/// their side. Mirrors [FamilyContactsService]'s Supabase-client access
/// pattern. Requires an authenticated user (the share row needs an owner);
/// silently unavailable otherwise, same convention as contact sync.
class TripShareService {
  TripShareService._();
  static final TripShareService instance = TripShareService._();

  static const String viewerBaseUrl =
      'https://webviewer-nine.vercel.app/share.html';

  static String linkFor(String token) => '$viewerBaseUrl?t=$token';

  /// Create a share row and return its token (not the full link — the
  /// caller composes that via [linkFor]).
  Future<String?> createShare({
    required String tripId,
    required double destLat,
    required double destLng,
    required String destName,
  }) async {
    final client = SupabaseAuthService.instance.client;
    final userId = SupabaseAuthService.instance.currentUser?.id;
    if (client == null || userId == null) return null;

    try {
      final row = await client
          .from('trip_shares')
          .insert({
            'trip_id': tripId,
            'user_id': userId,
            'dest_lat': destLat,
            'dest_lng': destLng,
            'dest_name': destName,
            'expires_at':
                DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
          })
          .select('share_token')
          .single();
      return row['share_token'] as String;
    } catch (_) {
      return null;
    }
  }

  Future<void> updatePosition(
      String token, double lat, double lng, int? etaMinutes) async {
    final client = SupabaseAuthService.instance.client;
    if (client == null) return;
    try {
      await client.from('trip_shares').update({
        'current_lat': lat,
        'current_lng': lng,
        'eta_minutes': etaMinutes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('share_token', token);
    } catch (_) {}
  }

  /// Stop sharing — deletes the row so the viewer link goes dead immediately
  /// rather than waiting for expires_at.
  Future<void> revoke(String token) async {
    final client = SupabaseAuthService.instance.client;
    if (client == null) return;
    try {
      await client.from('trip_shares').delete().eq('share_token', token);
    } catch (_) {}
  }
}
