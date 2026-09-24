import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/services.dart';
import '../widgets/characters.dart';
import '../widgets/effects.dart';
import '../widgets/kid_widgets.dart';
import '../widgets/parent_gate.dart';

/// Shown when today's play time (set by the grown-up) is used up: Milo
/// falls asleep and the mic stays off. Only a grown-up can add more time.
/// The card wall stays available: communication is never time-limited.
/// Pops with true when a grown-up extended the time.
class RestView extends StatefulWidget {
  const RestView({super.key});

  @override
  State<RestView> createState() => _RestViewState();
}

class _RestViewState extends State<RestView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Services.of(context).speech.prompt('Great playing today! Milo is sleepy now. See you next time!');
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Backdrop(
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Bob(child: Milo(size: 220, awake: 0, glow: 0.3)),
                      const SizedBox(height: 16),
                      const Text(
                        'Rest time',
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: ES.lilac),
                      ),
                      const SizedBox(height: 28),
                      RoundButton(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        color: ES.turquoise,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: RoundButton(
                    icon: Icons.lock_rounded,
                    label: 'Grown-ups: 10 more minutes',
                    size: 60,
                    color: ES.lilac,
                    onTap: () async {
                      final s = Services.of(context);
                      if (await showParentGate(context) && context.mounted) {
                        s.session.extend(s.store.active!);
                        Navigator.of(context).pop(true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
