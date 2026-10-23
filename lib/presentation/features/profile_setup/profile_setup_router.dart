import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/domain/entities/education.dart';
import 'package:scn_jobs/presentation/features/profile_setup/create_profile_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/education_form_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/education_list_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/experience_form_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/experience_list_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/languages_selector_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/personal_details_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/preferred_industries_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/profile_completion_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/resume_upload_screen.dart';
import 'package:scn_jobs/presentation/features/profile_setup/skills_selector_screen.dart';

/// Route list for the whole profile-setup flow, spliced into
/// `app_router.dart`'s top-level `routes` via `...profileSetupRoutes`.
///
/// The `/profile-setup/preferences/*` screens chain via `context.go`
/// in a fixed order: skills → languages → industries →
/// `/profile-setup/resume` (Day 13). Each screen only knows the next
/// one, not the whole sequence — reordering the chain later means
/// editing two `context.go` calls, not a central list.
final List<RouteBase> profileSetupRoutes = [
  GoRoute(
    path: '/profile-setup/create',
    name: 'profileSetupCreate',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const CreateProfileScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/personal-details',
    name: 'profileSetupPersonalDetails',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const PersonalDetailsScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/education',
    name: 'profileSetupEducation',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const EducationListScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/education/add',
    name: 'profileSetupEducationAdd',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const EducationFormScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/education/edit',
    name: 'profileSetupEducationEdit',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: EducationFormScreen(existing: state.extra as Education?),
    ),
  ),
  GoRoute(
    path: '/profile-setup/experience',
    name: 'profileSetupExperience',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const ExperienceListScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/experience/add',
    name: 'profileSetupExperienceAdd',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const ExperienceFormScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/preferences/skills',
    name: 'profileSetupSkills',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const SkillsSelectorScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/preferences/languages',
    name: 'profileSetupLanguages',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const LanguagesSelectorScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/preferences/industries',
    name: 'profileSetupIndustries',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const PreferredIndustriesScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/resume',
    name: 'profileSetupResume',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const ResumeUploadScreen(),
    ),
  ),
  GoRoute(
    path: '/profile-setup/complete',
    name: 'profileSetupComplete',
    pageBuilder: (context, state) => _buildPage(
      state: state,
      child: const ProfileCompletionScreen(),
      transition: _PageTransition.fadeScale,
    ),
  ),
];

/// ─────────────────────────────────────────────
/// Page transition types
/// ─────────────────────────────────────────────
enum _PageTransition {
  slideRight,
  fadeScale,
}

/// Builds a [CustomTransitionPage] with smooth animations.
///
/// [slideRight] — Standard iOS/Android push from right (default).
/// [fadeScale] — Fade + slight scale up (used for completion/success).
CustomTransitionPage<void> _buildPage({
  required GoRouterState state,
  required Widget child,
  _PageTransition transition = _PageTransition.slideRight,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (transition) {
        case _PageTransition.fadeScale:
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );

        case _PageTransition.slideRight:
          final tween = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));

          final fadeTween = Tween<double>(
            begin: 0,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeOut));

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
      }
    },
  );
}
