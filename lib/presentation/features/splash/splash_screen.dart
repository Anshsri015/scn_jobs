import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:scn_jobs/core/network/dio_provider.dart'
    show secureStorageServiceProvider;
import 'package:scn_jobs/core/theme/app_theme.dart';
import 'package:scn_jobs/data/repositories/auth_repository_impl.dart'
    show SessionCheckException;
import 'package:scn_jobs/presentation/providers/auth/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // WHY: the dev API cold-starts on Render's free tier and can
  // legitimately take up to ~25s to respond after being asleep. That
  // long a spinner with zero feedback reads as "the app is frozen" to
  // most people, so after a few seconds we surface a reassuring hint
  // instead of leaving them guessing.
  bool _showSlowHint = false;
  Timer? _slowHintTimer;

  // WHY: a `SessionCheckException` means we have a saved session but
  // couldn't reach the (cold-starting) server to confirm it. Instead
  // of dumping a Retry button on the user, we keep the spinner up and
  // silently retry a few times ourselves — most of the time the
  // server just needed a bit longer to wake up. Only after several
  // failed attempts do we give up and fall back to onboarding.
  int _sessionCheckRetries = 0;
  static const int _maxSessionCheckRetries = 4;
  Timer? _retryTimer;
  bool _retryScheduled = false;

  // WHY: previously the splash screen always waited for `/auth/me` to
  // resolve before navigating anywhere — even for someone who was
  // already logged in a minute ago, was on the exact same session,
  // and just reopened the app. That meant every app open paid the
  // full network round-trip (and the ~25s cold-start on a bad day)
  // before reaching Home. A saved token in secure storage is a fast,
  // purely local check, so if one exists we navigate to /home right
  // away and let the `/auth/me` confirmation above keep running in
  // the background — `authStateProvider`'s own success/error handling
  // (below) still corrects course afterwards if that saved session
  // actually turns out to be dead.
  bool _optimisticNavDone = false;

  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _shimmerSlide;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 12000),
      vsync: this,
    )..repeat();

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoRotate = Tween<double>(begin: -0.2, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _shimmerSlide = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );

    _mainController.forward();

    _slowHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showSlowHint = true);
    });

    _maybeNavigateOptimistically();
  }

  Future<void> _maybeNavigateOptimistically() async {
    final hasSession =
    await ref.read(secureStorageServiceProvider).hasSession;
    if (!mounted || _optimisticNavDone) return;
    if (hasSession) {
      _optimisticNavDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/home');
      });
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _slowHintTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(authStateProvider);

    userState.whenData((user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(user != null ? '/home' : '/onboarding');
      });
    });

    userState.whenOrNull(
      error: (error, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          // A `SessionCheckException` means we have a saved session
          // but couldn't reach the server to confirm it — that's a
          // connectivity problem, not "logged out". We retry
          // automatically instead of bouncing a genuinely logged-in
          // user into onboarding or making them tap a button.
          // Anything else (malformed response, etc.) falls back to
          // the old behaviour, since it isn't a case we can safely
          // distinguish from "not logged in".
          if (error is SessionCheckException) {
            if (_sessionCheckRetries < _maxSessionCheckRetries) {
              if (_retryScheduled) return;
              _retryScheduled = true;
              _sessionCheckRetries++;
              _retryTimer = Timer(const Duration(seconds: 4), () {
                if (!mounted) return;
                _retryScheduled = false;
                ref.invalidate(authStateProvider);
              });
            } else {
              context.go('/onboarding');
            }
          } else {
            context.go('/onboarding');
          }
        });
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          /// Animated background orbs
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _rotateController,
              builder: (context, child) {
                final offset = (i * 2.094) + (_rotateController.value * 6.283);
                return Positioned(
                  left: MediaQuery.of(context).size.width * 0.5 +
                      (i == 0 ? 120 : i == 1 ? -100 : 80) *
                          (0.5 + 0.5 * (offset % 3.14)),
                  top: MediaQuery.of(context).size.height * 0.3 +
                      (i == 0 ? -80 : i == 1 ? 100 : -40) *
                          (0.5 + 0.5 * ((offset + 1) % 3.14)),
                  child: Container(
                    width: [300, 250, 200][i].toDouble(),
                    height: [300, 250, 200][i].toDouble(),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          [
                            const Color(0xFF667eea),
                            const Color(0xFFf093fb),
                            const Color(0xFF4facfe)
                          ][i].withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),

          /// Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// Logo with shimmer + pulse
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _mainController,
                    _pulseController,
                  ]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScale.value * (0.95 + 0.05 * _pulseController.value),
                      child: Transform.rotate(
                        angle: _logoRotate.value,
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      /// Glow layers
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.navy.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.navy.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),

                      /// Main logo container
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                // The purple gradient box looked odd
                                // sitting behind the logo's own dark
                                // rounded background — dropped it so
                                // the logo shows as-is, just keeping a
                                // soft shadow so it still lifts off
                                // the dark splash background.
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              // Real logo, dropped in at
                              // assets/images/logo.jpeg (declared under
                              // `flutter: assets:` in pubspec.yaml —
                              // see the setup steps for this file).
                              // Falls back to the old placeholder icon
                              // if the asset is ever missing, instead
                              // of crashing the splash screen.
                              child: Image.asset(
                                'assets/images/logo.jpeg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(0xFF667eea),
                                            const Color(0xFF764ba2),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                      child: const Icon(
                                        Icons.work_outline_rounded,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                              ),
                            ),

                            /// Shimmer sweep
                            AnimatedBuilder(
                              animation: _shimmerSlide,
                              builder: (context, child) {
                                return Positioned.fill(
                                  child: Transform.translate(
                                    offset: Offset(
                                      _shimmerSlide.value * 140,
                                      0,
                                    ),
                                    child: Container(
                                      width: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white.withOpacity(0),
                                            Colors.white.withOpacity(0.3),
                                            Colors.white.withOpacity(0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                /// App name with gradient
                FadeTransition(
                  opacity: _fadeIn,
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [
                          Colors.white,
                          Color(0xFFa5b4fc),
                        ],
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'SCN Jobs',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// Tagline
                AnimatedBuilder(
                  animation: _slideUp,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideUp.value),
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'Find work near you',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                /// Premium loading indicator. Session-check failures
                /// (see the auto-retry logic above) no longer show a
                /// Retry button — we keep this spinner up and retry
                /// silently in the background instead.
                FadeTransition(
                  opacity: _fadeIn,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),

                /// Cold-start reassurance — only shown once we've
                /// been waiting a while, so a normal fast load never
                /// flashes this text.
                if (_showSlowHint) ...[
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _fadeIn,
                    child: Text(
                      'Waking up the server, almost there…',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          /// Bottom branding
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  /// Animated dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final delay = i * 0.3;
                          final value = ((_pulseController.value + delay) % 1.0);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 6 + (value * 4),
                            height: 6 + (value * 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.3 + (value * 0.4),
                              ),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Made in India 🇮🇳',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
