import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scn_jobs/presentation/providers/health/health_providers.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = false;
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _checking = true);
    await ref.read(backendHealthyProvider.notifier).checkNow();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          /// Background ambient glow
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: MediaQuery.of(context).size.width * 0.5 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF667eea).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),

                  /// Animated illustration
                  Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          /// Outer glow
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF667eea).withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),

                          /// Inner glow
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF764ba2).withOpacity(0.15),
                                  Colors.transparent,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),

                          /// Main icon container
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF667eea).withOpacity(0.2),
                                  const Color(0xFF764ba2).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Icon(
                              Icons.cloud_off_rounded,
                              size: 48,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),

                          /// Animated pulse ring
                          AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.05),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  /// Title
                  Text(
                    "We'll be back soon",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Subtitle
                  Text(
                    "We're having trouble connecting to our servers. Please check your internet connection or try again in a few minutes.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.4),
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 48),

                  /// Retry button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        shadowColor: const Color(0xFF667eea).withOpacity(0.4),
                      ),
                      child: _checking
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
                          Icon(Icons.refresh_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Try Again',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Secondary action
                  TextButton(
                    onPressed: () {
                      // Could open help/support or show more info
                    },
                    child: Text(
                      'Contact Support',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),

                  const Spacer(),

                  /// Bottom status
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red.shade400.withOpacity(0.8),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.shade400.withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Server offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}