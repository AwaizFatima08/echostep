import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/content.dart';
import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/services.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';

/// "My Cards" (AAC card wall): tap a picture to hear its word. Core words
/// (more, help, all done, yes, no...) are always here; Echo Safari unlocks
/// more. Communication is never time-limited.
class CardWallView extends StatefulWidget {
  const CardWallView({super.key});

  @override
  State<CardWallView> createState() => _CardWallViewState();
}

class _CardWallViewState extends State<CardWallView> {
  late final Services _s = Services.of(context);
  AacCard? _big;
  SessionRecord? _visit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visit = _s.session.begin(_s.store.active!, 'cards');
      _s.sound.music(false);
    });
  }

  @override
  void dispose() {
    if (_visit != null) _s.session.end(_visit);
    _s.speech.hush();
    super.dispose();
  }

  void _tap(AacCard c) {
    setState(() => _big = c);
    // Words are the child's own choice to speak: always said, even with
    // coaching prompts off.
    _s.speech.say(c.word, rateOverride: 0.38);
  }

  @override
  Widget build(BuildContext context) {
    final child = _s.store.active!;
    final cards = child.availableCards;
    final hidden = aacCards.length - cards.length;
    return Scaffold(
      body: Backdrop(
        calm: child.settings.calmMode,
        top: const Color(0xFF2A2440),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                    child: Row(
                      children: const [
                        KidBackButton(),
                        SizedBox(width: 12),
                        Text(
                          'My Cards',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ES.sunshine),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final cols = math.max(3, (box.maxWidth / 150).floor());
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: cards.length + (hidden > 0 ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == cards.length) return _MoreTile(count: hidden);
                            final c = cards[i];
                            return BouncyButton(
                              key: ValueKey('card-${c.id}'),
                              label: c.word,
                              sound: false,
                              onTap: () => _tap(c),
                              child: AacCardTile(card: c),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_big != null)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _big = null),
                    child: ColoredBox(
                      color: ES.canvasDeep.withValues(alpha: 0.75),
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(_big!.id),
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutBack,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: GestureDetector(
                            onTap: () => _s.speech.say(_big!.word, rateOverride: 0.38),
                            child: SizedBox(width: 280, child: AacCardTile(card: _big!, big: true)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One picture card: picture above, word below, on a cream card.
class AacCardTile extends StatelessWidget {
  const AacCardTile({super.key, required this.card, this.big = false});
  final AacCard card;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(big ? 22 : 10),
      decoration: BoxDecoration(
        color: ES.cream,
        borderRadius: BorderRadius.circular(ES.radius),
        border: Border.all(color: card.core ? ES.turquoise : ES.sunshine, width: big ? 6 : 4),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          big
              ? Image.asset(card.asset, width: 180, height: 180)
              : Expanded(child: Image.asset(card.asset, fit: BoxFit.contain)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.word,
              style: TextStyle(fontSize: big ? 40 : 22, fontWeight: FontWeight.w700, color: ES.canvasDeep, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ES.radius),
        border: Border.all(color: ES.cardLine, width: 3),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Expanded(child: FittedBox(child: Pip(size: 90, happy: true))),
          Text(
            '+$count',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ES.turquoise),
          ),
          const Text(
            'in Echo Safari',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ES.muted),
          ),
        ],
      ),
    );
  }
}
