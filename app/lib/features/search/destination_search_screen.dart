import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/destination.dart';
import '../../routing/app_router.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../state/trip_draft_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/primary_button.dart';

/// Destination Search — Live real-world place search via OpenStreetMap Nominatim
/// and current location GPS pin drop.
class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  final _controller = TextEditingController();
  final _geocoding = GeocodingService();
  final _location = LocationService();

  bool _mapMode = false;
  bool _searching = false;
  Destination? _selected;
  String _query = '';
  List<Destination> _searchResults = [];
  Timer? _debounce;

  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    final ready = await _location.ensureReady();
    if (ready) {
      final pos = await _location.currentPosition();
      if (pos != null && mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    setState(() => _query = val);
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      final results = await _geocoding.search(
        val,
        userLat: _userLat,
        userLng: _userLng,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  void _select(Destination d) {
    setState(() => _selected = d);
  }

  void _confirm() {
    if (_selected == null) return;
    ref.read(tripDraftProvider.notifier).setDestination(_selected!);
    context.push(Routes.setAlarm);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _searching = true);
    final pos = await _location.currentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch current GPS position.')),
      );
      return;
    }

    final dest = Destination(
      placeName: 'My Current Location',
      lat: pos.latitude,
      lng: pos.longitude,
      address: 'GPS Position (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
    );
    setState(() {
      _selected = dest;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set destination'),
        actions: [
          IconButton(
            tooltip: _mapMode ? 'List' : 'Drop a pin',
            onPressed: () => setState(() => _mapMode = !_mapMode),
            icon: Icon(_mapMode ? Icons.list_rounded : Icons.map_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: TextField(
                controller: _controller,
                autofocus: !_mapMode,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search real location, station, or city...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Quick current location button
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding),
              child: InkWell(
                onTap: _useCurrentLocation,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location_rounded, color: AppColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Use my current location',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            Expanded(child: _mapMode ? _buildMapMode() : _buildListMode()),
            if (_selected != null)
              _ConfirmBar(
                destination: _selected!,
                onConfirm: _confirm,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListMode() {
    if (_searching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Searching live locations...'),
          ],
        ),
      );
    }

    if (_query.isNotEmpty && _searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No matching places found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Try searching for a station name, city, landmark, or street.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final results = _searchResults;
    if (results.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Popular destinations:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            _PopularTile(title: 'Jaipur Junction', sub: 'Jaipur, Rajasthan', lat: 26.9196, lng: 75.7878),
            _PopularTile(title: 'New Delhi Railway Station', sub: 'New Delhi', lat: 28.6430, lng: 77.2194),
            _PopularTile(title: 'CSMT Station Mumbai', sub: 'Mumbai, Maharashtra', lat: 18.9400, lng: 72.8353),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final d = results[i];
        final selected = _selected?.placeName == d.placeName && _selected?.lat == d.lat;
        return ListTile(
          leading: Icon(
            Icons.place_outlined,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  d.placeName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (d.distanceFromUserKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${d.distanceFromUserKm!.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: d.address != null ? Text(d.address!, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
          trailing: selected
              ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
              : null,
          selected: selected,
          selectedTileColor: AppColors.accentSoft,
          onTap: () => _select(d),
        );
      },
    );
  }

  double _mapLat = 26.9124;
  double _mapLng = 75.7873;

  Widget _buildMapMode() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MapPreview(
                  height: double.infinity,
                  lat: _mapLat,
                  lng: _mapLng,
                  zoom: 14.0,
                  onTap: (point) {
                    setState(() {
                      _mapLat = point.latitude;
                      _mapLng = point.longitude;
                    });
                  },
                ),
                Positioned(
                  bottom: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: PrimaryButton(
                    label: 'Confirm pinned location',
                    icon: Icons.push_pin_rounded,
                    onPressed: () => _select(Destination(
                      placeName: 'Pinned Location (${_mapLat.toStringAsFixed(4)}, ${_mapLng.toStringAsFixed(4)})',
                      lat: _mapLat,
                      lng: _mapLng,
                      address: 'Selected on map',
                    )),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _PopularTile extends ConsumerWidget {
  final String title;
  final String sub;
  final double lat;
  final double lng;

  const _PopularTile({
    required this.title,
    required this.sub,
    required this.lat,
    required this.lng,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dest = Destination(placeName: title, lat: lat, lng: lng, address: sub);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.location_city_rounded, color: AppColors.accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub),
      onTap: () {
        ref.read(tripDraftProvider.notifier).setDestination(dest);
        context.push(Routes.setAlarm);
      },
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final Destination destination;
  final VoidCallback onConfirm;
  const _ConfirmBar({required this.destination, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.place_rounded, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.placeName, style: Theme.of(context).textTheme.titleMedium),
                    if (destination.address != null)
                      Text(destination.address!, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(label: 'Confirm destination', onPressed: onConfirm),
        ],
      ),
    );
  }
}
