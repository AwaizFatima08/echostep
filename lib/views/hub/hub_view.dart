import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/content.dart';
import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/services.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/parent_gate.dart';
import '../cards/card_wall_view.dart';
import '../parent/parent_zone_view.dart';
import '../safari/safari_map_view.dart';
import '../spark/sound_spark_view.dart';

/// Main hub (PDD Screen 2): three big cards and the grown-ups' lock.
class HubView extends StatefulWidget {
  const HubView({super.key});

  @override
  State<HubView> createState() => _HubViewState();
}

class _HubViewState extends State<HubView> {
  bool _greeted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  void _greet() {
    if (!mounted || _greeted) return;
    _greeted = true;
    final s = Services.of(context);
    s.sound.music(true);
    final c = s.store.active;
    if (c != null) s.speech.prompt('Hi ${c.displayName}! Let\'s play!');
  }

  Future<void> _open(Widget page) async {
    final s = Services.of(context);
    await s.speech.hush();
    if (!mounted) return;
    await Navigator.of(context).push(fadeRoute(page));
    if (!mounted) return;
    s.sound.music(true);
    setState(() {});
  }

  Future<void> _parentZone() async {
    final s = Services.of(context);
    unawaited(s.speech.hush());
    if (!await showParentGate(context) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentZoneView()));
    if (!mounted) return;
    s.applySettings();
    // The grown-up may have removed every child or signed out.
    if (!s.store.isSetUp) return;
    setState(() {});
  }

  Future<void> _pickChild() async {
    final s = Services.of(context);
    if (s.store.children.length < 2) return;
    final picked = await showModalBottomSheet<ChildProfile>(
      context: context,
      backgroundColor: ES.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ES.radius))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (final ch in s.store.children)
                BouncyButton(
                  label: ch.displayName,
                  onTap: () => Navigator.pop(c, ch),
                  child: SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        BuddyFace(pip: ch.buddy == Buddy.pip, size: 90),
                        Text(
                          ch.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    s.store.active = picked;
    s.applySettings();
    setState(() {});
    s.speech.prompt('Hi ${picked.displayName}!');
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final c = s.store.active;
    if (c == null) {
      // Every child was removed from the Parent Zone: back to setup.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      });
      return const Scaffold();
    }
    final next = c.suggestedTarget;
    return Scaffold(
      body: Backdrop(
        calm: c.settings.calmMode,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BouncyButton(
                        label: 'Hi ${c.displayName}',
                        sound: false,
                        onTap: s.store.children.length > 1 ? _pickChild : null,
                        child: Row(
                          children: [
                            BuddyFace(pip: c.buddy == Buddy.pip, size: 64),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Hi, ${c.displayName}!',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (s.store.children.length > 1)
                              const Icon(Icons.swap_horiz_rounded, color: ES.muted, size: 28),
                          ],
                        ),
                      ),
                    ),
                    RoundButton(
                      key: const ValueKey('parent-lock'),
                      icon: Icons.lock_rounded,
                      label: 'Parent Zone (for grown-ups)',
                      size: 60,
                      color: ES.lilac,
                      onTap: _parentZone,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _HubCard(
                    key: const ValueKey('hub-spark'),
                    color: ES.coral,
                    title: 'Sound Spark',
                    subtitle: 'Make sound, see magic!',
                    art: const Milo(size: 150, awake: 0, glow: 0.25),
                    onTap: () => _open(const SoundSparkView()),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _HubCard(
                    key: const ValueKey('hub-safari'),
                    color: ES.turquoise,
                    title: 'Echo Safari',
                    subtitle: 'Help Pip say "${next.label}"!',
                    art: Pip(size: 140, shape: next.releaseMouth ?? next.mouth),
                    onTap: () => _open(const SafariMapView()),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _HubCard(
                    key: const ValueKey('hub-cards'),
                    color: ES.sunshine,
                    title: 'My Cards',
                    subtitle: 'Tap a picture to talk',
                    art: const _CardFan(),
                    onTap: () => _open(const CardWallView()),
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

class _HubCard extends StatelessWidget {
  const _HubCard({
    super.key,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.art,
    required this.onTap,
  });
  final Color color;
  final String title, subtitle;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      label: title,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ES.card,
          borderRadius: BorderRadius.circular(ES.radius + 4),
          border: Border.all(color: color, width: 4),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 18)],
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [color.withValues(alpha: 0.22), ES.card],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: FittedBox(fit: BoxFit.scaleDown, child: art),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, height: 1.2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three AAC cards fanned out, for the hub.
class _CardFan extends StatelessWidget {
  const _CardFan();

  @override
  Widget build(BuildContext context) {
    final pics = [cardById('ball')!, cardById('more')!, cardById('milk')!];
    return SizedBox(
      width: 170,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset((i - 1) * 42.0, (i - 1).abs() * 8.0),
              child: Transform.rotate(
                angle: (i - 1) * 0.22,
                child: Container(
                  width: 78,
                  height: 96,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ES.cream,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  child: Image.asset(pics[i].asset),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
