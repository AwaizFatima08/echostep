import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/services.dart';
import '../widgets/characters.dart';
import '../widgets/effects.dart';
import '../widgets/kid_widgets.dart';
import 'hub/hub_view.dart';
import 'onboarding/onboarding_view.dart';

/// Milo wakes up, the title fades in, then the app continues to setup or to
/// the hub.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _next = Timer(const Duration(milliseconds: 2100), _go);
  }

  void _go() {
    if (!mounted) return;
    final s = Services.of(context);
    final next = s.store.isSetUp ? const HubView() : const OnboardingView();
    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  @override
  void dispose() {
    _next?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _next?.cancel();
            _go();
          },
          child: Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                final wake = Curves.easeInOut.transform(((t - 0.25) / 0.4).clamp(0.0, 1.0));
                final text = Curves.easeOut.transform(((t - 0.45) / 0.5).clamp(0.0, 1.0));
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Milo(size: 200, awake: wake, glow: wake * 0.7, mouth: wake > 0.9 ? 0.3 : 0),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: text,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - text)),
                        child: const Column(
                          children: [
                            Text(
                              'EchoSteps',
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                color: ES.cream,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('Speech & Imitation Lab', style: TextStyle(fontSize: 18, color: ES.turquoise)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
