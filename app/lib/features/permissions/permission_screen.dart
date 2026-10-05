import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../routing/app_router.dart';
import '../../services/battery_optimization.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/primary_button.dart';

enum _PermStatus { pending, granted, denied }

class _PermStep {
  final String title;
  final String reason;
  final IconData icon;
  const _PermStep(this.title, this.reason, this.icon);
}

/// Permission Screen — sequential, single-purpose requests, each with a
/// one-line plain-language reason before the system dialog fires.
/// Location → Background Location → Notifications → Battery optimization.
/// UI/UX Brief §3.3, App Flow §2, TRD §4.1.
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  static const _steps = [
    _PermStep(
      'Location',
      'To know where you are and how far you are from your stop.',
      Icons.my_location_rounded,
    ),
    _PermStep(
      'Background location',
      "So the alarm still works when your phone is locked or the app is closed. Please choose “Allow all the time”.",
      Icons.location_on_rounded,
    ),
    _PermStep(
      'Notifications',
      'To show the tracking status and fire the wake-up alarm.',
      Icons.notifications_active_rounded,
    ),
    _PermStep(
      'Battery optimization',
      "So Android doesn't kill tracking to save power mid-trip.",
      Icons.battery_saver_rounded,
    ),
  ];

  final _status = List<_PermStatus>.filled(_steps.length, _PermStatus.pending);
  int _current = 0;
  bool _busy = false;
  String? _oemInstruction;

  bool get _allResolved =>
      _status.every((s) => s != _PermStatus.pending);

  @override
  void initState() {
    super.initState();
    // OEM autostart/background-kill managers (Samsung, Xiaomi, Oppo, Vivo,
    // Huawei) sit on top of standard Android battery optimization and have
    // no runtime permission of their own — surface plain instructions here.
    BatteryOptimization.manufacturer().then((m) {
      if (!mounted) return;
      setState(() => _oemInstruction = BatteryOptimization.instructionsFor(m));
    });
  }

  Future<void> _request(int index) async {
    setState(() => _busy = true);
    _PermStatus result;
    switch (index) {
      case 0:
        result = _map(await Permission.locationWhenInUse.request());
        break;
      case 1:
        result = _map(await Permission.locationAlways.request());
        break;
      case 2:
        result = _map(await Permission.notification.request());
        break;
      case 3:
        // Battery-optimization exemption: opens the OEM/OS settings screen.
        final status =
            await Permission.ignoreBatteryOptimizations.request();
        result = _map(status);
        break;
      default:
        result = _PermStatus.pending;
    }

    if (!mounted) return;
    setState(() {
      _status[index] = result;
      _busy = false;
      if (_current < _steps.length - 1) _current = index + 1;
    });
  }

  _PermStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return _PermStatus.granted;
    return _PermStatus.denied;
  }

  void _continue() => context.go(Routes.home);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('A few permissions',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "WakeMate needs these to wake you reliably. We'll ask one at a time.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView.separated(
                  itemCount: _steps.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _PermCard(
                    step: _steps[i],
                    status: _status[i],
                    isActive: i == _current,
                    busy: _busy && i == _current,
                    onAllow: () => _request(i),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_status[1] == _PermStatus.denied)
                const _BackgroundDeniedBanner(),
              if (_oemInstruction != null)
                _OemInstructionBanner(text: _oemInstruction!),
              const _BackgroundHelpSection(),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: _allResolved ? 'Continue' : 'Continue anyway',
                onPressed: _continue,
                color: _allResolved ? AppColors.accent : AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  final _PermStep step;
  final _PermStatus status;
  final bool isActive;
  final bool busy;
  final VoidCallback onAllow;

  const _PermCard({
    required this.step,
    required this.status,
    required this.isActive,
    required this.busy,
    required this.onAllow,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status == _PermStatus.granted;
    final denied = status == _PermStatus.denied;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: granted
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              granted ? Icons.check_rounded : step.icon,
              color: granted ? AppColors.success : AppColors.accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(step.reason,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                if (granted)
                  const _StatusText('Granted', AppColors.success)
                else
                  Row(
                    children: [
                      SizedBox(
                        height: 36,
                        child: TextButton(
                          onPressed: busy ? null : onAllow,
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.accentSoft,
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Text(denied ? 'Try again' : 'Allow'),
                        ),
                      ),
                      if (denied) ...[
                        const SizedBox(width: AppSpacing.xs),
                        TextButton(
                          onPressed: openAppSettings,
                          child: const Text('Settings'),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusText(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

/// Warns about the manufacturer's own autostart/background-kill manager
/// (separate from standard Android battery optimization above) and offers a
/// best-effort deep link straight to it.
class _OemInstructionBanner extends StatelessWidget {
  final String text;
  const _OemInstructionBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android_rounded,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Your phone may still stop tracking in the background '
                  'unless you also allow this:',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.warning, fontWeight: FontWeight.w600)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: BatteryOptimization.openOemSettings,
              style: TextButton.styleFrom(foregroundColor: AppColors.warning),
              child: const Text('Open settings'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Always-visible self-help reference: how to allow WakeMate to run in the
/// background on each major manufacturer, for when auto-detection above
/// ([_OemInstructionBanner]) can't identify the device or the user wants to
/// double-check another step. Collapsed by default to stay out of the way.
class _BackgroundHelpSection extends StatelessWidget {
  const _BackgroundHelpSection();

  static const _manufacturers = [
    'samsung',
    'xiaomi',
    'oppo',
    'vivo',
    'huawei',
    'oneplus',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.phone_android_rounded, color: AppColors.accent),
        title: const Text('Keep WakeMate running in the background',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Steps for your phone brand, in case the alarm gets killed'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in _manufacturers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label(m),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(BatteryOptimization.instructionsFor(m) ?? '',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                Text('Other phones',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                    'Settings → Apps → WakeMate → Battery → set to "Unrestricted" '
                    'or "No restrictions".',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: BatteryOptimization.openOemSettings,
                    child: const Text('Open my phone\'s settings'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _label(String m) {
    switch (m) {
      case 'samsung':
        return 'Samsung';
      case 'xiaomi':
        return 'Xiaomi / Redmi / Poco';
      case 'oppo':
        return 'Oppo / Realme';
      case 'vivo':
        return 'Vivo';
      case 'huawei':
        return 'Huawei / Honor';
      case 'oneplus':
        return 'OnePlus';
      default:
        return m;
    }
  }
}

class _BackgroundDeniedBanner extends StatelessWidget {
  const _BackgroundDeniedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Without “Allow all the time”, the alarm may not fire when your phone is locked.',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
