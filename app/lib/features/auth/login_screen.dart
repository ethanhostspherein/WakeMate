import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routing/app_router.dart';
import '../../services/supabase_auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/wakemate_logo.dart';

/// Authentication Screen supporting Email Magic Link & 6-digit OTP Verification.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum AuthMode { emailInput, magicLinkSent, otpInput }

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _auth = SupabaseAuthService.instance;

  AuthMode _mode = AuthMode.emailInput;
  bool _loading = false;
  String? _errorMessage;

  StreamSubscription<AuthState>? _authSub;
  Timer? _timer;
  int _resendCountdown = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _auth.authStateChanges?.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || data.session != null) {
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login verified successfully! Welcome to WakeMate.'),
            backgroundColor: AppColors.success,
          ),
        );

        context.go(seenOnboarding ? Routes.home : Routes.permissions);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  Future<void> _handleSendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _auth.sendMagicLink(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _mode = AuthMode.magicLinkSent;
      });
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification link sent to $email'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      String msg = raw.replaceAll('Exception: ', '');
      if (raw.contains('Error sending confirmation email') || raw.contains('unexpected_failure')) {
        msg = 'Error sending email. Please check your Supabase SMTP settings or turn OFF Custom SMTP.';
      }
      setState(() {
        _loading = false;
        _errorMessage = msg;
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code sent to your email.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _auth.verifyOtp(email: email, token: otp);
      if (!mounted) return;

      if (res.session != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful! Welcome to WakeMate.'),
            backgroundColor: AppColors.success,
          ),
        );

        context.go(seenOnboarding ? Routes.home : Routes.permissions);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = 'Invalid or expired code. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = _auth.isConfigured;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Center(child: WakeMateLogo(size: 72)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'WakeMate',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _mode == AuthMode.magicLinkSent
                    ? 'Check your inbox to verify your email'
                    : 'Sign in to access your trips and saved alarms',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (!configured) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Supabase credentials required',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Please add your SUPABASE_URL and SUPABASE_ANON_KEY to app/.env to test live authentication.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 14),
                  ),
                ),
              ],

              if (_mode == AuthMode.emailInput) ...[
                // Mode 1: Email Input
                Text(
                  'Email address',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleSendMagicLink(),
                  decoration: InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Send Verification Link',
                  icon: Icons.send_rounded,
                  loading: _loading,
                  onPressed: _handleSendMagicLink,
                ),
              ] else if (_mode == AuthMode.magicLinkSent) ...[
                // Mode 2: Magic Link Sent State
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_rounded, size: 38, color: AppColors.accent),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Check your email',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'We sent a confirmation link to:\n${_emailController.text.trim()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, color: AppColors.accent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap "Confirm your email address" in Gmail to sign in automatically.',
                                style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_canResend) ...[
                      Text(
                        'Resend link in ${_resendCountdown}s',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: _loading ? null : _handleSendMagicLink,
                        child: const Text(
                          'Resend Link',
                          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    const Text(' · ', style: TextStyle(color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: () => setState(() => _mode = AuthMode.emailInput),
                      child: const Text('Change Email', style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _mode = AuthMode.otpInput),
                    icon: const Icon(Icons.pin_rounded, size: 18),
                    label: const Text('Have a 6-digit code? Enter OTP'),
                  ),
                ),
              ] else ...[
                // Mode 3: Manual 6-digit OTP Code Input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Verification code',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _mode = AuthMode.emailInput),
                      child: const Text(
                        'Change email',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: 'Verify & Continue',
                  icon: Icons.check_circle_outline_rounded,
                  loading: _loading,
                  onPressed: _handleVerifyOtp,
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _mode = AuthMode.magicLinkSent),
                    child: const Text('Back to Magic Link'),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              // Guest Mode Fallback
              Center(
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
                    if (!context.mounted) return;
                    context.go(seenOnboarding ? Routes.home : Routes.permissions);
                  },
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
