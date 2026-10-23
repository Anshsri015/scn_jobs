import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/error/api_failure.dart';
import 'package:scn_jobs/domain/entities/education.dart';
import 'package:scn_jobs/domain/entities/master_data.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

/// Fixed level options — display labels match the screenshot's
/// "Qualification Level" dropdown exactly; values are the enum the
/// backend expects (`GET /master/qualifications`'s grouping keys /
/// `POST /worker/education`'s `level` field).
const List<({String value, String label})> kEducationLevels = [
  (value: 'TEN', label: '10th Pass'),
  (value: 'TWELVE', label: '12th Pass'),
  (value: 'DIPLOMA', label: 'Diploma'),
  (value: 'GRADUATE', label: 'Graduate'),
  (value: 'POST_GRADUATE', label: 'Post Graduate'),
  (value: 'ANY', label: 'Other / Certification'),
];

class EducationFormScreen extends ConsumerStatefulWidget {
  const EducationFormScreen({super.key, this.existing});

  /// When non-null, the form opens pre-filled for this record and
  /// submits via [UpdateEducationUseCase] instead of [AddEducationUseCase].
  final Education? existing;

  @override
  ConsumerState<EducationFormScreen> createState() =>
      _EducationFormScreenState();
}

class _EducationFormScreenState extends ConsumerState<EducationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instituteController = TextEditingController();
  final _qualificationNameController = TextEditingController();

  String? _selectedLevel;
  QualificationItem? _selectedQualification;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedLevel = existing.level;
      _instituteController.text = existing.institute ?? '';
      if (existing.level == 'ANY') {
        _qualificationNameController.text = existing.qualificationName ?? '';
      }
      // The specific QualificationItem (for non-ANY levels) is resolved
      // once the master-data list loads — see the `qualificationsAsync`
      // build below.
    }
  }

  @override
  void dispose() {
    _instituteController.dispose();
    _qualificationNameController.dispose();
    super.dispose();
  }

  bool get _isAnyLevel => _selectedLevel == 'ANY';

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final level = _selectedLevel;
    if (level == null) return;

    // Enforce the doc's either/or rule before it ever reaches the
    // network: qualificationId for every level except ANY, free-text
    // qualificationName only for ANY.
    if (!_isAnyLevel && _selectedQualification == null) return;
    if (_isAnyLevel && _qualificationNameController.text.trim().isEmpty) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final education = Education(
        id: widget.existing?.id ?? '',
        level: level,
        qualificationId: _isAnyLevel ? null : _selectedQualification!.id,
        qualificationName: _isAnyLevel
            ? _qualificationNameController.text.trim()
            : _selectedQualification!.name,
        institute: _instituteController.text.trim().isEmpty
            ? null
            : _instituteController.text.trim(),
      );

      if (_isEditing) {
        final useCase = ref.read(updateEducationUseCaseProvider);
        await useCase(education);
      } else {
        final useCase = ref.read(addEducationUseCaseProvider);
        await useCase(education);
      }

      if (mounted) context.pop(true);
    } catch (e) {
      // Surface the backend's actual reason (e.g. the "institute is
      // required for this qualification level" case the client-side
      // validator above now catches before it even reaches here) so
      // any *other* level-specific rule the backend enforces doesn't
      // just show a generic "try again" with no way to know what to
      // fix.
      final message = e is ApiFailure
          ? e.message
          : "Couldn't save. Try again.";
      if (mounted) {
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qualificationsAsync = ref.watch(qualificationsProvider);
    final colors = Theme.of(context).colorScheme;

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
        title: Text(
          _isEditing ? 'Edit Education' : 'Add Education',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /// Header
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
                        border: Border.all(color: colors.primary.withOpacity(0.1)),
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
                              Icons.school_rounded,
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
                                  'Qualification Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'You can add multiple qualifications one by one.',
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

                    const SizedBox(height: 28),

                    /// Qualification Level Dropdown (always shown — this is the
                    /// enum the backend calls `level`, screenshot's "10th
                    /// Pass / 12th Pass / Diploma / Graduate" picker).
                    FormField<String>(
                      initialValue: _selectedLevel,
                      validator: (_) =>
                      _selectedLevel == null ? 'Please select a level' : null,
                      builder: (state) {
                        String? currentLevelLabel;
                        for (final l in kEducationLevels) {
                          if (l.value == _selectedLevel) {
                            currentLevelLabel = l.label;
                            break;
                          }
                        }
                        return _SearchablePickerField<({String value, String label})>(
                          decoration: _fieldDecoration(
                            label: 'Qualification Level *',
                            icon: Icons.stairs_outlined,
                            suffix: Icon(Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey.shade500),
                          ).copyWith(errorText: state.errorText),
                          items: kEducationLevels,
                          labelOf: (l) => l.label,
                          selectedLabel: currentLevelLabel,
                          sheetTitle: 'Select Qualification Level',
                          onSelected: (l) {
                            state.didChange(l.value);
                            setState(() {
                              _selectedLevel = l.value;
                              // Level changed -> previously chosen specific
                              // qualification no longer necessarily matches it.
                              _selectedQualification = null;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    /// Second tier: specific qualification (filtered by level)
                    /// or free-text name — only once a level is picked.
                    if (_selectedLevel != null) ...[
                      if (_isAnyLevel)
                        TextFormField(
                          controller: _qualificationNameController,
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration(
                            label: 'Qualification Name *',
                            icon: Icons.workspace_premium_outlined,
                            hint: 'e.g. Certificate in Cloud Computing',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter the qualification name'
                              : null,
                        )
                      else
                        qualificationsAsync.when(
                          loading: () => Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Loading qualifications...',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          error: (_, __) => Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade400),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Couldn't load qualifications. Pull back and retry.",
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          data: (qualifications) {
                            final scoped = qualifications
                                .where((q) => q.level == _selectedLevel)
                                .toList();

                            // Editing an existing record: resolve the
                            // matching QualificationItem by id once the
                            // master-data list is available, so the
                            // dropdown opens pre-selected instead of blank.
                            final existing = widget.existing;
                            if (_selectedQualification == null &&
                                existing != null &&
                                existing.qualificationId != null &&
                                existing.level == _selectedLevel) {
                              final match = scoped.where(
                                    (q) => q.id == existing.qualificationId,
                              );
                              if (match.isNotEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() => _selectedQualification = match.first);
                                  }
                                });
                              }
                            }

                            return FormField<QualificationItem>(
                              initialValue: _selectedQualification,
                              validator: (_) => _selectedQualification == null
                                  ? 'Please select a qualification'
                                  : null,
                              builder: (state) => _SearchablePickerField<QualificationItem>(
                                decoration: _fieldDecoration(
                                  label: 'Specific Qualification *',
                                  icon: Icons.school_outlined,
                                  suffix: Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Colors.grey.shade500),
                                ).copyWith(errorText: state.errorText),
                                items: scoped,
                                labelOf: (q) => q.name,
                                selectedLabel: _selectedQualification?.name,
                                sheetTitle: 'Select Specific Qualification',
                                onSelected: (q) {
                                  state.didChange(q);
                                  setState(() => _selectedQualification = q);
                                },
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 18),
                    ],

                    /// Institute
                    ///
                    /// Was marked "Optional" with no validator, but the
                    /// backend rejects POST /worker/education with 400
                    /// ("institute is required for this qualification
                    /// level") for every level except ANY — confirmed
                    /// live for DIPLOMA. ANY stays optional since it's
                    /// a free-text "Other/Certification" entry, not
                    /// tied to a formal institute the way a school/
                    /// college qualification is.
                    TextFormField(
                      controller: _instituteController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (_isAnyLevel) return null;
                        if (value == null || value.trim().isEmpty) {
                          return 'Institute name is required';
                        }
                        return null;
                      },
                      decoration: _fieldDecoration(
                        label: 'Institute Name',
                        icon: Icons.account_balance_outlined,
                        hint: 'e.g. Delhi Public School',
                        suffix: _isAnyLevel
                            ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
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
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isEditing ? 'Save Changes' : '+ Add Qualification',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
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
/// a normal text field and opens a bottom sheet capped to ~65% of the
/// screen with a search box on top, so long lists (e.g. all Indian
/// states) don't need endless scrolling.
class _SearchablePickerField<T> extends StatelessWidget {
  const _SearchablePickerField({
    required this.decoration,
    required this.items,
    required this.labelOf,
    required this.selectedLabel,
    required this.onSelected,
    required this.sheetTitle,
    this.customBuilder,
    this.customHint,
  });

  final InputDecoration decoration;
  final List<T> items;
  final String Function(T) labelOf;
  final String? selectedLabel;
  final ValueChanged<T> onSelected;
  final String sheetTitle;

  /// When provided, the picker sheet lets the user type a value that
  /// isn't in [items] (state/city/locality not covered by master
  /// data) and turns that free text into a [T] via this builder.
  final T Function(String query)? customBuilder;

  /// Placeholder shown in the "enter manually" text field. Defaults
  /// to [sheetTitle] if omitted.
  final String? customHint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await _showSearchablePickerSheet<T>(
          context: context,
          title: sheetTitle,
          items: items,
          labelOf: labelOf,
          customBuilder: customBuilder,
          customHint: customHint ?? sheetTitle,
        );
        if (picked != null) onSelected(picked);
      },
      child: InputDecorator(
        decoration: decoration,
        child: Text(
          selectedLabel ?? (decoration.hintText ?? 'Select'),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            color:
            selectedLabel != null ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

Future<T?> _showSearchablePickerSheet<T>({
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
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SearchablePickerSheet<T>(
      title: title,
      items: items,
      labelOf: labelOf,
      customBuilder: customBuilder,
      customHint: customHint,
    ),
  );
}

class _SearchablePickerSheet<T> extends StatefulWidget {
  const _SearchablePickerSheet({
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
  State<_SearchablePickerSheet<T>> createState() =>
      _SearchablePickerSheetState<T>();
}

class _SearchablePickerSheetState<T>
    extends State<_SearchablePickerSheet<T>> {
  final _searchController = TextEditingController();
  late List<T> _filtered = widget.items;

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items
          .where((i) => widget.labelOf(i).toLowerCase().contains(q))
          .toList();
    });
  }

  void _useCustom() {
    final query = _searchController.text.trim();
    final builder = widget.customBuilder;
    if (builder == null || query.isEmpty) return;
    Navigator.of(context).pop(builder(query));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Capped height (not full-screen) + a search box so the worker can
    // filter instead of scrolling through, say, every Indian state.
    final maxHeight = MediaQuery.of(context).size.height * 0.65;
    final query = _searchController.text.trim();
    final canUseCustom = widget.customBuilder != null && query.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  // Nothing matched and the user hit search/enter —
                  // treat it as "use what I typed" when custom entry
                  // is available for this field.
                  if (_filtered.isEmpty) _useCustom();
                },
                decoration: InputDecoration(
                  hintText: widget.customBuilder != null
                      ? 'Search or type your own ${widget.customHint.toLowerCase()}'
                      : 'Search ${widget.title.toLowerCase()}',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
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
                            "Can't find it? Use \"$query\"",
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
              child: _filtered.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  widget.customBuilder != null
                      ? (query.isEmpty
                      ? 'No matches — type to search or add your own'
                      : 'No matches — tap above to use "$query"')
                      : 'No matches found',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final item = _filtered[i];
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
