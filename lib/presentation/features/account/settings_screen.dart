import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scn_jobs/presentation/features/account/account_controller.dart';
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';
import 'package:scn_jobs/presentation/providers/profile/profile_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(onboardingStatusProvider);
    });
  }

  Future<void> _confirmAndLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmDialog(
      context: context,
      icon: Icons.logout_rounded,
      iconColor: Colors.orange,
      title: 'Log out?',
      message: "You'll need to log in again to continue.",
      confirmText: 'Log out',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(accountControllerProvider.notifier).logout();

    final state = ref.read(accountControllerProvider);
    if (state.hasError && context.mounted) {
      _showErrorSnackBar(context, "Couldn't log out. Please try again.");
    }
  }

  Future<void> _confirmAndDeleteAccount(
      BuildContext context,
      WidgetRef ref,
      ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete account?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your profile, applications, '
                  'and account. This cannot be undone.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Type DELETE to confirm',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'DELETE',
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              controller.text.trim() == 'DELETE',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(accountControllerProvider.notifier).deleteAccount();

    final state = ref.read(accountControllerProvider);
    if (state.hasError && context.mounted) {
      _showErrorSnackBar(context, "Couldn't delete your account. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountControllerProvider);
    final isBusy = accountState.isLoading;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Profile Summary Card ──
            Builder(
              builder: (context) {
                // Same profile the worker edits in Edit Profile
                // (`currentProfileProvider` is invalidated there on
                // save, so this stays in sync). While it loads or if
                // the fetch fails we just show the generic fallbacks —
                // never crash this card over a missing/bad photo.
                final profile = ref.watch(currentProfileProvider).valueOrNull;

                final photoUrl = profile?.photoUrl;
                ImageProvider? avatarImage;
                if (photoUrl != null && photoUrl.isNotEmpty) {
                  avatarImage = photoUrl.startsWith('http')
                      ? NetworkImage(photoUrl)
                      : FileImage(File(photoUrl)) as ImageProvider;
                }

                final name = (profile?.name ?? '').trim();
                final location = [profile?.city, profile?.state]
                    .where((e) => e != null && e.trim().isNotEmpty)
                    .map((e) => e!.trim())
                    .join(', ');

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push('/settings/edit-profile'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Photo with a soft brand-colour ring so it
                            // stands out on the white card.
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.primary.withOpacity(0.25),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor:
                                colors.primary.withOpacity(0.08),
                                backgroundImage: avatarImage,
                                onBackgroundImageError: avatarImage == null
                                    ? null
                                    : (_, __) {},
                                child: avatarImage == null
                                    ? Icon(
                                  Icons.person_rounded,
                                  color: colors.primary,
                                  size: 32,
                                )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isNotEmpty ? name : 'My Account',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    location.isNotEmpty
                                        ? location
                                        : 'Manage your profile & preferences',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Account Section ──
            const _SectionHeader(title: 'Account'),
            _SettingsCard(
              children: [
                ref.watch(onboardingStatusProvider).maybeWhen(
                  data: (needsOnboarding) => needsOnboarding
                      ? _SettingsTile(
                    icon: Icons.person_add_alt_1_rounded,
                    iconBgColor: Colors.orange.shade50,
                    iconColor: Colors.orange.shade600,
                    title: 'Complete your profile',
                    subtitle: 'Finish setup to apply for jobs',
                    showDivider: true,
                    onTap: () => context.push('/profile-setup/create'),
                  )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  iconBgColor: colors.primary.withOpacity(0.1),
                  iconColor: colors.primary,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal details',
                  onTap: () => context.push('/settings/edit-profile'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Support Section ──
            const _SectionHeader(title: 'Support'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconBgColor: Colors.purple.shade50,
                  iconColor: Colors.purple,
                  title: 'About',
                  subtitle: 'App version & info',
                  onTap: () => context.push('/settings/about'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Account Actions Section ──
            _SectionHeader(title: 'Account Actions', color: Colors.red.shade400),
            _SettingsCard(
              borderColor: Colors.red.shade100,
              children: [
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  iconBgColor: Colors.orange.shade50,
                  iconColor: Colors.orange.shade700,
                  title: 'Log out',
                  titleColor: Colors.orange.shade800,
                  showDivider: true,
                  onTap: isBusy ? null : () => _confirmAndLogout(context, ref),
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  iconBgColor: Colors.red.shade50,
                  iconColor: Colors.red,
                  title: 'Delete account',
                  titleColor: Colors.red,
                  onTap: isBusy
                      ? null
                      : () => _confirmAndDeleteAccount(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Version footer
            Center(
              child: Text(
                'SCN Jobs v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Future<bool?> _showConfirmDialog({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Reusable Settings Components
// ═══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color ?? Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, this.borderColor});

  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.showDivider = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 62, color: Colors.grey.shade100),
      ],
    );
  }
}