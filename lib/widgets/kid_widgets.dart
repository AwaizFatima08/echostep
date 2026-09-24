import 'package:flutter/material.dart';

import '../core/audio/sound_player.dart';
import '../core/theme.dart';
import '../services/services.dart';

/// Squishy tap target: shrinks while pressed, springs back, plays a soft
/// pop. No double-tap or long-press needed.
class BouncyButton extends StatefulWidget {
  const BouncyButton({super.key, required this.child, required this.onTap, required this.label, this.sound = true});

  final Widget child;
  final VoidCallback? onTap;

  /// Read by TalkBack.
  final String label;
  final bool sound;

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.sound) Services.of(context).sound.sfx(Sfx.pop, volume: 0.6);
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Round chunky icon button (back, mute, lock...).
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.size = ES.kidTarget,
    this.color = ES.turquoise,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      label: label,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ES.card,
          border: Border.all(color: color, width: 3.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16)],
        ),
        child: Icon(icon, color: color, size: size * 0.48),
      ),
    );
  }
}

/// Back arrow in the top-left of every child screen.
class KidBackButton extends StatelessWidget {
  const KidBackButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RoundButton(
    icon: Icons.arrow_back_rounded,
    label: 'Back',
    color: ES.cream,
    size: 64,
    onTap: onTap ?? () => Navigator.of(context).maybePop(),
  );
}

/// A gently pulsing wrapper that draws the eye to the next thing to tap.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.enabled = true, this.amount = 0.05});
  final Widget child;
  final bool enabled;
  final double amount;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.enabled && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.scale(scale: 1 + widget.amount * Curves.easeInOut.transform(_c.value), child: child),
    child: widget.child,
  );
}

/// Slow up-and-down float for idle characters.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.distance = 8, this.seconds = 2.6});
  final Widget child;
  final double distance;
  final double seconds;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.seconds * 1000).round()),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) =>
        Transform.translate(offset: Offset(0, -widget.distance * Curves.easeInOut.transform(_c.value)), child: child),
    child: widget.child,
  );
}

/// Fade page transition (no sliding: calmer for sensitive children).
Route<T> fadeRoute<T>(Widget page, {RouteSettings? settings}) => PageRouteBuilder<T>(
  settings: settings,
  transitionDuration: const Duration(milliseconds: 350),
  reverseTransitionDuration: const Duration(milliseconds: 250),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, c) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    child: c,
  ),
);
