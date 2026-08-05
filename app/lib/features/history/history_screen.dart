import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/trip.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/trip_status_badge.dart';

/// History Screen — list of past trips with destination, date, distance and a
/// status badge; tapping opens a read-only summary. UI/UX Brief §3.9.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = MockData.recentTrips();

    return Scaffold(
      appBar: AppBar(title: const Text('Trip history')),
      body: trips.isEmpty
          ? const _EmptyHistory()
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: trips.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _HistoryTile(trip: trips[i]),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Trip trip;
  const _HistoryTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _showSummary(context, trip),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(trip.destination.placeName,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TripStatusBadge(status: trip.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(_formatDate(trip.createdAt),
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: AppSpacing.md),
                  const Icon(Icons.straighten_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                      '${trip.distanceTravelledKm?.toStringAsFixed(0) ?? '—'} km',
                      style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSummary(BuildContext context, Trip trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.destination.placeName,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            _summaryRow(context, 'Date', _formatDate(trip.createdAt)),
            _summaryRow(context, 'Distance travelled',
                '${trip.distanceTravelledKm?.toStringAsFixed(0) ?? '—'} km'),
            _summaryRow(context, 'Alarm distance',
                '${trip.alarmDistanceKm.toStringAsFixed(0)} km'),
            _summaryRow(context, 'Alarm fired',
                trip.alarmTriggered ? 'Yes' : 'No'),
            _summaryRow(
                context,
                'Outcome',
                trip.reachedSuccessfully
                    ? 'Reached successfully'
                    : 'Cancelled'),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded,
              size: 64, color: AppColors.disabled),
          const SizedBox(height: AppSpacing.md),
          Text('No trips yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Your completed journeys will show up here.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
