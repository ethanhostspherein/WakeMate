import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/alarm_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/wakemate_logo.dart';

/// Settings / Profile — account info, default sound/volume/units, permission
/// shortcuts, premium entry point, and policy links. UI/UX Brief §3.10.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _metric = true;
  bool _vibrate = true;
  String _sound = AlarmSettings.defaults.soundId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          _ProfileCard(),
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
            onChanged: (v) => setState(() => _vibrate = v),
          ),
          _SwitchTile(
            icon: Icons.straighten_rounded,
            title: 'Use kilometres',
            subtitle: _metric ? 'km' : 'miles',
            value: _metric,
            onChanged: (v) => setState(() => _metric = v),
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
          _SectionLabel('WakeMate Premium'),
          _PremiumCard(),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel('About'),
          _Tile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy policy',
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () {}),
          _Tile(
              icon: Icons.description_rounded,
              title: 'Terms of service',
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () {}),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text('WakeMate v0.1.0 · Phase 1',
                style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            label: const Text('Sign out',
                style: TextStyle(color: AppColors.danger)),
          ),
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
    if (choice != null) setState(() => _sound = choice);
  }
}

class _ProfileCard extends StatelessWidget {
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
          const CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accentSoft,
            child: Icon(Icons.person_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Guest', style: Theme.of(context).textTheme.titleMedium),
              Text('Local-only · no sync',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const Spacer(),
          OutlinedButton(onPressed: () {}, child: const Text('Sign in')),
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
