import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:scn_jobs/core/widgets/chip_group.dart';
import 'package:scn_jobs/domain/entities/education.dart';
import 'package:scn_jobs/domain/entities/experience.dart';
import 'package:scn_jobs/domain/entities/language_selection.dart';
import 'package:scn_jobs/domain/entities/master_data.dart';
import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart'
    show onboardingStatusProvider;
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;
  String? _selectedState;
  String? _selectedCity;
  String? _selectedLocalityId;
  String? _selectedLocalityName;
  String? _photoPath;
  bool _prefilled = false;
  bool _submitting = false;

  // Reuses `_submitting` (declared above) to drive the avatar spinner
  // shown while the profile save + refetch is in flight — see the
  // WHY note in `_submit` for what that spinner is actually covering.

  // Optimistic-update state for the master-data-backed multi-select
  // sections (Skills, Preferred Industries/Job Roles/Departments,
  // Assets). Keyed by a short field key (e.g. 'skills'). Without
  // this, the chips only update after BOTH the save PATCH and the
  // subsequent currentProfileProvider refetch complete, which on a
  // cold/slow backend can take many seconds with zero feedback on
  // screen — looks like the selection "isn't showing" / is very
  // late. Setting the override the instant the sheet closes makes
  // the chips update immediately; it's cleared on error (rollback)
  // and just left in place on success (the eventual refetch will
  // agree with it anyway).
  final Map<String, List<String>> _pendingOverrides = {};
  final Set<String> _savingSections = {};

  List<String> _idsFor(String key, List<String> fallback) =>
      _pendingOverrides[key] ?? fallback;

  static const _genders = ['Male', 'Female', 'Other'];
  // Backend enum is MALE | FEMALE | ANY — same mapping as
  // PersonalDetailsScreen. profile.gender arrives as the raw API
  // value ("MALE"), which doesn't match any `_genders` UI label
  // directly — binding it straight to the dropdown's `value` is what
  // caused "There should be exactly one item with value: MALE".
  static const _genderApiValues = {
    'Male': 'MALE',
    'Female': 'FEMALE',
    'Other': 'ANY',
  };
  static const _genderApiToLabel = {
    'MALE': 'Male',
    'FEMALE': 'Female',
    'ANY': 'Other',
  };

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  void _prefillFrom(WorkerProfile profile) {
    if (_prefilled) return;
    _fullNameController.text = profile.name ?? '';
    _selectedState = profile.state;
    _selectedCity = profile.city;
    _selectedLocalityName = profile.locality;
    _dateOfBirth = profile.dateOfBirth;
    _gender = profile.gender == null ? null : _genderApiToLabel[profile.gender];
    _photoPath = profile.photoUrl;
    _prefilled = true;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 14),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photoPath = picked.path);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final useCase = ref.read(updateProfileUseCaseProvider);
      await useCase(
        name: _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _gender == null ? null : _genderApiValues[_gender],
        state: _selectedState,
        city: _selectedCity,
        locality: _selectedLocalityName,
        photoUrl: _photoPath,
      );

      ref.invalidate(currentProfileProvider);
      // Without this, `onboardingStatusProvider` stays on its stale
      // cached value from before this save — Apply keeps showing
      // "complete your profile" (and blocking the actual apply
      // action) even after the worker has just finished it here. See
      // the matching fix/note in `profile_completion_screen.dart`
      // for the same bug on the main onboarding flow's last step;
      // this is the same fix for the Edit Profile path.
      ref.invalidate(onboardingStatusProvider);

      // WHY: the save itself returns fast, but the profile the rest
      // of the app reads (`currentProfileProvider`) can take a few
      // seconds to actually reflect the new photo server-side. It
      // used to "work" only in the sense that leaving this screen and
      // waiting ~5-6s before coming back showed the update — with
      // nothing telling the worker to wait, that looked broken.
      // Awaiting the refetch here keeps the existing Save spinner
      // (and the dimmed avatar below) up for exactly that gap, so by
      // the time this screen closes the update has already landed —
      // no more leaving and re-entering needed.
      try {
        await ref.read(currentProfileProvider.future);
      } catch (_) {
        // The save itself already succeeded above; a slow/failed
        // refetch here just means some other screen will refresh a
        // little later — not worth blocking the success message for.
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Profile updated successfully'),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text("Couldn't save changes. Try again."),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ═══════════════════════════════════════════
  // Shared helpers for the sections below
  // ═══════════════════════════════════════════

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        backgroundColor: isError ? null : Colors.green.shade700,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  /// Resolves `WorkerProfile`'s stored ids (e.g. `preferredIndustries`)
  /// against a loaded master-data list, for chip display. Falls back
  /// to the raw id if the list hasn't loaded yet or the id has no
  /// match, rather than silently dropping it.
  List<String> _namesFor(List<String> ids, List<MasterDataItem>? items) {
    if (items == null) return ids;
    return ids.map((id) {
      for (final item in items) {
        if (item.id == id) return item.name;
      }
      return id;
    }).toList();
  }

  Future<void> _runSectionSave(
      Future<void> Function() action, {
        String successMessage = 'Updated',
      }) async {
    try {
      await action();
      ref.invalidate(currentProfileProvider);
      // Same reasoning as `_submit()` above — a section save can flip
      // completeness just as much as the main form can.
      ref.invalidate(onboardingStatusProvider);
      _showSnack(successMessage);
    } catch (_) {
      _showSnack("Couldn't save. Try again.", isError: true);
    }
  }

  /// Generic multi-select bottom sheet shared by Skills, Preferred
  /// Industries, Preferred Job Roles, Preferred Departments, and
  /// Assets — only [idOf] differs (Assets keys selection by name, not
  /// master-data id — see `WorkerProfile.assets`'s doc).
  static const _pickerPageSize = 10;

  /// Opens the sheet immediately and loads inside it via [itemsLoader]
  /// — no separate full-screen dialog before the sheet appears. If
  /// [paginate] is true, only the first 10 loaded items are shown at
  /// once, with a "Load more" button underneath to reveal 10 more at a
  /// time, instead of the old prev/next page flipper.
  Future<List<String>?> _showMultiSelectSheet({
    required String title,
    required Future<List<MasterDataItem>> Function() itemsLoader,
    required Set<String> initialSelected,
    String Function(MasterDataItem item)? idOf,
    bool paginate = false,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _MultiSelectSheet(
        title: title,
        itemsLoader: itemsLoader,
        initialSelected: initialSelected,
        idOf: idOf,
        paginate: paginate,
        pageSize: _pickerPageSize,
      ),
    );
  }

  /// Wraps a master-data-backed section's edit tap so the pencil icon
  /// is ALWAYS tappable, never gated behind `asyncValue.hasValue`.
  ///
  /// Previously each section (Preferred Industries, Job Roles,
  /// Departments, Skills, Assets) only showed its pencil once that
  /// section's own `FutureProvider` had already resolved — so on a
  /// slow/cold-starting backend, the icon simply wasn't there yet and
  /// the worker had no way to even try tapping edit.
  ///
  /// Now the sheet opens the instant the pencil is tapped, [loadItems]
  /// runs *inside* it (loading spinner lives in the sheet, not a
  /// separate full-screen dialog blocking it), and reuses
  /// [loadedItems] directly when that provider has already resolved so
  /// the fast path skips the spinner entirely.
  ///
  /// [loadItems] MUST force a real network attempt every time it's
  /// called — including on the sheet's own "Retry" button, which just
  /// calls this same closure again. Passing `() => ref.read(x
  /// Provider.future)` looks right but isn't: once a `FutureProvider`
  /// has errored, `ref.read(provider.future)` returns that *same
  /// cached* rejected future forever, so Retry would instantly
  /// re-throw the old error without ever hitting the API again. Use
  /// `() => ref.refresh(xProvider.future)` at every call site instead
  /// — it invalidates the provider and actually re-fetches.
  Future<void> _editMasterDataSection({
    required String key,
    required List<MasterDataItem>? loadedItems,
    required Future<List<MasterDataItem>> Function() loadItems,
    required String title,
    required List<String> currentIds,
    required Future<void> Function(List<String> ids) onSave,
    String successMessage = 'Updated',
    String Function(MasterDataItem item)? idOf,
    bool paginate = false,
  }) async {
    await _editMultiSelect(
      key: key,
      title: title,
      itemsLoader: () async => loadedItems ?? await loadItems(),
      currentIds: currentIds,
      onSave: (ids) async {
        await onSave(ids);
        // A worker-typed custom value (job role/department/skill/
        // industry not already in the master list) gets find-or-
        // created server-side by this save — the backend hands it a
        // real numeric id from here on. Without refreshing the
        // cached master list right after, that id has no name to
        // resolve against (the cache still predates this save), so
        // `_namesFor` falls back to displaying the bare id/number
        // once this screen is re-fetched or reopened — exactly the
        // "random number instead of what I typed" symptom. Best-
        // effort: a failed refresh here shouldn't turn an already-
        // successful save into a shown error.
        try {
          await loadItems();
        } catch (_) {}
      },
      successMessage: successMessage,
      idOf: idOf,
      paginate: paginate,
    );
  }

  Future<void> _editMultiSelect({
    required String key,
    required String title,
    required Future<List<MasterDataItem>> Function() itemsLoader,
    required List<String> currentIds,
    required Future<void> Function(List<String> ids) onSave,
    String successMessage = 'Updated',
    String Function(MasterDataItem item)? idOf,
    bool paginate = false,
  }) async {
    final result = await _showMultiSelectSheet(
      title: title,
      itemsLoader: itemsLoader,
      initialSelected: currentIds.toSet(),
      idOf: idOf,
      paginate: paginate,
    );
    if (result == null) return;

    // 1) Reflect the pick on screen INSTANTLY — don't wait on any
    // network round trip for the chips to update.
    setState(() {
      _pendingOverrides[key] = result;
      _savingSections.add(key);
    });

    try {
      await onSave(result);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingStatusProvider);
      if (mounted) _showSnack(successMessage);
    } catch (_) {
      // 2) Save actually failed — roll the optimistic chips back so
      // we're not showing a selection that was never persisted.
      if (mounted) {
        setState(() => _pendingOverrides.remove(key));
        _showSnack("Couldn't save. Try again.", isError: true);
      }
    } finally {
      if (mounted) setState(() => _savingSections.remove(key));
    }
  }

  // ═══════════════════════════════════════════
  // About
  // ═══════════════════════════════════════════

  Widget _buildAboutSection(WorkerProfile profile) {
    return _EditableSectionCard(
      title: 'About',
      onEdit: () => _editAbout(profile),
      child: Text(
        (profile.summary?.trim().isNotEmpty ?? false)
            ? profile.summary!.trim()
            : 'Add a professional biography here.',
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: (profile.summary?.trim().isNotEmpty ?? false)
              ? Colors.black87
              : Colors.grey.shade400,
        ),
      ),
    );
  }

  Future<void> _editAbout(WorkerProfile profile) async {
    final headlineCtrl = TextEditingController(text: profile.headline ?? '');
    final summaryCtrl = TextEditingController(text: profile.summary ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('About',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _ModernTextField(
              controller: headlineCtrl,
              label: 'Headline',
              hint: 'e.g. Backend Developer',
              prefixIcon: Icons.short_text_rounded,
              isOptional: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: summaryCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Professional biography',
                hintText: 'Add a professional biography here',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _runSectionSave(
          () => ref.read(updateProfileUseCaseProvider)(
        headline: headlineCtrl.text.trim(),
        summary: summaryCtrl.text.trim(),
      ),
      successMessage: 'About updated',
    );
  }

  // ═══════════════════════════════════════════
  // Personal & Preference Details (Marital Status, Category)
  // ═══════════════════════════════════════════

  static const _maritalOptions = {'Single': 'SINGLE', 'Married': 'MARRIED'};
  static const _maritalApiToLabel = {'SINGLE': 'Single', 'MARRIED': 'Married'};
  // GEN/OBC/SC/ST — the values the API doc's own example payloads use.
  static const _categoryOptions = {
    'General': 'GEN',
    'OBC': 'OBC',
    'SC': 'SC',
    'ST': 'ST',
  };
  static const _categoryApiToLabel = {
    'GEN': 'General',
    'OBC': 'OBC',
    'SC': 'SC',
    'ST': 'ST',
  };

  Widget _buildPreferencesSection(WorkerProfile profile) {
    final maritalLabel = profile.maritalStatus == null
        ? null
        : _maritalApiToLabel[profile.maritalStatus];
    final categoryLabel =
    profile.category == null ? null : _categoryApiToLabel[profile.category];

    return _EditableSectionCard(
      title: 'Personal & Preference Details',
      onEdit: () => _editPreferences(profile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'Marital Status', value: maritalLabel ?? '—'),
          const SizedBox(height: 10),
          _DetailRow(label: 'Category', value: categoryLabel ?? '—'),
        ],
      ),
    );
  }

  Future<void> _editPreferences(WorkerProfile profile) async {
    var marital = profile.maritalStatus == null
        ? null
        : _maritalApiToLabel[profile.maritalStatus];
    var category =
    profile.category == null ? null : _categoryApiToLabel[profile.category];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Personal & Preference Details',
                  style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _ModernDropdownField<String>(
                label: 'Marital Status',
                hint: 'Select marital status',
                prefixIcon: Icons.favorite_border_rounded,
                value: marital,
                items: _maritalOptions.keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) => setSheetState(() => marital = v),
              ),
              const SizedBox(height: 16),
              _ModernDropdownField<String>(
                label: 'Category',
                hint: 'Select category',
                prefixIcon: Icons.category_outlined,
                value: category,
                items: _categoryOptions.keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) => setSheetState(() => category = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    await _runSectionSave(
          () => ref.read(updateProfileUseCaseProvider)(
        maritalStatus: marital == null ? null : _maritalOptions[marital],
        category: category == null ? null : _categoryOptions[category],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Skills & Endorsements
  // ═══════════════════════════════════════════

  Widget _buildSkillsSection(WorkerProfile profile) {
    return Consumer(
      builder: (context, ref, _) {
        final skillsAsync = ref.watch(skillsProvider);
        final currentIds = _idsFor('skills', profile.skills);
        final names = _namesFor(currentIds, skillsAsync.asData?.value);
        return _EditableSectionCard(
          title: 'Skills & Endorsements',
          isSaving: _savingSections.contains('skills'),
          onEdit: () => _editMasterDataSection(
            key: 'skills',
            loadedItems: skillsAsync.asData?.value,
            loadItems: () => ref.refresh(skillsProvider.future),
            title: 'Skills',
            currentIds: currentIds,
            onSave: (ids) =>
                ref.read(updateSkillsUseCaseProvider)(ids),
            successMessage: 'Skills updated',
            paginate: true,
          ),
          child: _ChipsOrEmpty(
            labels: names,
            emptyText: 'No skills added yet.',
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // Preferred Industries / Job Roles / Departments
  // ═══════════════════════════════════════════

  Widget _buildPreferredIndustriesSection(WorkerProfile profile) {
    return Consumer(
      builder: (context, ref, _) {
        final industriesAsync = ref.watch(industriesProvider);
        final currentIds = _idsFor('industries', profile.preferredIndustries);
        final names = _namesFor(currentIds, industriesAsync.asData?.value);
        return _EditableSectionCard(
          title: 'Preferred Industries',
          isSaving: _savingSections.contains('industries'),
          onEdit: () => _editMasterDataSection(
            key: 'industries',
            loadedItems: industriesAsync.asData?.value,
            loadItems: () => ref.refresh(industriesProvider.future),
            title: 'Preferred Industries',
            currentIds: currentIds,
            onSave: (ids) =>
                ref.read(updatePreferredIndustriesUseCaseProvider)(ids),
            successMessage: 'Preferred industries updated',
            paginate: true,
          ),
          child: _ChipsOrEmpty(
            labels: names,
            emptyText: 'None — tap edit to add.',
          ),
        );
      },
    );
  }

  Widget _buildPreferredJobRolesSection(WorkerProfile profile) {
    return Consumer(
      builder: (context, ref, _) {
        // `null` == every job role, unscoped by function — the picker
        // isn't narrowed to a single department.
        final jobRolesAsync = ref.watch(jobRolesProvider(null));
        final currentIds = _idsFor('jobRoles', profile.preferredJobRoles);
        final names = _namesFor(currentIds, jobRolesAsync.asData?.value);
        return _EditableSectionCard(
          title: 'Preferred Job Roles',
          isSaving: _savingSections.contains('jobRoles'),
          onEdit: () => _editMasterDataSection(
            key: 'jobRoles',
            loadedItems: jobRolesAsync.asData?.value,
            loadItems: () => ref.refresh(jobRolesProvider(null).future),
            title: 'Preferred Job Roles',
            currentIds: currentIds,
            onSave: (ids) =>
                ref.read(updatePreferredJobRolesUseCaseProvider)(ids),
            successMessage: 'Preferred job roles updated',
            paginate: true,
          ),
          child: _ChipsOrEmpty(
            labels: names,
            emptyText: 'None — click edit to add.',
          ),
        );
      },
    );
  }

  Widget _buildPreferredDepartmentsSection(WorkerProfile profile) {
    return Consumer(
      builder: (context, ref, _) {
        final functionsAsync = ref.watch(jobFunctionsProvider);
        final currentIds =
        _idsFor('departments', profile.preferredDepartments);
        final names = _namesFor(currentIds, functionsAsync.asData?.value);
        return _EditableSectionCard(
          title: 'Preferred Departments',
          isSaving: _savingSections.contains('departments'),
          onEdit: () => _editMasterDataSection(
            key: 'departments',
            loadedItems: functionsAsync.asData?.value,
            loadItems: () => ref.refresh(jobFunctionsProvider.future),
            title: 'Preferred Departments',
            currentIds: currentIds,
            onSave: (ids) =>
                ref.read(updatePreferredDepartmentsUseCaseProvider)(ids),
            successMessage: 'Preferred departments updated',
            paginate: true,
          ),
          child: _ChipsOrEmpty(
            labels: names,
            emptyText: 'None — click edit to add.',
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // Languages
  // ═══════════════════════════════════════════

  Widget _buildLanguagesSection(WorkerProfile profile) {
    return Consumer(
      builder: (context, ref, _) {
        final languagesAsync = ref.watch(languagesProvider);
        final allLanguages = languagesAsync.asData?.value ?? const [];
        final labels = profile.languages.map((sel) {
          final match = allLanguages.where((l) => l.id == sel.languageId);
          final name = match.isNotEmpty ? match.first.name : sel.languageId;
          return sel.proficiency == null
              ? name
              : '$name · ${sel.proficiency!.label}';
        }).toList();
        return _EditableSectionCard(
          title: 'Languages',
          onEdit: () => _editLanguagesWhenReady(profile, languagesAsync),
          child: _ChipsOrEmpty(
            labels: labels,
            emptyText: 'No languages added yet.',
          ),
        );
      },
    );
  }

  /// Same "always tappable" treatment as `_editMasterDataSection` —
  /// Languages has its own signature (`_editLanguages` takes the
  /// resolved list directly) so it gets a small dedicated wrapper
  /// instead of reusing `_editMasterDataSection`.
  Future<void> _editLanguagesWhenReady(
      WorkerProfile profile,
      AsyncValue<List<LanguageItem>> languagesAsync,
      ) async {
    List<LanguageItem> allLanguages;
    if (languagesAsync.hasValue) {
      allLanguages = languagesAsync.value!;
    } else {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
      try {
        allLanguages = await ref.read(languagesProvider.future);
      } catch (_) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showSnack("Couldn't load. Try again.", isError: true);
        return;
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    }
    await _editLanguages(profile, allLanguages);
  }

  /// Proficiency picker — plain list of levels, bold text, a checkmark
  /// on the currently-selected row (or on [current] if the language
  /// already has one). Tapping a row confirms it immediately, the
  /// same one-tap-to-pick behaviour the old `SimpleDialog` had, just
  /// restyled to match the rest of the app's proficiency picker.
  Future<LanguageProficiency?> _showProficiencyPicker(
      String languageName,
      LanguageProficiency? current,
      ) {
    return showModalBottomSheet<LanguageProficiency>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              languageName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'How well do you speak this language?',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ...LanguageProficiency.values.map((level) {
              final isSelected = level == current;
              return InkWell(
                onTap: () => Navigator.of(sheetContext).pop(level),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: isSelected
                            ? const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: Colors.black87,
                        )
                            : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${level.label} $languageName',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _editLanguages(
      WorkerProfile profile,
      List<LanguageItem> allLanguages,
      ) async {
    final selected = <String, LanguageProficiency>{
      for (final l in profile.languages)
        l.languageId: l.proficiency ?? LanguageProficiency.intermediate,
    };
    final result = await showModalBottomSheet<Map<String, LanguageProficiency>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Languages',
                      style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Tap a language, then pick how well you speak it.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allLanguages.map((lang) {
                          final isSel = selected.containsKey(lang.id);
                          return ChoiceChip(
                            label: Text(isSel
                                ? '${lang.name} · ${selected[lang.id]!.label}'
                                : lang.name),
                            selected: isSel,
                            onSelected: (value) async {
                              if (!value) {
                                setSheetState(() => selected.remove(lang.id));
                                return;
                              }
                              final proficiency = await _showProficiencyPicker(
                                lang.name,
                                selected[lang.id],
                              );
                              setSheetState(() => selected[lang.id] =
                                  proficiency ?? LanguageProficiency.intermediate);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null) return;
    await _runSectionSave(
          () {
        final selections = result.entries
            .map((e) =>
            LanguageSelection(languageId: e.key, proficiency: e.value))
            .toList();
        return ref.read(updateLanguagesUseCaseProvider)(selections);
      },
      successMessage: 'Languages updated',
    );
  }

  // ═══════════════════════════════════════════
  // Assets & Vehicles
  // ═══════════════════════════════════════════

  Widget _buildAssetsSection(WorkerProfile profile) {
    return Consumer(
      builder: (context, ref, _) {
        final assetsAsync = ref.watch(assetsProvider);
        final currentNames = _idsFor('assets', profile.assets);
        return _EditableSectionCard(
          title: 'Assets & Vehicles',
          isSaving: _savingSections.contains('assets'),
          onEdit: () => _editMasterDataSection(
            key: 'assets',
            loadedItems: assetsAsync.asData?.value,
            loadItems: () => ref.refresh(assetsProvider.future),
            title: 'Assets & Vehicles',
            // Selection is keyed by NAME here, not id — see
            // `WorkerProfile.assets`'s doc — so `currentIds`
            // is the profile's own name list and `idOf`
            // overrides the default id-based selection.
            currentIds: currentNames,
            idOf: (item) => item.name,
            onSave: (names) =>
                ref.read(updateAssetsUseCaseProvider)(names),
            successMessage: 'Assets updated',
          ),
          child: _ChipsOrEmpty(
            labels: currentNames,
            emptyText: 'No assets specified (e.g. Laptop, Two-Wheeler, '
                'Smartphone, Safety Gear). Click edit icon to set.',
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // Education & Qualifications
  // ═══════════════════════════════════════════

  static const _educationLevels = [
    'TEN',
    'TWELVE',
    'DIPLOMA',
    'GRADUATE',
    'POST_GRADUATE',
    'ANY',
  ];
  static const _educationLevelLabels = {
    'TEN': '10th',
    'TWELVE': '12th',
    'DIPLOMA': 'Diploma',
    'GRADUATE': 'Graduate',
    'POST_GRADUATE': 'Post Graduate',
    'ANY': 'Other / Certification',
  };

  Widget _buildEducationSection(WorkerProfile profile) {
    return _EditableSectionCard(
      title: 'Education & Qualifications',
      onAdd: _addEducation,
      child: profile.education.isEmpty
          ? Text('No education added yet.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13))
          : Column(
        children: profile.education
            .map((edu) => _ListEntryTile(
          icon: Icons.school_outlined,
          title:
          _educationLevelLabels[edu.level] ?? edu.level,
          subtitle: [
            if (edu.qualificationName != null)
              edu.qualificationName!,
            if (edu.institute != null) edu.institute!,
          ].join(' · '),
          onDelete: () => _runSectionSave(
                () => ref
                .read(removeEducationUseCaseProvider)(edu.id),
            successMessage: 'Education entry removed',
          ),
        ))
            .toList(),
      ),
    );
  }

  Future<void> _addEducation() async {
    String level = 'GRADUATE';
    String? qualificationId;
    final qualificationNameCtrl = TextEditingController();
    final instituteCtrl = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add Education',
                    style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _ModernDropdownField<String>(
                  label: 'Qualification Level',
                  hint: 'Select level',
                  prefixIcon: Icons.school_outlined,
                  value: level,
                  items: _educationLevels
                      .map((l) => DropdownMenuItem(
                      value: l, child: Text(_educationLevelLabels[l]!)))
                      .toList(),
                  onChanged: (v) => setSheetState(() {
                    level = v ?? level;
                    qualificationId = null;
                  }),
                ),
                const SizedBox(height: 16),
                if (level == 'ANY')
                  _ModernTextField(
                    controller: qualificationNameCtrl,
                    label: 'Qualification name',
                    hint: 'e.g. Certificate in Cloud Computing',
                    prefixIcon: Icons.workspace_premium_outlined,
                  )
                else
                  Consumer(
                    builder: (context, ref, _) {
                      final qualsAsync = ref.watch(qualificationsProvider);
                      return qualsAsync.when(
                        loading: () =>
                        const _DropdownSkeleton(label: 'Qualification'),
                        error: (_, __) => _DropdownError(
                          label: 'qualifications',
                          onRetry: () =>
                              ref.invalidate(qualificationsProvider),
                        ),
                        data: (quals) {
                          final filtered =
                          quals.where((q) => q.level == level).toList();
                          return _ModernDropdownField<String>(
                            label: 'Qualification',
                            hint: 'Select qualification',
                            prefixIcon: Icons.workspace_premium_outlined,
                            value: qualificationId,
                            items: filtered
                                .map((q) => DropdownMenuItem(
                                value: q.id, child: Text(q.name)))
                                .toList(),
                            onChanged: (v) =>
                                setSheetState(() => qualificationId = v),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 16),
                _ModernTextField(
                  controller: instituteCtrl,
                  label: 'Institute',
                  hint: 'Institute / school name',
                  prefixIcon: Icons.apartment_outlined,
                  isOptional: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (level != 'ANY' && qualificationId == null) {
                        _showSnack('Please pick a qualification',
                            isError: true);
                        return;
                      }
                      if (level == 'ANY' &&
                          qualificationNameCtrl.text.trim().isEmpty) {
                        _showSnack('Please enter a qualification name',
                            isError: true);
                        return;
                      }
                      Navigator.of(sheetContext).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    await _runSectionSave(
          () => ref.read(addEducationUseCaseProvider)(
        Education(
          id: '',
          level: level,
          qualificationId: level == 'ANY' ? null : qualificationId,
          qualificationName:
          level == 'ANY' ? qualificationNameCtrl.text.trim() : null,
          institute: instituteCtrl.text.trim().isEmpty
              ? null
              : instituteCtrl.text.trim(),
        ),
      ),
      successMessage: 'Education added',
    );
  }

  // ═══════════════════════════════════════════
  // Experience
  // ═══════════════════════════════════════════

  Widget _buildExperienceSection(WorkerProfile profile) {
    return _EditableSectionCard(
      title: 'Experience',
      onAdd: _addExperience,
      child: profile.experience.isEmpty
          ? Text(
        'No experience added yet. (Freshers can also add '
            'internships, traineeships, or projects)',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      )
          : Column(
        children: profile.experience
            .map((exp) => _ListEntryTile(
          icon: Icons.work_outline_rounded,
          title: exp.jobTitle,
          subtitle: exp.isCurrent
              ? '${exp.companyName} · Present'
              : exp.companyName,
          onDelete: () => _runSectionSave(
                () => ref
                .read(removeExperienceUseCaseProvider)(exp.id),
            successMessage: 'Experience entry removed',
          ),
        ))
            .toList(),
      ),
    );
  }

  Future<void> _addExperience() async {
    final companyCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    DateTime? fromDate;
    DateTime? toDate;
    bool isCurrent = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add Experience',
                    style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _ModernTextField(
                  controller: titleCtrl,
                  label: 'Job title',
                  hint: 'e.g. Backend Developer Intern',
                  prefixIcon: Icons.work_outline_rounded,
                ),
                const SizedBox(height: 16),
                _ModernTextField(
                  controller: companyCtrl,
                  label: 'Company name',
                  hint: 'e.g. TechNova Solutions',
                  prefixIcon: Icons.apartment_outlined,
                ),
                const SizedBox(height: 16),
                _ModernDateField(
                  label: 'From',
                  hint: 'Start date',
                  prefixIcon: Icons.calendar_today_outlined,
                  value: fromDate,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fromDate ?? DateTime.now(),
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setSheetState(() => fromDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Currently working here'),
                  value: isCurrent,
                  onChanged: (v) => setSheetState(() {
                    isCurrent = v;
                    if (v) toDate = null;
                  }),
                ),
                if (!isCurrent) ...[
                  const SizedBox(height: 4),
                  _ModernDateField(
                    label: 'To',
                    hint: 'End date',
                    prefixIcon: Icons.calendar_today_outlined,
                    value: toDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: toDate ?? DateTime.now(),
                        firstDate: fromDate ?? DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSheetState(() => toDate = picked);
                    },
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty ||
                          companyCtrl.text.trim().isEmpty ||
                          fromDate == null) {
                        _showSnack(
                          'Job title, company, and start date are required',
                          isError: true,
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    await _runSectionSave(
          () => ref.read(addExperienceUseCaseProvider)(
        Experience(
          id: '',
          companyName: companyCtrl.text.trim(),
          jobTitle: titleCtrl.text.trim(),
          startDate: fromDate!,
          endDate: isCurrent ? null : toDate,
          isCurrent: isCurrent,
        ),
      ),
      successMessage: 'Experience added',
    );
  }

  ImageProvider? _avatarImage() {
    if (_photoPath == null) return null;
    if (_photoPath!.startsWith('http')) return NetworkImage(_photoPath!);
    return FileImage(File(_photoPath!));
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
        data: (profile) {
          _prefillFrom(profile);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Profile Photo ──
                        Center(
                          child: GestureDetector(
                            onTap: _submitting ? null : _pickPhoto,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.primary,
                                        colors.primary.withBlue(
                                          (colors.primary.blue * 0.8).round(),
                                        ),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 52,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage: _avatarImage(),
                                          child: _photoPath == null
                                              ? Icon(
                                            Icons.person_outline_rounded,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          )
                                              : null,
                                        ),
                                        // Dims the avatar and shows a
                                        // spinner for as long as the
                                        // real upload is in flight —
                                        // this is the missing feedback
                                        // that made the save look like
                                        // it "did nothing" for 5-6s.
                                        if (_submitting)
                                          Container(
                                            width: 104,
                                            height: 104,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.black.withOpacity(0.45),
                                            ),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _submitting
                                        ? Icons.hourglass_top_rounded
                                        : Icons.camera_alt_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _submitting
                                ? 'Saving…'
                                : 'Tap to change photo',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Form Card ──
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionLabel('Personal Information'),
                              const SizedBox(height: 16),

                              // Full Name
                              _ModernTextField(
                                controller: _fullNameController,
                                label: 'Full name',
                                hint: 'Enter your full name',
                                prefixIcon: Icons.badge_outlined,
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Date of Birth
                              _ModernDateField(
                                label: 'Date of birth',
                                hint: 'Select your date of birth',
                                prefixIcon: Icons.cake_outlined,
                                value: _dateOfBirth,
                                onTap: _pickDob,
                              ),
                              const SizedBox(height: 16),

                              // Gender
                              _ModernDropdownField<String>(
                                label: 'Gender',
                                hint: 'Select gender',
                                prefixIcon: Icons.wc_outlined,
                                // `_gender` is already the UI label
                                // ('Male'/'Female'/'Other') — mapped
                                // from the API's uppercase enum in
                                // `_prefillFrom`. Never bind the raw
                                // API value directly here.
                                value: _gender,
                                items: _genders
                                    .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g),
                                ))
                                    .toList(),
                                onChanged: (v) => setState(() => _gender = v),
                                validator: (v) =>
                                v == null ? 'Please select a gender' : null,
                              ),
                              const SizedBox(height: 16),

                              _SectionLabel('Location'),
                              const SizedBox(height: 16),

                              // State — backend requires state, city
                              // and locality to be sent together (or
                              // not at all), so these three are one
                              // dependent cascade, not independent
                              // free-text fields.
                              //
                              // Compact tap field instead of
                              // DropdownButtonFormField — opening it
                              // shows a height-capped, searchable
                              // bottom sheet (`_showEditLocationSheet`)
                              // instead of a full-screen dropdown menu
                              // that used to grow to cover the page
                              // once the state/city/locality list had
                              // more than a handful of entries. The
                              // sheet also lets the worker type a
                              // place that isn't in the list and add
                              // it ("Can't find it? Use ...").
                              Consumer(
                                builder: (context, ref, _) {
                                  final statesAsync =
                                  ref.watch(locationStatesProvider);
                                  return statesAsync.when(
                                    loading: () =>
                                    const _DropdownSkeleton(label: 'State'),
                                    error: (_, __) => _DropdownError(
                                      label: 'states',
                                      onRetry: () =>
                                          ref.invalidate(locationStatesProvider),
                                      onEnterManually: () async {
                                        final custom = await _promptCustomLocationText(
                                            context, 'state');
                                        if (custom != null) {
                                          setState(() {
                                            _selectedState = custom;
                                            _selectedCity = null;
                                            _selectedLocalityId = null;
                                            _selectedLocalityName = null;
                                          });
                                        }
                                      },
                                    ),
                                    data: (states) => _LocationFormField(
                                      label: 'State',
                                      icon: Icons.map_outlined,
                                      value: _selectedState,
                                      requiredMessage: 'State is required',
                                      onTap: () async {
                                        final picked =
                                        await _showEditLocationSheet<String>(
                                          context: context,
                                          title: 'Select state',
                                          items: states,
                                          labelOf: (s) => s,
                                          customBuilder: (q) => q,
                                          customHint: 'state',
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _selectedState = picked;
                                            _selectedCity = null;
                                            _selectedLocalityId = null;
                                            _selectedLocalityName = null;
                                          });
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // City — depends on selected state
                              if (_selectedState != null)
                                Consumer(
                                  builder: (context, ref, _) {
                                    final citiesAsync = ref.watch(
                                        locationCitiesProvider(_selectedState!));
                                    return citiesAsync.when(
                                      loading: () => const _DropdownSkeleton(
                                          label: 'City'),
                                      error: (_, __) => _DropdownError(
                                        label: 'cities',
                                        onRetry: () => ref.invalidate(
                                            locationCitiesProvider(
                                                _selectedState!)),
                                        onEnterManually: () async {
                                          final custom =
                                          await _promptCustomLocationText(
                                              context, 'city');
                                          if (custom != null) {
                                            setState(() {
                                              _selectedCity = custom;
                                              _selectedLocalityId = null;
                                              _selectedLocalityName = null;
                                            });
                                          }
                                        },
                                      ),
                                      data: (cities) => _LocationFormField(
                                        label: 'City',
                                        icon: Icons.location_city_outlined,
                                        value: _selectedCity,
                                        requiredMessage: 'City is required',
                                        onTap: () async {
                                          final picked =
                                          await _showEditLocationSheet<String>(
                                            context: context,
                                            title: 'Select city',
                                            items: cities,
                                            labelOf: (c) => c,
                                            customBuilder: (q) => q,
                                            customHint: 'city',
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              _selectedCity = picked;
                                              _selectedLocalityId = null;
                                              _selectedLocalityName = null;
                                            });
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              if (_selectedState != null)
                                const SizedBox(height: 16),

                              // Locality — depends on selected state +
                              // city. Only the *name* is ever sent to
                              // the backend (see `_submit` above), so
                              // a worker can also type a locality
                              // that isn't in the master-data list and
                              // use that name directly — `_selectedLocalityId`
                              // just stays null for those and is only
                              // populated as a best-effort match when
                              // a listed locality is picked.
                              if (_selectedState != null &&
                                  _selectedCity != null)
                                Consumer(
                                  builder: (context, ref, _) {
                                    final key = (
                                    state: _selectedState!,
                                    city: _selectedCity!,
                                    );
                                    final localitiesAsync = ref
                                        .watch(locationLocalitiesProvider(key));
                                    return localitiesAsync.when(
                                      loading: () => const _DropdownSkeleton(
                                          label: 'Locality / Area'),
                                      error: (_, __) => _DropdownError(
                                        label: 'localities',
                                        onRetry: () => ref.invalidate(
                                            locationLocalitiesProvider(key)),
                                        onEnterManually: () async {
                                          final custom =
                                          await _promptCustomLocationText(
                                              context, 'locality');
                                          if (custom != null) {
                                            setState(() {
                                              _selectedLocalityId = null;
                                              _selectedLocalityName = custom;
                                            });
                                          }
                                        },
                                      ),
                                      data: (localities) => _LocationFormField(
                                        label: 'Locality / Area',
                                        icon: Icons.pin_drop_outlined,
                                        value: _selectedLocalityName,
                                        requiredMessage:
                                        'Locality is required',
                                        onTap: () async {
                                          final picked =
                                          await _showEditLocationSheet<String>(
                                            context: context,
                                            title: 'Select locality / area',
                                            items:
                                            localities.map((l) => l.name).toList(),
                                            labelOf: (name) => name,
                                            customBuilder: (q) => q,
                                            customHint: 'locality',
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              _selectedLocalityName = picked;
                                              // Best-effort id match for a
                                              // listed locality; stays
                                              // null for a typed one.
                                              final match = localities
                                                  .where((l) => l.name == picked)
                                                  .toList();
                                              _selectedLocalityId =
                                              match.isNotEmpty
                                                  ? match.first.id
                                                  : null;
                                            });
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),

                        // ── Additional sections (About, Experience,
                        // Skills, Education, Preferences, Languages,
                        // Assets) — each saves independently via its
                        // own edit sheet, separate from the
                        // name/DOB/gender/location "Save Changes"
                        // form above.
                        _buildAboutSection(profile),
                        _buildExperienceSection(profile),
                        _buildSkillsSection(profile),
                        _buildEducationSection(profile),
                        _buildPreferencesSection(profile),
                        _buildPreferredIndustriesSection(profile),
                        _buildPreferredJobRolesSection(profile),
                        _buildPreferredDepartmentsSection(profile),
                        _buildLanguagesSection(profile),
                        _buildAssetsSection(profile),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Sticky Save Button ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade100),
                  ),
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
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.check_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Reusable Components
// ═══════════════════════════════════════════

/// Content of the multi-select bottom sheet used by Skills, Preferred
/// Industries, Preferred Job Roles, Preferred Departments, and Assets.
///
/// Loading now happens *inside* the sheet ([itemsLoader] is awaited
/// from `initState`, not before the sheet is shown), and when
/// [paginate] is true only [pageSize] items are visible at a time with
/// a "Load more" button to reveal the next batch — replacing the old
/// prev/next page flipper.
class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.itemsLoader,
    required this.initialSelected,
    required this.pageSize,
    this.idOf,
    this.paginate = false,
  });

  final String title;
  final Future<List<MasterDataItem>> Function() itemsLoader;
  final Set<String> initialSelected;
  final int pageSize;
  final String Function(MasterDataItem item)? idOf;
  final bool paginate;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _selected = Set<String>.from(widget.initialSelected);
  List<MasterDataItem>? _items;
  // Worker-typed values with no match in the master list — either
  // added just now via the "Add" button, or already part of this
  // profile's saved selection from an earlier custom add (rebuilt
  // from `widget.initialSelected` in `_load`, since the master list
  // has no entry for them to resolve against). Sent to the backend
  // as plain strings, exactly like a real master-data id — see
  // `CustomMasterDataItem`.
  final List<MasterDataItem> _customItems = [];
  bool _loading = true;
  bool _failed = false;
  late int _visibleCount = widget.pageSize;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await widget.itemsLoader();
      if (!mounted) return;
      // Any already-selected id the master list doesn't recognize is
      // a previously-added custom value (this profile was saved with
      // it once already) — rebuild it as a chip instead of silently
      // losing it from the sheet just because it can't be resolved
      // against master data.
      final knownIds = items.map(_idOf).toSet();
      final customFromProfile = widget.initialSelected
          .where((id) => !knownIds.contains(id))
          .map((id) => CustomMasterDataItem(id));
      setState(() {
        _items = items;
        _customItems
          ..clear()
          ..addAll(customFromProfile);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  String _idOf(MasterDataItem item) => widget.idOf?.call(item) ?? item.id;

  /// Adds whatever the worker typed as a selected custom value — sent
  /// later as a plain string, exactly like any other id in [_selected]
  /// (see `CustomMasterDataItem`). Clears the search so the sheet
  /// falls back to the browse view with the new chip already selected.
  void _addCustom(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final custom = CustomMasterDataItem(trimmed);
    setState(() {
      _customItems.add(custom);
      _selected.add(_idOf(custom));
      _searchController.clear();
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final query = _query.trim();
    final searching = query.isNotEmpty;

    // Search matches against master + custom together, and against
    // the FULL master list, not just what pagination has revealed so
    // far — otherwise typing something that exists on "page 4" would
    // show as "no matches" until the worker manually taps "Load more"
    // enough times to reach it.
    final matched = items == null
        ? null
        : (searching
        ? [...items, ..._customItems]
        .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
        .toList()
        : null);

    // Only offer "Add" once the typed text genuinely matches nothing
    // — not as a permanent extra option alongside real results.
    final canAddCustom = searching && matched != null && matched.isEmpty;

    // Pagination only ever trims the master list in browse mode.
    // Custom items are always shown in full and never paginated away
    // — the worker just picked one, so it should never look like the
    // pick silently vanished behind "Load more".
    final visibleMasterItems = items == null
        ? null
        : (widget.paginate ? items.take(_visibleCount).toList() : items);
    final visibleItems = searching
        ? matched
        : (items == null ? null : [..._customItems, ...visibleMasterItems!]);
    final remaining = widget.paginate && items != null && !searching
        ? items.length - _visibleCount
        : 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            )
          else if (_failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    "Couldn't load. Try again.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else if (items == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nothing to pick from yet.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
            else ...[
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (v) {
                    if (canAddCustom) _addCustom(v);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search ${widget.title.toLowerCase()}...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (canAddCustom)
                // Nothing matched — the ONLY thing shown here is the
                // add action itself, no "no matches" text alongside
                // it, so there's exactly one obvious thing to do.
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _addCustom(query),
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
                              'Add "$query"',
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
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: ChipGroup<MasterDataItem>(
                        items: visibleItems!,
                        selectedIds: _selected,
                        idOf: _idOf,
                        labelOf: (i) => i.name,
                        onToggle: (id, isSel) => setState(() {
                          if (isSel) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        }),
                      ),
                    ),
                  ),
                if (widget.paginate && !searching && remaining > 0) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _visibleCount = (_visibleCount + widget.pageSize)
                          .clamp(0, items!.length);
                    }),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text('Load more ($remaining left)'),
                  ),
                ],
              ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// A card for one of the "extra" profile sections (About, Skills,
/// Education, Preferences, etc.) — pass [onEdit] for a pencil icon
/// (single-value or multi-select sections that replace their whole
/// contents), or [onAdd] for a "+" icon (list sections like Education/
/// Experience where new entries are appended, not replaced).
class _EditableSectionCard extends StatelessWidget {
  const _EditableSectionCard({
    required this.title,
    required this.child,
    this.onEdit,
    this.onAdd,
    this.isSaving = false,
  });

  final String title;
  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onAdd;
  // Shows a small spinner next to the title while a save triggered
  // from this section is in flight, so a slow/cold-starting backend
  // doesn't look like the tap did nothing.
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isSaving)
                const Padding(
                  padding: EdgeInsets.all(6),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (onEdit != null)
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: Colors.grey.shade600),
                  ),
                ),
              if (onAdd != null)
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.add_circle_outline,
                        size: 22, color: colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Chip list used by every master-data-backed section (Skills,
/// Preferred Industries/Job Roles/Departments, Assets, Languages) —
/// falls back to a grey placeholder when nothing's picked yet, same
/// tone as the reference "No skills added yet." style.
class _ChipsOrEmpty extends StatelessWidget {
  const _ChipsOrEmpty({required this.labels, required this.emptyText});

  final List<String> labels;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return Text(
        emptyText,
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels
          .map((label) => Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ))
          .toList(),
    );
  }
}

/// One label/value line inside "Personal & Preference Details".
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        Text(value,
            style:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// One row inside Education/Experience's list — icon, title, subtitle,
/// and a delete affordance.
class _ListEntryTile extends StatelessWidget {
  const _ListEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade600)),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded,
                  size: 18, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernTextField extends StatelessWidget {
  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.textInputAction,
    this.validator,
    this.isOptional = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey.shade500),
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
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
        suffixIcon: isOptional
            ? Padding(
          padding: const EdgeInsets.only(right: 12, top: 16),
          child: Text(
            'Optional',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
            ),
          ),
        )
            : null,
      ),
    );
  }
}

class _ModernDateField extends StatelessWidget {
  const _ModernDateField({
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData prefixIcon;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayText = value == null
        ? hint
        : DateFormat('d MMM yyyy').format(value!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey.shade500),
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
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: Colors.grey.shade400,
          ),
        ),
        child: Text(
          displayText,
          style: TextStyle(
            fontSize: 15,
            color: value == null ? Colors.grey.shade500 : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// Extracts a display string for [value] out of [items] by pulling the
/// text out of whichever `DropdownMenuItem` has a matching `.value` —
/// lets `_ModernDropdownField` keep accepting the same
/// `List<DropdownMenuItem<T>>` shape every call site already builds,
/// without each call site having to separately supply a label
/// function too.
String _labelForDropdownValue<T>(T value, List<DropdownMenuItem<T>> items) {
  for (final item in items) {
    if (item.value == value) {
      final child = item.child;
      if (child is Text && child.data != null) return child.data!;
      return value.toString();
    }
  }
  return value.toString();
}

/// Compact, tap-to-open field standing in for the old
/// `DropdownButtonFormField` — opening it shows a height-capped,
/// searchable bottom sheet (`_showEditLocationSheet`) instead of a
/// full-screen dropdown menu, the same fix already applied to the
/// State/City/Locality fields above. Still wraps a [FormField] so
/// `_formKey` validation (used for Gender) keeps working exactly as
/// before.
class _ModernDropdownField<T> extends FormField<T> {
  _ModernDropdownField({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) : super(
    initialValue: value,
    validator: validator,
    builder: (state) {
      final colors = Theme.of(state.context).colorScheme;
      final displayLabel =
      value == null ? null : _labelForDropdownValue<T>(value, items);
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: items.isEmpty
            ? null
            : () async {
          final picked = await _showEditLocationSheet<T>(
            context: state.context,
            title: label,
            items: items.map((i) => i.value as T).toList(),
            labelOf: (v) => _labelForDropdownValue<T>(v, items),
          );
          if (picked != null) {
            state.didChange(picked);
            onChanged(picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: Colors.grey.shade50,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            prefixIcon:
            Icon(prefixIcon, size: 20, color: Colors.grey.shade500),
            suffixIcon:
            Icon(Icons.expand_more_rounded, color: Colors.grey.shade500),
            errorText: state.errorText,
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
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
          child: Text(
            displayLabel ?? hint,
            style: TextStyle(
              fontSize: 15,
              color: value != null ? Colors.black87 : Colors.grey.shade500,
            ),
          ),
        ),
      );
    },
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: colors.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Couldn't load profile",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Something went wrong while loading your profile. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Location dropdown loading/error placeholders
/// (same pattern as PersonalDetailsScreen)
/// ─────────────────────────────────────────────
class _DropdownSkeleton extends StatelessWidget {
  const _DropdownSkeleton({required this.label});
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

class _DropdownError extends StatelessWidget {
  const _DropdownError({
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
          TextButton(
              onPressed: onEnterManually, child: const Text('Enter manually')),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// Small dialog used to collect a free-text value when a location
/// picker's master-data list can't be loaded at all (network/API
/// failure) — mirrors `_promptCustomText` in
/// `CascadingLocationPicker`.
Future<String?> _promptCustomLocationText(BuildContext context, String label) {
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

/// Compact, read-only, tap-to-open field styled like a form field,
/// wrapped in a [FormField] so it still participates in `_formKey`
/// validation the same way the old `DropdownButtonFormField`s did.
/// Tapping it opens `_showEditLocationSheet` instead of a full-screen
/// dropdown menu.
class _LocationFormField extends FormField<String> {
  _LocationFormField({
    required String label,
    required IconData icon,
    required String? value,
    required VoidCallback onTap,
    required String requiredMessage,
  }) : super(
    initialValue: value,
    validator: (_) => value == null ? requiredMessage : null,
    builder: (state) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            prefixIcon: Icon(icon),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 0),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
            errorText: state.errorText,
          ),
          child: Text(
            value ?? 'Select $label',
            style: TextStyle(
              color: value != null ? Colors.black87 : Colors.grey.shade500,
            ),
          ),
        ),
      );
    },
  );
}

/// Opens a height-capped (60% of screen), searchable bottom sheet for
/// picking a state/city/locality, and resolves with the item the
/// worker picked (or null if dismissed). If [customBuilder] is given
/// and the search finds no match, a "Can't find it? Use ..." option
/// lets the worker add whatever they typed instead of getting stuck.
/// Mirrors `_showSearchSheet` in `CascadingLocationPicker`.
Future<T?> _showEditLocationSheet<T>({
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
    builder: (context) => _EditLocationSearchSheet<T>(
      title: title,
      items: items,
      labelOf: labelOf,
      customBuilder: customBuilder,
      customHint: customHint,
    ),
  );
}

class _EditLocationSearchSheet<T> extends StatefulWidget {
  const _EditLocationSearchSheet({
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
  State<_EditLocationSearchSheet<T>> createState() =>
      _EditLocationSearchSheetState<T>();
}

class _EditLocationSearchSheetState<T>
    extends State<_EditLocationSearchSheet<T>> {
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
        .where((item) =>
        widget.labelOf(item).toLowerCase().contains(_query.toLowerCase()))
        .toList();

    // Only offer "use my own value" once nothing in the list actually
    // matches what was typed — not as a standing option alongside
    // real results the worker could just tap instead.
    final canUseCustom = widget.customBuilder != null &&
        _query.trim().isNotEmpty &&
        filtered.isEmpty;

    // Capped at 60% of screen height so the sheet never grows to
    // cover the whole page, regardless of how many items the list
    // has (this was the "make the dropdown compact" fix).
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            'Add "${_query.trim()}"',
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
              // When canUseCustom is showing, the add tile above is
              // already the entire empty-state — no extra "no
              // matches" text underneath it as well.
              child: filtered.isEmpty
                  ? (canUseCustom
                  ? const SizedBox.shrink()
                  : Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  widget.customBuilder != null
                      ? 'No matches — type to search or add your own'
                      : 'No matches for "$_query"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ))
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