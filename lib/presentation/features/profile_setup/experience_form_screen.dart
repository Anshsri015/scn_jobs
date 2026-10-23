import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:scn_jobs/core/error/api_failure.dart';

import 'package:scn_jobs/domain/entities/experience.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

class ExperienceFormScreen extends ConsumerStatefulWidget {
  const ExperienceFormScreen({super.key});

  @override
  ConsumerState<ExperienceFormScreen> createState() =>
      _ExperienceFormScreenState();
}

class _ExperienceFormScreenState extends ConsumerState<ExperienceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  // Display-only — the picker returns a full date (day included), so
  // show the full date here too instead of collapsing it to month+year.
  final _dateFormat = DateFormat('d MMM yyyy');
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCurrent = false;
  bool _submitting = false;
  bool _markingFresher = false;

  @override
  void dispose() {
    _companyController.dispose();
    _jobTitleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// "I'm a Fresher" — for people with no work experience at all, so
  /// they don't have to fill in company/job-title fields just to get
  /// past this step. Marks the profile and pops straight back to the
  /// experience list without adding an entry.
  Future<void> _markAsFresher() async {
    if (_markingFresher || _submitting) return;
    setState(() => _markingFresher = true);
    try {
      await ref.read(updateWorkingStatusUseCaseProvider)(isFresher: true);
      if (mounted) {
        HapticFeedback.lightImpact();
        context.pop(false);
      }
    } catch (e) {
      if (mounted) {
        _showError(e is ApiFailure ? e.message : "Couldn't save. Try again.");
      }
    } finally {
      if (mounted) setState(() => _markingFresher = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_endDate ?? now),
      firstDate: DateTime(now.year - 60),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
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
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      _showError('Please select a start date');
      return;
    }
    if (!_isCurrent && _endDate == null) {
      _showError('Please select an end date, or mark as current');
      return;
    }
    if (!_isCurrent && _endDate!.isBefore(_startDate!)) {
      _showError('End date must be after start date');
      return;
    }

    setState(() => _submitting = true);
    try {
      final useCase = ref.read(addExperienceUseCaseProvider);
      await useCase(
        Experience(
          id: '',
          companyName: _companyController.text.trim(),
          jobTitle: _jobTitleController.text.trim(),
          startDate: _startDate!,
          endDate: _isCurrent ? null : _endDate,
          isCurrent: _isCurrent,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showError(e is ApiFailure ? e.message : "Couldn't save. Try again.");
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
        title: const Text(
          'Add Experience',
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
                              Icons.work_history_rounded,
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
                                  'Work Experience',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add your past or current jobs to help recruiters understand your background.',
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

                    /// I'm a Fresher — sits right at the top, above the
                    /// company/job-title fields, so someone with no
                    /// experience can tap straight through instead of
                    /// filling in a form for a job they never had.
                    InkWell(
                      onTap: _markingFresher ? null : _markAsFresher,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.emoji_objects_outlined,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "I'm a Fresher",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  Text(
                                    "I don't have any work experience yet",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _markingFresher
                                ? SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.blue.shade700,
                              ),
                            )
                                : Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// Job Title
                    TextFormField(
                      controller: _jobTitleController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        label: 'Job title',
                        icon: Icons.work_outline_rounded,
                        hint: 'e.g. Delivery Executive',
                        isRequired: true,
                      ),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Job title is required' : null,
                    ),

                    const SizedBox(height: 18),

                    /// Company
                    TextFormField(
                      controller: _companyController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: _fieldDecoration(
                        label: 'Company name',
                        icon: Icons.apartment_outlined,
                        hint: 'e.g. Amazon, Swiggy',
                        isRequired: true,
                      ),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
                    ),

                    const SizedBox(height: 28),

                    /// Date Range Section
                    _SectionHeader(title: 'Duration', icon: Icons.date_range_outlined),
                    const SizedBox(height: 16),

                    /// Date range row
                    Row(
                      children: [
                        /// Start Date
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(isStart: true),
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _fieldDecoration(
                                label: 'Start date',
                                icon: Icons.calendar_today_outlined,
                                isRequired: true,
                                suffix: _startDate != null
                                    ? Icon(Icons.edit_calendar_outlined,
                                    size: 18, color: colors.primary)
                                    : null,
                              ).copyWith(
                                // Two side-by-side fields don't leave much
                                // room for a full "13 Sep 2021" — trim the
                                // padding a bit to give the text more space.
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                              ),
                              child: SizedBox(
                                height: 24,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _startDate == null
                                        ? 'Select'
                                        : _dateFormat.format(_startDate!),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _startDate == null
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                      fontWeight: _startDate == null
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        /// Arrow
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),

                        const SizedBox(width: 12),

                        /// End Date
                        Expanded(
                          child: InkWell(
                            onTap: _isCurrent ? null : () => _pickDate(isStart: false),
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: _fieldDecoration(
                                label: 'End date',
                                icon: Icons.event_outlined,
                                suffix: _endDate != null && !_isCurrent
                                    ? Icon(Icons.edit_calendar_outlined,
                                    size: 18, color: colors.primary)
                                    : null,
                              ).copyWith(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                              ),
                              child: SizedBox(
                                height: 24,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _isCurrent
                                        ? 'Present'
                                        : _endDate == null
                                        ? 'Select'
                                        : _dateFormat.format(_endDate!),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _isCurrent
                                          ? Colors.green.shade600
                                          : _endDate == null
                                          ? Colors.grey.shade400
                                          : Colors.black87,
                                      fontWeight: _isCurrent || _endDate != null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// Currently working here toggle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isCurrent
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isCurrent
                              ? Colors.green.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isCurrent
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isCurrent
                                  ? Icons.check_rounded
                                  : Icons.work_outline,
                              size: 18,
                              color: _isCurrent
                                  ? Colors.green.shade700
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'I currently work here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isCurrent
                                        ? Colors.green.shade800
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  _isCurrent
                                      ? 'End date set to Present'
                                      : 'Mark if this is your current job',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isCurrent,
                            onChanged: (v) => setState(() {
                              _isCurrent = v;
                              if (v) _endDate = null;
                            }),
                            activeColor: Colors.green.shade600,
                            activeTrackColor: Colors.green.shade200,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    /// Description
                    _SectionHeader(title: 'Job Description', icon: Icons.description_outlined),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _fieldDecoration(
                        label: 'What did you do here?',
                        icon: Icons.notes_outlined,
                        hint: 'Describe your responsibilities and achievements...',
                      ).copyWith(
                        // The prefix icon centers itself across the whole
                        // 4-line box, so it lands mid-way down and sits on
                        // top of the wrapped text (looked like a stray
                        // "line 3"). Multi-line fields read fine without
                        // it, so drop it here instead of fighting its
                        // alignment.
                        prefixIcon: null,
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.all(16),
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
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Save Experience',
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
      ),
    );
  }
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