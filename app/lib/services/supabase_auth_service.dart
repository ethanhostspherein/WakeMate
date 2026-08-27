import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized authentication service backed by Supabase Auth.
class SupabaseAuthService {
  SupabaseAuthService._();
  static final SupabaseAuthService instance = SupabaseAuthService._();

  bool _initialized = false;
  bool _configured = false;

  /// Returns true if Supabase was initialized with valid credentials.
  bool get isConfigured => _configured;

  /// Initialize Supabase Flutter SDK using credentials from `.env` or defaults.
  Future<void> init() async {
    if (_initialized) return;

    String url = '';
    String anonKey = '';

    try {
      await dotenv.load(fileName: '.env');
      url = dotenv.env['SUPABASE_URL'] ?? '';
      anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    } catch (_) {
      // Dotenv file might not exist or failed to load
    }

    if (url.isEmpty || anonKey.isEmpty || url.contains('your-supabase-project-id')) {
      if (kDebugMode) {
        print('⚠️ Supabase credentials not configured in app/.env');
      }
      _initialized = true;
      _configured = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
          autoRefreshToken: false,
        ),
      );
      _configured = true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error initializing Supabase: $e');
      }
    }

    _initialized = true;
  }

  /// Get the current Supabase client instance (or null if not initialized).
  SupabaseClient? get client => _configured ? Supabase.instance.client : null;

  /// Check if a user currently has an active, authenticated session.
  bool get isAuthenticated => client?.auth.currentSession != null;

  /// Get currently signed-in user.
  User? get currentUser => client?.auth.currentUser;

  /// Stream of Auth State changes.
  Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  /// Send Email OTP code to user's email.
  Future<void> sendOtp(String email) async {
    if (!_configured || client == null) {
      throw Exception(
        'Supabase is not configured. Please paste your SUPABASE_URL and SUPABASE_ANON_KEY in app/.env',
      );
    }

    await client!.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  /// Send Email Magic Link to user's email.
  Future<void> sendMagicLink(String email) async {
    if (!_configured || client == null) {
      throw Exception(
        'Supabase is not configured. Please paste your SUPABASE_URL and SUPABASE_ANON_KEY in app/.env',
      );
    }

    await client!.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: 'wakemate://login-callback',
      shouldCreateUser: true,
    );
  }

  /// Verify 6-digit OTP code sent to user's email.
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    if (!_configured || client == null) {
      throw Exception(
        'Supabase is not configured. Please paste your SUPABASE_URL and SUPABASE_ANON_KEY in app/.env',
      );
    }

    final response = await client!.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );

    return response;
  }

  /// Sign out current user.
  Future<void> signOut() async {
    if (!_configured || client == null) return;
    await client!.auth.signOut();
  }
}
