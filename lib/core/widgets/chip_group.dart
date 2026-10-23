import 'package:flutter/material.dart';

/// Generic multi-select chip group — used by Skills, Languages, and
/// Industries pickers so all three share one selection widget instead
/// of each screen re-implementing `FilterChip` wrapping/spacing.
class ChipGroup<T> extends StatelessWidget {
  const ChipGroup({
    required this.items,
    required this.selectedIds,
    required this.idOf,
    required this.labelOf,
    required this.onToggle,
    super.key,
  });

  final List<T> items;
  final Set<String> selectedIds;
  final String Function(T item) idOf;
  final String Function(T item) labelOf;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final id = idOf(item);
        final selected = selectedIds.contains(id);
        return FilterChip(
          label: Text(labelOf(item)),
          selected: selected,
          onSelected: (value) => onToggle(id, value),
        );
      }).toList(),
    );
  }
}

// WHY THIS FILE
// Generic over T (not hardcoded to SkillItem) so the same widget covers
// Skills, Languages, and Industries — three different MasterDataItem
// subtypes — without three near-identical copy-pasted chip-list
// widgets. idOf/labelOf are passed in rather than assuming every T has
// `.id`/`.name` fields, keeping this decoupled from `MasterDataItem`
// specifically (it would work for any list of anything with an id and
// a label).
// Pitfall a junior would hit: using `List<String>` as `selectedIds`
// instead of `Set<String>` — `.contains()` on a List is O(n) per chip,
// so a 50-item skill list re-renders with 50×50 comparisons on every
// toggle. `Set` makes that O(1) per lookup.
