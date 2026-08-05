import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/destination.dart';
import '../../routing/app_router.dart';
import '../../services/geocoding_service.dart';
import '../../services/ticket_parser.dart';
import '../../state/trip_draft_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/map_preview.dart';
import '../../widgets/primary_button.dart';

/// Confirm a trip detected from a shared ticket before tracking. Geocodes the
/// parsed destination (keyless, via OSM) and lets the user correct it.
/// Implements the "Share-to-WakeMate" intake path.
class SharedTripScreen extends ConsumerStatefulWidget {
  final ParsedTicket ticket;
  const SharedTripScreen({super.key, required this.ticket});

  @override
  ConsumerState<SharedTripScreen> createState() => _SharedTripScreenState();
}

class _SharedTripScreenState extends ConsumerState<SharedTripScreen> {
  final _geocoder = GeocodingService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  Destination? _destination;
  bool _resolving = true;
  bool _editing = false;
  List<Destination> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _resolveInitial();
  }

  Future<void> _resolveInitial() async {
    final name = widget.ticket.destinationName;
    if (name == null) {
      setState(() {
        _resolving = false;
        _editing = true;
      });
      return;
    }
    final match = await _geocoder.resolve(name);
    if (!mounted) return;
    setState(() {
      _destination = match;
      _resolving = false;
      _editing = match == null;
      if (match == null) _searchController.text = name;
    });
    // Auto-resolve failed (e.g. rate-limited) — surface candidate matches for
    // the parsed name straight away instead of an empty search box.
    if (match == null) _search(name);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _geocoder.search(value);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _pick(Destination d) {
    setState(() {
      _destination = d;
      _editing = false;
      _results = [];
    });
  }

  void _confirm() {
    if (_destination == null) return;
    ref.read(tripDraftProvider.notifier).setFromShared(
          destination: _destination!,
          departureAt: widget.ticket.departureAt,
        );
    context.go(Routes.setAlarm);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Scaffold(
      appBar: AppBar(title: const Text('Trip from your ticket')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.accent, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'We picked this up from what you shared. Check the details before tracking.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (t.pnr != null) _InfoChip(
                    icon: Icons.confirmation_number_rounded,
                    label: 'PNR ${t.pnr}',
                    note: 'Live train tracking arrives with Train Mode.',
                  ),
                  if (t.departureAt != null) _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: 'Departs ${_formatDate(t.departureAt!)}',
                    note: "We'll offer to arm the alarm at departure.",
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Destination',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  if (_resolving)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_editing || _destination == null)
                    _buildSearch()
                  else
                    _buildResolved(_destination!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: PrimaryButton(
                label: 'Confirm destination',
                onPressed: _destination == null ? null : _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolved(Destination d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MapPreview(height: 120, destinationLabel: d.placeName),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_rounded, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.placeName,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (d.address != null)
                      Text(d.address!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _editing = true),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.ticket.destinationName != null && _destination == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              "Couldn't pin “${widget.ticket.destinationName}” exactly — search for it below.",
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.warning),
            ),
          ),
        TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search station or place',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ..._results.map((d) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined,
                  color: AppColors.textSecondary),
              title: Text(d.placeName),
              subtitle: d.address != null
                  ? Text(d.address!,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () => _pick(d),
            )),
      ],
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $hh:$mm';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String note;
  const _InfoChip(
      {required this.icon, required this.label, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(note, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
