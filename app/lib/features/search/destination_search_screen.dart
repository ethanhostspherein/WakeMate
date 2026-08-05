import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../models/destination.dart';
import '../../routing/app_router.dart';
import '../../state/trip_draft_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/primary_button.dart';

/// Destination Search — Places-style autocomplete (mock data in Phase 1) with
/// recents pinned on top, plus a map-pin toggle to drop a manual pin.
/// UI/UX Brief §3.5, App Flow §2.
class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  final _controller = TextEditingController();
  bool _mapMode = false;
  Destination? _selected;
  String _query = '';

  List<Destination> get _results {
    if (_query.isEmpty) return MockData.searchSuggestions;
    final q = _query.toLowerCase();
    return MockData.searchSuggestions
        .where((d) =>
            d.placeName.toLowerCase().contains(q) ||
            (d.address?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  void _select(Destination d) {
    setState(() => _selected = d);
  }

  void _confirm() {
    if (_selected == null) return;
    ref.read(tripDraftProvider.notifier).setDestination(_selected!);
    context.push(Routes.setAlarm);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search a place or station',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _mapMode ? _buildMapMode() : _buildListMode()),
            if (_selected != null) _ConfirmBar(
              destination: _selected!,
              onConfirm: _confirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListMode() {
    final results = _results;
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final d = results[i];
        final isRecent = i < 2 && _query.isEmpty;
        final selected = _selected == d;
        return ListTile(
          leading: Icon(
            isRecent ? Icons.history_rounded : Icons.place_outlined,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
          title: Text(d.placeName),
          subtitle: d.address != null ? Text(d.address!) : null,
          trailing: selected
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent)
              : null,
          selected: selected,
          selectedTileColor: AppColors.accentSoft,
          onTap: () => _select(d),
        );
      },
    );
  }

  Widget _buildMapMode() {
    // Manual pin drop — in Phase 1 this stands in for the live map's
    // draggable pin. Tapping "Drop pin here" selects a mock coordinate.
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const MapPreview(height: double.infinity),
                const Icon(Icons.place_rounded,
                    color: AppColors.accent, size: 48),
                Positioned(
                  bottom: AppSpacing.md,
                  left: 0,
                  right: 0,
                  child: PrimaryButton(
                    label: 'Drop pin here',
                    icon: Icons.push_pin_rounded,
                    onPressed: () => _select(const Destination(
                      placeName: 'Pinned location',
                      lat: 26.9124,
                      lng: 75.7873,
                      address: 'Dropped on map',
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

class _ConfirmBar extends StatelessWidget {
  final Destination destination;
  final VoidCallback onConfirm;
  const _ConfirmBar({required this.destination, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
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
                    Text(destination.placeName,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (destination.address != null)
                      Text(destination.address!,
                          style: Theme.of(context).textTheme.labelMedium),
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
