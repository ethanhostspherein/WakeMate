import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/alarm_settings.dart';
import '../../routing/app_router.dart';
import '../../services/supabase_auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/wakemate_logo.dart';

/// Settings / Profile — account info, default sound/volume/units, permission
/// shortcuts, premium entry point, policy links, real-time auth sign-out & guest sign-in.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _metric = true;
  bool _vibrate = true;
  String _sound = AlarmSettings.defaults.soundId;
  final _auth = SupabaseAuthService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _metric = prefs.getBool('pref_metric') ?? true;
      _vibrate = prefs.getBool('pref_vibrate') ?? true;
      _sound = prefs.getString('pref_sound') ?? AlarmSettings.defaults.soundId;
    });
  }

  Future<void> _saveBool(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  Future<void> _saveString(String key, String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
  }

  Future<void> _handleSignOut() async {
    await _auth.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signed out successfully.'),
        backgroundColor: AppColors.primary,
      ),
    );
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAuthenticated = _auth.isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _ProfileCard(
            userEmail: user?.email,
            isAuthenticated: isAuthenticated,
            onSignIn: () => context.go(Routes.login),
            onSignOut: _handleSignOut,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Alarm defaults'),
          _Tile(
            icon: Icons.music_note_rounded,
            title: 'Default sound',
            trailing: Text(AlarmSound.labelFor(_sound),
                style: Theme.of(context).textTheme.bodyMedium),
            onTap: _pickSound,
          ),
          _SwitchTile(
            icon: Icons.vibration_rounded,
            title: 'Vibrate with alarm',
            value: _vibrate,
            onChanged: (v) {
              setState(() => _vibrate = v);
              _saveBool('pref_vibrate', v);
            },
          ),
          _SwitchTile(
            icon: Icons.straighten_rounded,
            title: 'Use kilometres',
            subtitle: _metric ? 'km' : 'miles',
            value: _metric,
            onChanged: (v) {
              setState(() => _metric = v);
              _saveBool('pref_metric', v);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('Permissions'),
          _Tile(
            icon: Icons.location_on_rounded,
            title: 'Location & background access',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: openAppSettings,
          ),
          _Tile(
            icon: Icons.battery_saver_rounded,
            title: 'Battery optimization',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: openAppSettings,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('App Tour'),
          _Tile(
            icon: Icons.slideshow_rounded,
            title: 'Re-watch Onboarding',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go(Routes.onboarding),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('WakeMate Premium'),
          _PremiumCard(),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('About'),
          _Tile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy policy',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.privacyPolicy)),
          _Tile(
              icon: Icons.description_rounded,
              title: 'Terms of service',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.termsOfService)),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text('WakeMate v1.0.0',
                style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(height: AppSpacing.md),

          if (isAuthenticated) ...[
            TextButton.icon(
              onPressed: _handleSignOut,
              icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
              label: const Text(
                'Sign out of account',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            TextButton.icon(
              onPressed: () => context.go(Routes.login),
              icon: const Icon(Icons.login_rounded, color: AppColors.accent),
              label: const Text(
                'Sign in with Email',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _pickSound() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AlarmSound.all
              .map((s) => ListTile(
                    title: Text(s.label),
                    trailing: s.id == _sound
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.accent)
                        : null,
                    onTap: () => Navigator.pop(context, s.id),
                  ))
              .toList(),
        ),
      ),
    );
    if (choice != null) {
      setState(() => _sound = choice);
      _saveString('pref_sound', choice);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final String? userEmail;
  final bool isAuthenticated;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  const _ProfileCard({
    required this.userEmail,
    required this.isAuthenticated,
    required this.onSignIn,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: isAuthenticated ? AppColors.accentSoft : AppColors.border,
            child: Icon(
              isAuthenticated ? Icons.person_rounded : Icons.person_outline_rounded,
              color: isAuthenticated ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAuthenticated ? (userEmail ?? 'Logged In User') : 'Guest Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isAuthenticated ? 'Account active · Cloud sync' : 'Local-only · No sync',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isAuthenticated ? AppColors.success : AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (isAuthenticated) ...[
            OutlinedButton(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              child: const Text('Sign out'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign in'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const WakeMateLogo(size: 40, onDark: true),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Go ad-free for ₹99',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text('One-time lifetime unlock',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
      child: Text(text.toUpperCase(),
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(letterSpacing: 0.8)),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;
  const _Tile(
      {required this.icon,
      required this.title,
      this.trailing,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.accent),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        activeThumbColor: AppColors.accent,
        onChanged: onChanged,
      ),
    );
  }
}
