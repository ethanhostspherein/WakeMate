import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/trip.dart';
import '../../services/user_trips_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/trip_status_badge.dart';

/// History Screen — list of past trips with destination, date, distance and a
/// status badge; tapping opens a read-only summary. UI/UX Brief §3.9.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Trip> _trips = [];
  bool _loading = true;
  StreamSubscription<List<Trip>>? _tripsSub;

  @override
  void initState() {
    super.initState();
    _loadTrips();
    _tripsSub = UserTripsService.instance.recentTripsStream.listen((trips) {
      if (mounted) {
        setState(() {
          _trips = trips;
        });
      }
    });
  }

  @override
  void dispose() {
    _tripsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    final trips = await UserTripsService.instance.getRecentTrips();
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip history')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? const _EmptyHistory()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  itemCount: _trips.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => i == 0
                      ? _StatsSummary(trips: _trips)
                      : _HistoryTile(trip: _trips[i - 1]),
                ),
    );
  }
}

/// Travel stats/journal — total distance, trip count, distinct places, from
/// the already-loaded recent-trips list. No new service call or route.
/// ponytail: reflects only the last 20 trips (existing recent-trips cap);
/// good enough for a V1 journal, raise the cap later if users want history.
class _StatsSummary extends StatelessWidget {
  final List<Trip> trips;
  const _StatsSummary({required this.trips});

  @override
  Widget build(BuildContext context) {
    final totalKm = trips.fold<double>(
        0, (sum, t) => sum + (t.distanceTravelledKm ?? 0));
    final places = trips.map((t) => t.destination.placeName).toSet().length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _StatItem(value: totalKm.toStringAsFixed(0), label: 'km travelled'),
          _StatItem(value: '${trips.length}', label: 'trips'),
          _StatItem(value: '$places', label: 'places'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
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
                  Icon(
                    trip.mode == TripMode.train ? Icons.train_rounded : Icons.directions_bus_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
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
                      'Alarm: ${trip.alarmDistanceKm.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.labelMedium),
                  if (trip.pnr != null && trip.pnr!.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.md),
                    Text('PNR: ${trip.pnr}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                  ],
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
            _summaryRow(context, 'Mode', trip.mode.name.toUpperCase()),
            if (trip.pnr != null && trip.pnr!.isNotEmpty)
              _summaryRow(context, 'PNR Number', trip.pnr!),
            _summaryRow(context, 'Date', _formatDate(trip.createdAt)),
            _summaryRow(context, 'Alarm distance',
                '${trip.alarmDistanceKm.toStringAsFixed(1)} km'),
            _summaryRow(
                context,
                'Status',
                trip.status == TripStatus.completed
                    ? 'Completed ✅'
                    : trip.status == TripStatus.active
                        ? 'Active 🟢'
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
