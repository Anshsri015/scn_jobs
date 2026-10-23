import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/core/widgets/chip_group.dart';
import 'package:scn_jobs/domain/entities/master_data.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';

/// Prefix marking a locality id as user-typed rather than a real
/// `LocationItem.id` from master data — see [CascadingLocationPicker]'s
/// class doc for why a freeform entry has no backend id to submit.
const String _kCustomLocationPrefix = 'custom:';

/// Three-level State -> City -> Locality cascade, matching the Master
/// Data API's real shape: `id` only exists at the locality tier
/// (`GET /master/locations/:city/localities?state=`), so that's the
/// only id ever submitted (job posting, worker preferred locations).
/// States and cities are plain strings, fetched on demand from their
/// own endpoints as the worker narrows down — there's no single flat
/// "all locations" endpoint meant for this UI (the closest thing,
/// `GET /master/locations`, is an unfiltered legacy dump the doc
/// explicitly says to avoid for per-state cities).
///
/// [selectedLocalityIds] persists across state/city switches —
/// switching state or city only changes which localities are *shown*,
/// it doesn't clear an already-made selection from elsewhere (a worker
/// can prefer localities across multiple cities/states).
///
/// State/city picking is done through a searchable bottom sheet
/// (`_showSearchSheet`) rather than `DropdownButtonFormField` — the
/// plain dropdown's overlay menu grows to cover almost the entire
/// screen once a state/city list has more than a handful of entries,
/// with no way to filter it. The bottom sheet is height-capped and has
/// its own search field.
///
/// Locality selection is limited to master-data results only — there's
/// no "type your own locality" entry point here. `_kCustomLocationPrefix`
/// is kept only so any `custom:<name>` id a worker saved before this was
/// removed still resolves to a readable label instead of the raw id.
class CascadingLocationPicker extends ConsumerStatefulWidget {
  const CascadingLocationPicker({
    required this.selectedLocalityIds,
    required this.onChanged,
    super.key,
  });

  final Set<String> selectedLocalityIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  ConsumerState<CascadingLocationPicker> createState() =>
      _CascadingLocationPickerState();
}

