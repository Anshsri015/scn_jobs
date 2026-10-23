import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:scn_jobs/core/utils/legal_links.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
        ),
        title: const Text(
          'About',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final appName = info?.appName ?? 'SCN Jobs';
          final version = info == null
              ? ''
              : 'Version ${info.version} (${info.buildNumber})';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── App Branding ──
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          // Real logo (assets/images/logo.jpeg — same
                          // file used on splash/login), falls back to
                          // the old placeholder icon if missing.
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/images/final.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  Container(
                                    decoration: BoxDecoration(
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
                                    child: const Icon(
                                      Icons.work_outline_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          appName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            version.isEmpty ? 'Loading...' : version,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Legal & Info ──
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _AboutTile(
                          icon: Icons.privacy_tip_outlined,
                          iconBgColor: Colors.blue.shade50,
                          iconColor: Colors.blue.shade600,
                          title: 'Privacy Policy',
                          trailing: Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () =>
                              LegalLinks.open(context, LegalLinks.privacy),
                        ),
                        const Divider(height: 1, indent: 56),
                        _AboutTile(
                          icon: Icons.description_outlined,
                          iconBgColor: Colors.orange.shade50,
                          iconColor: Colors.orange.shade600,
                          title: 'Terms of Service',
                          trailing: Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () =>
                              LegalLinks.open(context, LegalLinks.terms),
                        ),
                        const Divider(height: 1, indent: 56),
                        _AboutTile(
                          icon: Icons.article_outlined,
                          iconBgColor: Colors.purple.shade50,
                          iconColor: Colors.purple.shade600,
                          title: 'Open Source Licenses',
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: appName,
                            applicationVersion: version,
                            applicationIcon: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/final.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colors.primary,
                                            colors.primary.withBlue(
                                              (colors.primary.blue * 0.8)
                                                  .round(),
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.work_outline_rounded,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Footer ──
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Made with ❤️ for job seekers',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '© 2026 SCN Jobs. All rights reserved.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
