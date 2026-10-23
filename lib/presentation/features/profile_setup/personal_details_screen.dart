import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:scn_jobs/core/network/dio_provider.dart' show secureStorageServiceProvider;
import 'package:scn_jobs/domain/entities/master_data.dart' show LocationItem;
import 'package:scn_jobs/domain/entities/worker_profile.dart';
import 'package:scn_jobs/presentation/features/profile_setup/profile_setup_controller.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';
import 'package:scn_jobs/presentation/providers/master/master_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

class PersonalDetailsScreen extends ConsumerStatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  ConsumerState<PersonalDetailsScreen> createState() =>
      _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends ConsumerState<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  // Backend requires state + city + locality together — these three
  // now come from the master-data cascade (same source as
  // CascadingLocationPicker) instead of free-text fields, so we can
  // never submit one without the other two.
  String? _selectedState;
  String? _selectedCity;
  String? _selectedLocalityId;
  String? _selectedLocalityName;
  DateTime? _dateOfBirth;
  String? _gender;
  String? _maritalStatus;
  String? _photoPath;
  bool _submitting = false;
  // Set once the worker's already-saved profile (if any) has been
  // applied to these fields — without this guard, every rebuild while
  // `currentProfileProvider` is loading/refreshing would re-stomp
  // whatever the worker has typed so far.
  bool _prefilled = false;

  // "Is primary phone your WhatsApp number?" — this toggle itself
  // isn't a backend field (the API has no such concept); it's purely
  // UI logic that decides whether `alternatePhone` gets sent at all.
  // true (default) = worker's WhatsApp is the same as their
  // registered/verified phone, so no alternate number goes out.
  bool _whatsappSameAsPrimary = true;

  static const _genders = ['Male', 'Female', 'Other'];
  // Doc-confirmed values from the `POST /worker/profile` example
  // payloads (§6) — only these two are shown, since the doc doesn't
  // document a broader enum and guessing extra values risks a 400.
  static const _maritalStatuses = ['Single', 'Married'];
  static const _maritalStatusApiValues = {
    'Single': 'SINGLE',
    'Married': 'MARRIED',
  };
  static const _maritalStatusApiToLabel = {
    'SINGLE': 'Single',
    'MARRIED': 'Married',
  };
  // Backend enum is MALE | FEMALE | ANY — UI keeps friendly labels,
  // this maps the selected label to what PATCH /worker/profile expects.
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
    _alternatePhoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Prefill from what the worker already gave at registration —
    // `Full name` here is a fresh field on this screen, so without
    // this it'd always start blank and feel like retyping something
    // already provided. `GET /auth/me`/`currentProfileProvider` can't
    // supply this (the API doesn't return a name from either), so the
    // value is read from where it was captured once at register time
    // — see `SecureStorageService.saveDisplayName`'s doc.
    // NOTE: this is a fallback only — `_prefillFromProfile` below
    // overwrites it with the real saved name once/if the worker's
    // profile has one (e.g. they already completed this step before).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_fullNameController.text.isNotEmpty) return;
      final name =
      await ref.read(secureStorageServiceProvider).getDisplayName();
      if (mounted && name != null && name.isNotEmpty) {
        _fullNameController.text = name;
      }
    });
  }

  /// Applies a previously-saved profile to the form once — this is why
  /// Basic Information didn't survive closing and reopening the app:
  /// this screen only ever started blank, it never read back what
  /// `PATCH /worker/profile` had already saved (unlike Education/
  /// Experience, which are separate lists always re-fetched from their
  /// own `GET` endpoints). Education/Experience/Resume steps don't
  /// have this problem since their data lives server-side per-item,
  /// not in this screen's local state.
  void _prefillFromProfile(WorkerProfile profile) {
    if (_prefilled) return;
    _prefilled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (profile.name != null && profile.name!.isNotEmpty) {
          _fullNameController.text = profile.name!;
        }
        _selectedState = profile.state;
        _selectedCity = profile.city;
        _selectedLocalityName = profile.locality;
        _dateOfBirth = profile.dateOfBirth;
        _gender = profile.gender == null
            ? null
            : _genderApiToLabel[profile.gender];
        _photoPath = profile.photoUrl;
        _maritalStatus = profile.maritalStatus == null
            ? null
            : _maritalStatusApiToLabel[profile.maritalStatus];
        // `alternatePhone` only ever arrives when it was actually set
        // (differs from the verified primary) — its presence itself
        // is what "No, different number" means, there's no separate
        // same/different flag from the backend.
        if (profile.alternatePhone != null &&
            profile.alternatePhone!.isNotEmpty) {
          _whatsappSameAsPrimary = false;
          _alternatePhoneController.text = profile.alternatePhone!;
        }
      });
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 14),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
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
    if (_dateOfBirth == null) {
      _showErrorSnack('Please select your date of birth');
      return;
    }
    if (_selectedState == null ||
        _selectedCity == null ||
        _selectedLocalityName == null) {
      _showErrorSnack('Please select state, city and locality');
      return;
    }
    if (!_whatsappSameAsPrimary &&
        _alternatePhoneController.text.trim().isEmpty) {
      _showErrorSnack('Please enter your WhatsApp number');
      return;
    }

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
        // Only sent when WhatsApp differs from the primary/verified
        // number — "Yes, same" means nothing extra to tell the
        // backend.
        alternatePhone: _whatsappSameAsPrimary
            ? null
            : _alternatePhoneController.text.trim().isEmpty
            ? null
            : _alternatePhoneController.text.trim(),
        maritalStatus: _maritalStatus == null
            ? null
            : _maritalStatusApiValues[_maritalStatus],
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
      context.push('/profile-setup/education');
    } catch (_) {
      if (mounted) {
        _showErrorSnack("Couldn't save your details. Try again.");
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showErrorSnack(String message) {
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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
    bool isRequired = false,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
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
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 2),
      ),
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Applies once the saved profile (if any) loads in — see
    // `_prefillFromProfile`'s doc for why this screen needs it.
    ref.watch(currentProfileProvider).whenData(_prefillFromProfile);
    final dobLabel = _dateOfBirth == null
        ? 'Date of birth *'
        : DateFormat('d MMM yyyy').format(_dateOfBirth!);
    final dobColor = _dateOfBirth == null
        ? Colors.grey.shade600
        : Colors.black87;

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
          'Personal Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
                    /// Progress indicator
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
                            'Step 2 of 4',
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

                    /// Photo picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade100,
                                border: Border.all(
                                  color: _photoPath != null
                                      ? colors.primary
                                      : Colors.grey.shade300,
                                  width: _photoPath != null ? 3 : 2,
                                ),
                                image: _photoPath != null
                                    ? DecorationImage(
                                  image: FileImage(File(_photoPath!)),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: _photoPath == null
                                  ? Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 36,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Add Photo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              )
                                  : null,
                            ),
                            /// Edit badge
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Upload a clear photo for your profile',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    /// Section: Basic Info
                    _SectionHeader(title: 'Basic Information', icon: Icons.person_outline),
                    const SizedBox(height: 16),

                    /// Full Name
                    TextFormField(
                      controller: _fullNameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        label: 'Full name',
                        icon: Icons.badge_outlined,
                        hint: 'e.g. Rahul Sharma',
                        isRequired: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),

                    const SizedBox(height: 18),

                    /// WhatsApp toggle — see [_whatsappSameAsPrimary]'s
                    /// doc: purely UI logic, decides whether
                    /// `alternatePhone` is sent at all.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Is primary phone your WhatsApp number?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _WhatsappOption(
                                  label: 'Yes (WhatsApp is same)',
                                  selected: _whatsappSameAsPrimary,
                                  onTap: () => setState(
                                          () => _whatsappSameAsPrimary = true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _WhatsappOption(
                                  label: 'No (Add alternate number)',
                                  selected: !_whatsappSameAsPrimary,
                                  onTap: () => setState(
                                          () => _whatsappSameAsPrimary = false),
                                ),
                              ),
                            ],
                          ),
                          if (!_whatsappSameAsPrimary) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _alternatePhoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: _fieldDecoration(
                                label: 'WhatsApp Number',
                                icon: Icons.chat_outlined,
                                hint: '10-digit mobile number',
                                isRequired: true,
                              ).copyWith(filled: true, fillColor: Colors.white),
                              validator: (v) {
                                if (_whatsappSameAsPrimary) return null;
                                if (v == null || v.trim().isEmpty) {
                                  return 'WhatsApp number is required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    /// Phone Number — read-only. This is the
                    /// OTP-verified number tied to the login itself
                    /// (`User.phone` via `GET /auth/me`), not a form
                    /// field on `/worker/profile` — shown here just so
                    /// the worker can confirm it's the right number,
                    /// same as the reference design. Changing it isn't
                    /// something this screen does.
                    Consumer(
                      builder: (context, ref, _) {
                        final userAsync = ref.watch(authStateProvider);
                        final phone = userAsync.asData?.value?.phone;
                        if (phone == null || phone.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return TextFormField(
                          initialValue: phone,
                          enabled: false,
                          decoration: _fieldDecoration(
                            label: 'Primary Phone Number',
                            icon: Icons.phone_outlined,
                          ).copyWith(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            suffixIcon: Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Colors.green.shade400,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    /// DOB picker
                    InkWell(
                      onTap: _pickDob,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: _fieldDecoration(
                          label: 'Date of birth',
                          icon: Icons.cake_outlined,
                          isRequired: true,
                          suffix: _dateOfBirth != null
                              ? Icon(Icons.edit_calendar_outlined,
                              size: 18, color: colors.primary)
                              : null,
                        ),
                        child: SizedBox(
                          height: 24,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _dateOfBirth == null
                                  ? 'Select date of birth'
                                  : DateFormat('dd MMMM yyyy')
                                  .format(_dateOfBirth!),
                              style: TextStyle(
                                fontSize: 15,
                                color: dobColor,
                                fontWeight: _dateOfBirth == null
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    /// Gender chips
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Gender',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '*',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: _genders.map((g) {
                            final isSelected = _gender == g;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: InkWell(
                                onTap: () => setState(() => _gender = g),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (_gender == null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 6),
                            child: Text(
                              'Please select a gender',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    /// Marital Status — doc-confirmed optional field
                    /// on `PATCH /worker/profile` (§6). Only
                    /// SINGLE/MARRIED are documented, so no "Other" or
                    /// "Divorced" option is guessed in.
                    _SearchablePickerField<String>(
                      decoration: _fieldDecoration(
                        label: 'Marital Status',
                        icon: Icons.favorite_border_rounded,
                        suffix: Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey.shade500),
                      ),
                      items: _maritalStatuses,
                      labelOf: (m) => m,
                      selectedLabel: _maritalStatus,
                      sheetTitle: 'Select Marital Status',
                      onSelected: (v) => setState(() => _maritalStatus = v),
                    ),

                    const SizedBox(height: 32),

                    /// Section: Location
                    _SectionHeader(title: 'Location', icon: Icons.location_on_outlined),
                    const SizedBox(height: 16),

                    /// State
                    Consumer(
                      builder: (context, ref, _) {
                        final statesAsync = ref.watch(locationStatesProvider);
                        return statesAsync.when(
                          loading: () => const _DropdownSkeleton(label: 'State'),
                          error: (_, __) => _DropdownError(
                            label: 'states',
                            onRetry: () =>
                                ref.invalidate(locationStatesProvider),
                            onEnterManually: () async {
                              final custom =
                              await _promptCustomText(context, 'state');
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
                          data: (states) => _SearchablePickerField<String>(
                            decoration: _fieldDecoration(
                              label: 'State',
                              icon: Icons.map_outlined,
                              isRequired: true,
                              suffix: Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey.shade500),
                            ),
                            items: states,
                            labelOf: (s) => s,
                            selectedLabel: _selectedState,
                            sheetTitle: 'Select State',
                            customBuilder: (query) => query,
                            customHint: 'state',
                            onSelected: (v) => setState(() {
                              _selectedState = v;
                              // City/locality depend on state — reset so
                              // we never submit a stale combination.
                              _selectedCity = null;
                              _selectedLocalityId = null;
                              _selectedLocalityName = null;
                            }),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    /// City — depends on selected state
                    if (_selectedState != null)
                      Consumer(
                        builder: (context, ref, _) {
                          final citiesAsync = ref
                              .watch(locationCitiesProvider(_selectedState!));
                          return citiesAsync.when(
                            loading: () =>
                            const _DropdownSkeleton(label: 'City'),
                            error: (_, __) => _DropdownError(
                              label: 'cities',
                              onRetry: () => ref.invalidate(
                                  locationCitiesProvider(_selectedState!)),
                              onEnterManually: () async {
                                final custom =
                                await _promptCustomText(context, 'city');
                                if (custom != null) {
                                  setState(() {
                                    _selectedCity = custom;
                                    _selectedLocalityId = null;
                                    _selectedLocalityName = null;
                                  });
                                }
                              },
                            ),
                            data: (cities) => _SearchablePickerField<String>(
                              decoration: _fieldDecoration(
                                label: 'City',
                                icon: Icons.location_city_outlined,
                                isRequired: true,
                                suffix: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Colors.grey.shade500),
                              ),
                              items: cities,
                              labelOf: (c) => c,
                              selectedLabel: _selectedCity,
                              sheetTitle: 'Select City',
                              customBuilder: (query) => query,
                              customHint: 'city',
                              onSelected: (v) => setState(() {
                                _selectedCity = v;
                                _selectedLocalityId = null;
                                _selectedLocalityName = null;
                              }),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 18),

                    /// Locality — depends on selected state + city
                    if (_selectedState != null && _selectedCity != null)
                      Consumer(
                        builder: (context, ref, _) {
                          final key = (
                          state: _selectedState!,
                          city: _selectedCity!,
                          );
                          final localitiesAsync =
                          ref.watch(locationLocalitiesProvider(key));
                          return localitiesAsync.when(
                            loading: () =>
                            const _DropdownSkeleton(label: 'Locality / Area'),
                            error: (_, __) => _DropdownError(
                              label: 'localities',
                              onRetry: () => ref
                                  .invalidate(locationLocalitiesProvider(key)),
                              onEnterManually: () async {
                                final custom = await _promptCustomText(
                                    context, 'locality / area');
                                if (custom != null) {
                                  setState(() {
                                    _selectedLocalityId = null;
                                    _selectedLocalityName = custom;
                                  });
                                }
                              },
                            ),
                            data: (localities) =>
                                _SearchablePickerField<LocationItem>(
                                  decoration: _fieldDecoration(
                                    label: 'Locality / Area',
                                    icon: Icons.pin_drop_outlined,
                                    isRequired: true,
                                    suffix: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.grey.shade500),
                                  ),
                                  items: localities,
                                  labelOf: (l) => l.name,
                                  selectedLabel: _selectedLocalityName,
                                  sheetTitle: 'Select Locality / Area',
                                  customHint: 'locality / area',
                                  // No real LocationItem id for a custom
                                  // entry — id stays empty, only the name
                                  // (free text) goes to the backend, same
                                  // as the picked-item path below.
                                  customBuilder: (query) => LocationItem(
                                    id: '',
                                    name: query,
                                    city: _selectedCity ?? '',
                                    stateName: _selectedState ?? '',
                                  ),
                                  onSelected: (l) => setState(() {
                                    _selectedLocalityId =
                                    l.id.isEmpty ? null : l.id;
                                    _selectedLocalityName = l.name;
                                  }),
                                ),
                          );
                        },
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
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Save & Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
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

/// ─────────────────────────────────────────────
/// Location dropdown loading/error placeholders
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

/// ─────────────────────────────────────────────
/// Section header widget
/// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _WhatsappOption extends StatelessWidget {
  const _WhatsappOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: selected ? colors.primary : Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? colors.primary : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Compact, searchable location field
/// ─────────────────────────────────────────────
/// Replaces the old `DropdownButtonFormField` for State/City/Locality:
/// the native dropdown menu opened near full-screen (and its own
/// loading state looked like an oversized spinner). This renders like
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
                      : 'No matches — tap above to add "$query"')
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