class _CascadingLocationPickerState
    extends ConsumerState<CascadingLocationPicker> {
  String? _selectedState;
  String? _selectedCity;
  final TextEditingController _localitySearchController =
  TextEditingController();

  /// Best-effort id -> display name cache, filled in as locality lists
  /// load and as custom entries are typed. A previously-selected master
  /// id whose city hasn't been revisited this session has no cached
  /// label yet, so the "Selected" chips fall back to the raw id for
  /// those until that city is opened again.
  final Map<String, String> _labelsById = {};

  @override
  void initState() {
    super.initState();
    for (final id in widget.selectedLocalityIds) {
      if (id.startsWith(_kCustomLocationPrefix)) {
        _labelsById[id] = id.substring(_kCustomLocationPrefix.length);
      }
    }
  }

  @override
  void dispose() {
    _localitySearchController.dispose();
    super.dispose();
  }

  void _toggleLocality(String localityId, bool selected) {
    final updated = Set<String>.from(widget.selectedLocalityIds);
    if (selected) {
      updated.add(localityId);
    } else {
      updated.remove(localityId);
    }
    widget.onChanged(updated);
  }

  void _removeSelected(String id) {
    final updated = Set<String>.from(widget.selectedLocalityIds)
      ..remove(id);
    widget.onChanged(updated);
  }

  Future<void> _pickState(List<String> states) async {
    final picked = await _showSearchSheet<String>(
      context: context,
      title: 'Select state',
      items: states,
      labelOf: (s) => s,
      customBuilder: (query) => query,
      customHint: 'state',
    );
    if (picked != null) {
      setState(() {
        _selectedState = picked;
        _selectedCity = null; // city list depends on state
      });
    }
  }

  Future<void> _pickCity(List<String> cities) async {
    final picked = await _showSearchSheet<String>(
      context: context,
      title: 'Select city',
      items: cities,
      labelOf: (c) => c,
      customBuilder: (query) => query,
      customHint: 'city',
    );
    if (picked != null) {
      setState(() => _selectedCity = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(locationStatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        statesAsync.when(
          loading: () => const _FieldSkeleton(label: 'State'),
          error: (_, __) => _FieldError(
            label: 'states',
            onRetry: () => ref.invalidate(locationStatesProvider),
            onEnterManually: () async {
              final custom = await _promptCustomText(context, 'state');
              if (custom != null) {
                setState(() {
                  _selectedState = custom;
                  _selectedCity = null;
                });
              }
            },
          ),
          data: (states) {
            // Only auto-pick a default the first time (when nothing is
            // selected yet). Do NOT reset just because the current value
            // isn't in `states` — that's exactly what happens for a
            // custom (user-typed) state, and resetting here would wipe
            // it out on the very next rebuild.
            _selectedState ??= states.isNotEmpty ? states.first : null;
            return _PickerField(
              label: 'State',
              icon: Icons.map_outlined,
              value: _selectedState,
              onTap: states.isEmpty ? null : () => _pickState(states),
            );
          },
        ),
        const SizedBox(height: 16),
        if (_selectedState != null)
          Consumer(
            builder: (context, ref, _) {
              final citiesAsync =
              ref.watch(locationCitiesProvider(_selectedState!));
              return citiesAsync.when(
                loading: () => const _FieldSkeleton(label: 'City'),
                error: (_, __) => _FieldError(
                  label: 'cities',
                  onRetry: () =>
                      ref.invalidate(locationCitiesProvider(_selectedState!)),
                  onEnterManually: () async {
                    final custom = await _promptCustomText(context, 'city');
                    if (custom != null) {
                      setState(() => _selectedCity = custom);
                    }
                  },
                ),
                data: (cities) {
                  // Same reasoning as `_selectedState` above — only
                  // default when empty, never reset an existing
                  // (possibly custom) selection just because it's not
                  // in the fetched `cities` list.
                  _selectedCity ??= cities.isNotEmpty ? cities.first : null;
                  return _PickerField(
                    label: 'City',
                    icon: Icons.location_city_outlined,
                    value: _selectedCity,
                    onTap: cities.isEmpty ? null : () => _pickCity(cities),
                  );
                },
              );
            },
          ),
        const SizedBox(height: 16),
        if (_selectedState != null && _selectedCity != null)
          Consumer(
            builder: (context, ref, _) {
              final key = (state: _selectedState!, city: _selectedCity!);
              final localitiesAsync =
              ref.watch(locationLocalitiesProvider(key));
              return localitiesAsync.when(
                loading: () => const _ChipsSkeleton(),
                error: (_, __) => _FieldError(
                  label: 'localities',
                  onRetry: () =>
                      ref.invalidate(locationLocalitiesProvider(key)),
                  // No `onEnterManually` here on purpose — unlike
                  // State/City, locality already has the
                  // always-visible "Can't find your area?" box below,
                  // so the worker isn't blocked even if this list
                  // fails to load.
                ),
                data: (localities) {
                  for (final l in localities) {
                    _labelsById[l.id] = l.name;
                  }
                  if (localities.isEmpty) {
                    return Text(
                      'No localities listed for $_selectedCity yet.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    );
                  }

                  final query = _localitySearchController.text.trim();
                  final filtered = query.isEmpty
                      ? localities
                      : localities
                      .where((l) => l.name
                      .toLowerCase()
                      .contains(query.toLowerCase()))
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _localitySearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search localities in $_selectedCity...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon:
                          _localitySearchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _localitySearchController.clear();
                              setState(() {});
                            },
                          )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        Text(
                          'No localities match "$query".',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        )
                      else
                        ChipGroup<LocationItem>(
                          items: filtered,
                          selectedIds: widget.selectedLocalityIds,
                          idOf: (l) => l.id,
                          labelOf: (l) => l.name,
                          onToggle: _toggleLocality,
                        ),
                    ],
                  );
                },
              );
            },
          ),
        const SizedBox(height: 20),

        /// All currently selected localities — across every city/state
        /// visited — with per-chip removal.
        if (widget.selectedLocalityIds.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Your selected locations',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedLocalityIds.map((id) {
              final label = _labelsById[id] ?? id;
              return Chip(
                label: Text(label, style: const TextStyle(fontSize: 12.5)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeSelected(id),
                backgroundColor: Colors.grey.shade100,
                side: BorderSide(color: Colors.grey.shade300),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// A read-only, tap-to-open field styled like a form field. Replaces
/// `DropdownButtonFormField` for state/city so opening it shows a
/// height-capped, searchable bottom sheet instead of a full-screen
/// dropdown menu.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(
          value ?? 'Select $label',
          style: TextStyle(
            color: value != null ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

/// Opens a height-capped, searchable bottom sheet and resolves with the
/// item the user picked (or null if dismissed without picking).
Future<T?> _showSearchSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  T Function(String query)? customBuilder,
  String customHint = '',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _SearchSheet<T>(
      title: title,
      items: items,
      labelOf: labelOf,
      customBuilder: customBuilder,
      customHint: customHint,
    ),
  );
}

class _SearchSheet<T> extends StatefulWidget {
  const _SearchSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    this.customBuilder,
    this.customHint = '',
  });

  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final T Function(String query)? customBuilder;
  final String customHint;

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _useCustom() {
    final builder = widget.customBuilder;
    final query = _query.trim();
    if (builder == null || query.isEmpty) return;
    Navigator.of(context).pop(builder(query));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
        .where((item) => widget
        .labelOf(item)
        .toLowerCase()
        .contains(_query.toLowerCase()))
        .toList();

    final canUseCustom =
        widget.customBuilder != null && _query.trim().isNotEmpty;

    // Capped at 60% of screen height so the sheet never grows to cover
    // the whole page, regardless of how many items the list has.
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (_) {
                  if (filtered.isEmpty) _useCustom();
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.customBuilder != null
                      ? 'Search or type your own ${widget.customHint}'
                      : 'Search...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (canUseCustom)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _useCustom,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Can\'t find it? Use "${_query.trim()}"',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (canUseCustom) const SizedBox(height: 8),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.customBuilder != null
                      ? (_query.isEmpty
                      ? 'No matches — type to search or add your own'
                      : 'No matches — tap above to use "${_query.trim()}"')
                      : 'No matches for "$_query"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return ListTile(
                    title: Text(widget.labelOf(item)),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldSkeleton extends StatelessWidget {
  const _FieldSkeleton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({
    required this.label,
    required this.onRetry,
    this.onEnterManually,
  });
  final String label;
  final VoidCallback onRetry;

  /// When provided, shows an extra "Enter manually" action so the
  /// worker isn't blocked if the master-data list fails to load.
  final VoidCallback? onEnterManually;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Couldn't load $label",
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
        ),
        if (onEnterManually != null)
          TextButton(onPressed: onEnterManually, child: const Text('Enter manually')),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// Small dialog used to collect a free-text value when a picker's
/// master-data list can't be loaded at all (network/API failure).
Future<String?> _promptCustomText(BuildContext context, String label) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Enter $label'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: 'Type your $label'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) Navigator.of(ctx).pop(text);
          },
          child: const Text('Use this'),
        ),
      ],
    ),
  );
}

class _ChipsSkeleton extends StatelessWidget {
  const _ChipsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 36,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
