import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _page = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const _slides = [
    _SlideData(
      gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
      icon: Icons.location_on_rounded,
      title: 'Find Jobs Near You',
      body:
      'Discover thousands of local opportunities tailored to your skills and location.',
    ),
    _SlideData(
      gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
      icon: Icons.badge_rounded,
      title: 'Build Your Profile',
      body:
      'Create your profile once and apply to multiple jobs with a single tap.',
    ),
    _SlideData(
      gradient: [Color(0xFF4facfe), Color(0xFF00f2fe)],
      icon: Icons.rocket_launch_rounded,
      title: 'Get Hired Faster',
      body:
      'Connect directly with recruiters and land your dream job in no time.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          /// Background decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _slides[_page].gradient[0].withOpacity(0.1),
                    _slides[_page].gradient[1].withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _slides[_page].gradient[1].withOpacity(0.08),
                    _slides[_page].gradient[0].withOpacity(0.03),
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                /// Skip button
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 20, 0),
                    child: TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                /// Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            /// Animated illustration
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: slide.gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(40),
                                  boxShadow: [
                                    BoxShadow(
                                      color: slide.gradient[0].withOpacity(0.3),
                                      blurRadius: 40,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  slide.icon,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const SizedBox(height: 48),

                            /// Title
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.3),
                                      end: Offset.zero,
                                    ).animate(_animationController),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                slide.title,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(height: 16),

                            /// Body
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(0.2, 1),
                                    )),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                slide.body,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                /// Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Column(
                    children: [
                      /// Page indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                              (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _page ? 28 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              gradient: i == _page
                                  ? LinearGradient(
                                colors: _slides[_page].gradient,
                              )
                                  : null,
                              color: i == _page ? null : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      /// Buttons
                      Row(
                        children: [
                          /// Log in
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.go('/login'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Log in',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          /// Next / Register
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _slides[_page].gradient,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _slides[_page].gradient[0]
                                        .withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  if (isLast) {
                                    context.go('/register');
                                  } else {
                                    _pageController.nextPage(
                                      duration:
                                      const Duration(milliseconds: 400),
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isLast ? 'Get Started' : 'Next',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedSwitcher(
                                      duration:
                                      const Duration(milliseconds: 200),
                                      child: Icon(
                                        isLast
                                            ? Icons.arrow_forward_rounded
                                            : Icons.arrow_forward_ios_rounded,
                                        key: ValueKey(isLast),
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.body,
  });

  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String body;
}
