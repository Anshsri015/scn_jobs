import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/widgets/cascading_location_picker.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

class PreferredLocationsScreen extends ConsumerStatefulWidget {
  const PreferredLocationsScreen({super.key});

  @override
  ConsumerState<PreferredLocationsScreen> createState() =>
      _PreferredLocationsScreenState();
}

class _PreferredLocationsScreenState
    extends ConsumerState<PreferredLocationsScreen> {
  Set<String> _selected = {};
  final Set<String> _customLocations = {};
  final TextEditingController _manualLocationController =
  TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _manualLocationController.dispose();
    super.dispose();
  }

  void _addCustomLocation(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _customLocations.add(trimmed);
      _manualLocationController.clear();
    });
  }

  Future<void> _continue() async {
    if (_selected.isEmpty && _customLocations.isEmpty) {
      _showError('Pick at least one preferred location to continue');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(updatePreferredLocationsUseCaseProvider)(
        [..._selected, ..._customLocations],
      );
      if (mounted) {
        HapticFeedback.lightImpact();
        context.push('/profile-setup/preferences/industries');
      }
    } catch (_) {
      if (mounted) {
        _showError("Couldn't save. Try again.");
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final totalCount = _selected.length + _customLocations.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
        title: const Text(
          'Work Locations',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Preferences 3 of 4',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  /// Header card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary.withOpacity(0.08),
                          colors.primary.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: colors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: colors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Where do you want to work?',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select localities where you are open to working. You can pick multiple locations.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// Selected count
                  if (totalCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Text(
                            'Selected locations',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              _selected = {};
                              _customLocations.clear();
                            }),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade400,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Clear all',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  /// Custom (manually typed) location chips
                  if (_customLocations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _customLocations.map((location) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => setState(
                                          () => _customLocations.remove(location)),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  /// Location picker container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: CascadingLocationPicker(
                      selectedLocalityIds: _selected,
                      onChanged: (updated) =>
                          setState(() => _selected = updated),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Type a location that isn't in the picker and hit
                  /// "Add" — goes out as a plain string in
                  /// `locationNames`, which the backend find-or-creates.
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualLocationController,
                          onSubmitted: _addCustomLocation,
                          decoration: InputDecoration(
                            hintText: 'Enter your location',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: colors.primary.withOpacity(0.3),
                                  width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _addCustomLocation(
                            _manualLocationController.text),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: colors.primary.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                        ),
                        child: Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  /// Tip
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Colors.blue.shade600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Selecting more locations increases your chances of getting job recommendations. You can always update this later.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// Sticky bottom CTA
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        totalCount == 0
                            ? 'Continue'
                            : 'Continue ($totalCount)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}