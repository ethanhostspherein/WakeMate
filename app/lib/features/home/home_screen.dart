import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../models/destination.dart';
import '../../models/favorite.dart';
import '../../models/trip.dart';
import '../../routing/app_router.dart';
import '../../state/trip_draft_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/trip_status_badge.dart';

/// Home — the launchpad. Search, map preview, favorites (one-tap re-trip),
/// and recent trips. UI/UX Brief §3.4, App Flow §2–3.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _startFromFavorite(
      BuildContext context, WidgetRef ref, Favorite fav) {
    // Fast path: pre-fill the draft and jump straight to Set Alarm.
    ref.read(tripDraftProvider.notifier).setDestination(
          Destination(
              placeName: fav.placeName, lat: fav.lat, lng: fav.lng),
        );
    if (fav.defaultAlarmDistanceKm != null) {
      ref
          .read(tripDraftProvider.notifier)
          .setDistance(fav.defaultAlarmDistanceKm!);
    }
    context.push(Routes.setAlarm);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = MockData.recentTrips();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(
                        onTap: () => context.push(Routes.search)),
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: () => context.push(Routes.search),
                      child: const MapPreview(
                        height: 150,
                        destinationLabel: 'Jaipur, Rajasthan',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(title: 'Favorites'),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _FavoritesRow(
              favorites: MockData.favorites,
              onTap: (f) => _startFromFavorite(context, ref, f),
            )),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
                    AppSpacing.lg, AppSpacing.screenPadding, AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(title: 'Recent trips'),
                    TextButton(
                      onPressed: () => context.push(Routes.history),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.separated(
              itemCount: recents.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                child: _RecentTile(
                  trip: recents[i],
                  onTap: () {
                    ref
                        .read(tripDraftProvider.notifier)
                        .setDestination(recents[i].destination);
                    ref
                        .read(tripDraftProvider.notifier)
                        .setDistance(recents[i].alarmDistanceKm);
                    context.push(Routes.setAlarm);
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.search),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('New trip'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding,
          AppSpacing.md, AppSpacing.screenPadding, AppSpacing.md),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi there 👋',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text('Where are you headed?',
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.push(Routes.settings),
            icon: const CircleAvatar(
              backgroundColor: AppColors.accentSoft,
              child: Icon(Icons.person_rounded, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text('Where are you headed?',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _FavoritesRow extends StatelessWidget {
  final List<Favorite> favorites;
  final ValueChanged<Favorite> onTap;
  const _FavoritesRow({required this.favorites, required this.onTap});

  IconData _iconFor(String name) {
    final n = name.toLowerCase();
    if (n.contains('home')) return Icons.home_rounded;
    if (n.contains('office')) return Icons.work_rounded;
    if (n.contains('college') || n.contains('school')) {
      return Icons.school_rounded;
    }
    return Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding),
        itemCount: favorites.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final fav = favorites[i];
          return GestureDetector(
            onTap: () => onTap(fav),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(_iconFor(fav.placeName),
                      color: AppColors.accent, size: 24),
                  Flexible(
                    child: Text(
                      fav.placeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const _RecentTile({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.train_rounded,
                    color: AppColors.accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.destination.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(trip.createdAt)} · ${trip.distanceTravelledKm?.toStringAsFixed(0) ?? '—'} km',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              TripStatusBadge(status: trip.status),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
