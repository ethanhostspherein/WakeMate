import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Small pill showing a trip's outcome — used on Home (recents) and History.
class TripStatusBadge extends StatelessWidget {
  final TripStatus status;

  const TripStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    late final IconData icon;

    switch (status) {
      case TripStatus.completed:
        color = AppColors.success;
        label = 'Reached';
        icon = Icons.check_circle_rounded;
        break;
      case TripStatus.cancelled:
        color = AppColors.textSecondary;
        label = 'Cancelled';
        icon = Icons.cancel_rounded;
        break;
      case TripStatus.active:
        color = AppColors.accent;
        label = 'Active';
        icon = Icons.my_location_rounded;
        break;
      case TripStatus.alarmTriggered:
        color = AppColors.warning;
        label = 'Alarm';
        icon = Icons.notifications_active_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
