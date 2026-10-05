import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized authentication service backed by Supabase Auth.
class SupabaseAuthService {
  SupabaseAuthService._();
  static final SupabaseAuthService instance = SupabaseAuthService._();

  bool _initialized = false;
  bool _configured = false;

  /// Returns true if Supabase was initialized with valid credentials.
  bool get isConfigured => _configured;

  /// Initialize Supabase Flutter SDK using credentials from environment variables.
  Future<void> init() async {
    if (_initialized) return;

    final String url = const String.fromEnvironment('SUPABASE_URL');
    final String anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty || url.contains('your-supabase-project-id')) {
      if (kDebugMode) {
        print('⚠️ Supabase credentials not configured via --dart-define');
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
          autoRefreshToken: true,
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
        'Supabase is not configured. Please pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define',
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
        'Supabase is not configured. Please pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define',
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
        'Supabase is not configured. Please pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define',
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
