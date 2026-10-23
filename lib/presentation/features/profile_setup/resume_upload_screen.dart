import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scn_jobs/domain/entities/upload_cancel_token.dart';
import 'package:scn_jobs/domain/entities/upload_file_kind.dart';
import 'package:scn_jobs/domain/entities/upload_progress.dart';
import 'package:scn_jobs/presentation/features/profile_setup/profile_setup_controller.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';
import 'package:scn_jobs/presentation/providers/upload/upload_providers.dart';

enum _Mode { pickFile, pasteLink }

/// Last profile-setup step. Two paths to the same outcome
/// (`WorkerProfile.resumeUrl` gets set):
/// 1. Pick a PDF/DOC/DOCX, upload it, get a URL back.
/// 2. Paste an existing link (Google Drive, Dropbox, etc.) — a
///    deliberate fallback for workers who already have their resume
///    hosted somewhere, and a way to unblock testing if the upload
///    endpoint isn't confirmed/live yet.
class ResumeUploadScreen extends ConsumerStatefulWidget {
  const ResumeUploadScreen({super.key});

  @override
  ConsumerState<ResumeUploadScreen> createState() => _ResumeUploadScreenState();
}

class _ResumeUploadScreenState extends ConsumerState<ResumeUploadScreen> {
  _Mode _mode = _Mode.pickFile;

  PlatformFile? _pickedFile;
  UploadProgress? _progress;
  UploadCancelToken? _cancelToken;
  bool _uploading = false;
  bool _saving = false;
  String? _errorMessage;

  final _linkController = TextEditingController();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: UploadFileKind.resume.allowedExtensions,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return;

    if (file.size > UploadFileKind.resume.maxSizeBytes) {
      setState(() => _errorMessage = 'File must be under 5 MB.');
      return;
    }

    setState(() {
      _pickedFile = file;
      _errorMessage = null;
    });
  }

  Future<void> _startUpload() async {
    final file = _pickedFile;
    if (file?.path == null) return;

    final cancelToken = UploadCancelToken();
    setState(() {
      _uploading = true;
      _errorMessage = null;
      _cancelToken = cancelToken;
      _progress = const UploadProgress(bytesSent: 0, totalBytes: 1);
    });

    try {
      final uploadUseCase = ref.read(uploadResumeUseCaseProvider);
      final url = await uploadUseCase(
        context: context,
        filePath: file!.path!,
        fileName: file.name,
        cancelToken: cancelToken,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await _saveResumeUrl(url);
    } catch (e, st) {
      // Release-safe: `print()` is NOT stripped from release builds,
      // so the old version leaked the full failure + stack trace to
      // logcat on every device. debugPrint under kDebugMode means
      // this is silent in release and still visible while developing.
      if (kDebugMode) {
        debugPrint('Resume upload failed: $e\n$st');
      }
      if (!mounted) return;
      if (cancelToken.isCancelled) {
        setState(() {
          _pickedFile = null;
          _progress = null;
        });
      } else {
        setState(
              () => _errorMessage =
          'Upload failed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _cancelUpload() {
    _cancelToken?.cancel();
  }

  Future<void> _submitPastedLink() async {
    final url = _linkController.text.trim();
    if (url.isEmpty || !Uri.tryParse(url)!.isAbsolute) {
      setState(
            () => _errorMessage = 'Enter a valid link (starting with https://).',
      );
      return;
    }
    setState(() => _errorMessage = null);
    await _saveResumeUrl(url);
  }

  Future<void> _saveResumeUrl(String url) async {
    setState(() => _saving = true);
    try {
      final useCase = ref.read(updateResumeUrlUseCaseProvider);
      // TEMP DEBUG — investigating: Settings still shows "Complete
      // your profile" right after finishing this whole wizard once,
      // but the second full run works. `updateResumeUrl` doesn't PATCH
      // anything itself — it just refetches the profile, trusting the
      // backend's own upload webhook already set `resumeUrl` (see
      // `ProfileRepositoryImpl.updateResumeUrl`'s doc). If that webhook
      // hasn't landed yet by the time this refetch fires, resumeUrl
      // (and whatever "profile complete" check depends on it) could
      // still read as unset on this very first fetch.
      final before = DateTime.now().toIso8601String();
      final profile = await useCase(url);
      if (kDebugMode) {
        debugPrint(
          "=========== resume upload → getProfile() — $before — resumeUrl: ${profile.resumeUrl} ===========",
        );
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
      context.push('/profile-setup/complete');
    } catch (_) {
      if (mounted) {
        setState(
              () => _errorMessage = "Couldn't save your resume link. Try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() {
    ref.read(profileSetupControllerProvider.notifier).completeCurrentStep();
    context.push('/profile-setup/complete');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final busy = _uploading || _saving;

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
          'Upload Resume',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: busy ? null : _skip,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade500,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                          'Final Step',
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
                            Icons.description_rounded,
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
                                'Upload your resume',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your resume to help recruiters learn more about you. You can upload a file or paste a link.',
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

                  /// Mode toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Upload File',
                            icon: Icons.upload_file_rounded,
                            isSelected: _mode == _Mode.pickFile,
                            onTap: busy
                                ? null
                                : () => setState(() => _mode = _Mode.pickFile),
                          ),
                        ),
                        Expanded(
                          child: _ModeButton(
                            label: 'Paste Link',
                            icon: Icons.link_rounded,
                            isSelected: _mode == _Mode.pasteLink,
                            onTap: busy
                                ? null
                                : () => setState(() => _mode = _Mode.pasteLink),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// Content based on mode
                  if (_mode == _Mode.pickFile)
                    _buildFilePicker(colors)
                  else
                    _buildLinkInput(colors),

                  /// Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 20, color: Colors.red.shade400),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          /// Bottom note
          if (!busy)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Center(
                child: Text(
                  'This step is optional — you can skip and add a resume later',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilePicker(ColorScheme colors) {
    if (_pickedFile == null) {
      return InkWell(
        onTap: _uploading ? null : _pickFile,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  size: 40,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tap to upload your resume',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PDF, DOC, or DOCX (max 5 MB)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// File info row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: colors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pickedFile!.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(_pickedFile!.size),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_uploading)
                IconButton(
                  onPressed: () => setState(() => _pickedFile = null),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        size: 18, color: Colors.red.shade400),
                  ),
                ),
            ],
          ),

          /// Upload progress
          if (_uploading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress?.fraction ?? 0,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_progress?.percentage ?? 0}% uploaded',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                TextButton(
                  onPressed: _cancelUpload,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _startUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
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
                      'Upload Resume',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.cloud_upload_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkInput(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste a public link',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Google Drive, Dropbox, or any publicly accessible URL.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _linkController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Resume link',
                  hintText: 'https://drive.google.com/...',
                  prefixIcon: Icon(Icons.link_rounded,
                      size: 22, color: Colors.grey.shade500),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                    BorderSide(color: colors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submitPastedLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
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
                        'Save Link',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.check_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────
/// Mode toggle button
/// ─────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
