import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/destination.dart';
import '../../models/favorite.dart';
import '../../models/trip.dart';
import '../../routing/app_router.dart';
import '../../services/location_service.dart';
import '../../services/user_trips_service.dart';
import '../../state/tracking_provider.dart';
import '../../state/trip_draft_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/trip_status_badge.dart';

/// Home — the launchpad. Dynamic user search, live location map preview,
/// real-time favorites, and user-created recent trips.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Trip> _recentTrips = [];
  List<Favorite> _favorites = [];
  Set<String> _favoriteNames = {};
  bool _loading = true;

  double? _userLat;
  double? _userLng;
  final _mapController = MapController();
  bool _mapCenteredOnUser = false;
  Destination? _pinnedDestination;
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<List<Trip>>? _tripsSub;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initLiveLocation();
    _subscribeTrips();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _tripsSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _subscribeTrips() {
    _tripsSub = UserTripsService.instance.recentTripsStream.listen((trips) {
      if (mounted) {
        setState(() {
          _recentTrips = trips;
        });
      }
    });
  }

  Future<void> _initLiveLocation() async {
    final location = LocationService();
    final pos = await location.currentPosition();
    if (mounted && pos != null) {
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      });
      _centerMapOnUserOnce(pos.latitude, pos.longitude);
    }

    _locationSub = location.positionStream(fine: false).listen((p) {
      if (mounted) {
        setState(() {
          _userLat = p.latitude;
          _userLng = p.longitude;
        });
        _centerMapOnUserOnce(p.latitude, p.longitude);
      }
    });
  }

  // MapOptions.initialCenter only applies on the map's first build, which
  // usually happens before this async location fetch resolves — so the map
  // needs an explicit move() the first time a fix comes in, or it stays
  // centered on the destination/fallback point with the user's marker
  // possibly off-screen. Only once, so it doesn't fight manual panning.
  void _centerMapOnUserOnce(double lat, double lng) {
    if (_mapCenteredOnUser) return;
    _mapCenteredOnUser = true;
    try {
      _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
    } catch (_) {}
  }

  Future<void> _loadUserData() async {
    final trips = await UserTripsService.instance.getRecentTrips();
    final favs = await UserTripsService.instance.getFavorites();
    if (!mounted) return;
    setState(() {
      _recentTrips = trips;
      _favorites = favs;
      _favoriteNames = favs.map((f) => f.placeName.toLowerCase()).toSet();
      _loading = false;
    });
  }

  void _startFromFavorite(Favorite fav) {
    ref.read(tripDraftProvider.notifier).setDestination(
          Destination(placeName: fav.placeName, lat: fav.lat, lng: fav.lng),
        );
    if (fav.defaultAlarmDistanceKm != null) {
      ref.read(tripDraftProvider.notifier).setDistance(fav.defaultAlarmDistanceKm!);
    }
    context.push(Routes.setAlarm).then((_) => _loadUserData());
  }

  void _startFromPinned() {
    if (_pinnedDestination == null) return;
    ref.read(tripDraftProvider.notifier).setDestination(_pinnedDestination!);
    context.push(Routes.setAlarm).then((_) => _loadUserData());
  }

  Future<void> _toggleFavoriteTrip(Trip trip) async {
    final nowFav = await UserTripsService.instance.toggleFavorite(
      trip.destination,
      defaultAlarmDistanceKm: trip.alarmDistanceKm,
    );
    await _loadUserData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowFav
              ? 'Added "${trip.destination.placeName}" to Favorites ⭐'
              : 'Removed "${trip.destination.placeName}" from Favorites',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recent Trip'),
        content: Text('Remove "${trip.destination.placeName}" from your recent trips?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await UserTripsService.instance.deleteTrip(trip.id);
      await _loadUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip deleted from history.')),
      );
    }
  }

  Future<void> _editTripDistance(Trip trip) async {
    double selectedKm = trip.alarmDistanceKm;
    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Alarm Distance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Destination: ${trip.destination.placeName}'),
              const SizedBox(height: 16),
              Text(
                '${selectedKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              Slider(
                value: selectedKm,
                min: 0.5,
                max: 20.0,
                divisions: 39,
                activeColor: AppColors.accent,
                onChanged: (val) {
                  setDialogState(() => selectedKm = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedKm),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (updated != null) {
      await UserTripsService.instance.updateTripDistance(trip.id, updated);
      await _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchBar(onTap: () => context.push(Routes.search).then((_) => _loadUserData())),
                      const SizedBox(height: AppSpacing.md),
                      Stack(
                        children: [
                          MapPreview(
                            height: 170,
                            mapController: _mapController,
                            lat: _pinnedDestination?.lat ?? (_recentTrips.isNotEmpty ? _recentTrips.first.destination.lat : 26.9124),
                            lng: _pinnedDestination?.lng ?? (_recentTrips.isNotEmpty ? _recentTrips.first.destination.lng : 75.7873),
                            userLat: _userLat,
                            userLng: _userLng,
                            destinationLabel: _pinnedDestination?.placeName ??
                                (_recentTrips.isNotEmpty
                                    ? _recentTrips.first.destination.placeName
                                    : 'Tap map to mark location'),
                            onTap: (LatLng point) {
                              setState(() {
                                _pinnedDestination = Destination(
                                  placeName: 'Pinned Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
                                  lat: point.latitude,
                                  lng: point.longitude,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      if (_pinnedDestination != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(color: AppColors.accent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pin_drop_rounded, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _pinnedDestination!.placeName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _startFromPinned,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: const Text('Set Alarm'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionHeader(title: 'Favorites'),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _favorites.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star_outline_rounded, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Text('No saved favorites yet', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    : _FavoritesRow(
                        favorites: _favorites,
                        onTap: _startFromFavorite,
                      ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.lg,
                    AppSpacing.screenPadding,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionHeader(title: 'Recent trips'),
                      if (_recentTrips.isNotEmpty)
                        TextButton(
                          onPressed: () => context.push(Routes.history),
                          child: const Text('See all'),
                        ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_recentTrips.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.explore_outlined, size: 40, color: AppColors.accent),
                          const SizedBox(height: 8),
                          const Text(
                            'No recent trips yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Search a place or tap + New trip to set your first alarm!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context.push(Routes.search).then((_) => _loadUserData()),
                            icon: const Icon(Icons.search),
                            label: const Text('Search Destination'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: _recentTrips.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final trip = _recentTrips[i];
                    final isFav = _favoriteNames.contains(trip.destination.placeName.toLowerCase());
                    final isActiveTrip = trackingState.isActive && trackingState.trip?.id == trip.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                      child: _RecentTile(
                        trip: trip,
                        isFavorite: isFav,
                        isActive: isActiveTrip,
                        onTap: () {
                          // If trip is currently active or tracking is active, navigate to active tracking screen (Stop/Test options)
                          if (trackingState.isActive || trip.status == TripStatus.active) {
                            context.push(Routes.tracking);
                          } else {
                            ref.read(tripDraftProvider.notifier).setDestination(trip.destination);
                            ref.read(tripDraftProvider.notifier).setDistance(trip.alarmDistanceKm);
                            context.push(Routes.setAlarm).then((_) => _loadUserData());
                          }
                        },
                        onToggleFavorite: () => _toggleFavoriteTrip(trip),
                        onEdit: () => _editTripDistance(trip),
                        onDelete: () => _deleteTrip(trip),
                      ),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.search).then((_) => _loadUserData()),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi there 👋', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  'Where are you headed?',
                  style: Theme.of(context).textTheme.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
            Text('Where are you headed?', style: Theme.of(context).textTheme.bodyMedium),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
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
                  Icon(_iconFor(fav.placeName), color: AppColors.accent, size: 24),
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
  final bool isFavorite;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecentTile({
    required this.trip,
    required this.isFavorite,
    this.isActive = false,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final activeState = isActive || trip.status == TripStatus.active;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: activeState ? AppColors.accent : AppColors.border, width: activeState ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      trip.mode == TripMode.train ? Icons.train_rounded : Icons.location_on_rounded,
                      color: AppColors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trip.destination.placeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            TripStatusBadge(status: trip.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDate(trip.createdAt)} • Alarm at ${trip.alarmDistanceKm.toStringAsFixed(1)} km${trip.pnr != null && trip.pnr!.isNotEmpty ? ' • PNR: ${trip.pnr}' : ''}',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  tooltip: isFavorite ? 'Remove Favorite' : 'Mark Favorite',
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFavorite ? Colors.amber : AppColors.textSecondary,
                  ),
                  onPressed: onToggleFavorite,
                ),
                IconButton(
                  tooltip: 'Edit distance',
                  icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Delete trip',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: onDelete,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onTap,
                  icon: Icon(activeState ? Icons.my_location_rounded : Icons.alarm_add_rounded, size: 18),
                  label: Text(activeState ? 'View Tracking' : 'Set Alarm'),
                  style: TextButton.styleFrom(
                    foregroundColor: activeState ? AppColors.success : AppColors.accent,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }
}
