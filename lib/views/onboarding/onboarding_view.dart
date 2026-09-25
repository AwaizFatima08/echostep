import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/voice_engine.dart';
import '../../core/content.dart';
import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/services.dart';
import '../../widgets/characters.dart';
import '../../widgets/effects.dart';
import '../../widgets/kid_widgets.dart';
import '../../widgets/parent_widgets.dart';
import '../hub/hub_view.dart';
import '../parent/account_views.dart';

/// Two-minute setup for the grown-up (PDD Screen 1): welcome, the child's
/// nickname, age and buddy, then the microphone and cloud backup choices.
/// No account needed.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key, this.addingChild = false});

  /// True when a grown-up adds another child from the Parent Zone.
  final bool addingChild;

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _page = 0;
  String _age = '2-3';
  Buddy _buddy = Buddy.milo;
  bool _backup = true;
  PermissionStatus? _mic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _backup = Services.of(context).store.settings.cloudBackup;
      try {
        final st = await Permission.microphone.status;
        if (mounted) setState(() => _mic = st);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(page, duration: const Duration(milliseconds: 380), curve: Curves.easeInOut);
  }

  Future<void> _askMic() async {
    try {
      final st = await MicInput.request();
      if (!mounted) return;
      setState(() => _mic = st);
      if (st.isPermanentlyDenied) await openAppSettings();
    } catch (_) {}
  }

  Future<void> _finish() async {
    final s = Services.of(context);
    if (!widget.addingChild && s.store.settings.cloudBackup != _backup) {
      await s.cloud.setBackup(_backup);
    }
    s.store.addChild(nickname: _name.text, ageGroup: _age, buddy: _buddy);
    s.applySettings();
    if (!mounted) return;
    if (widget.addingChild) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const HubView()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      if (!widget.addingChild) _welcome(),
      _childPage(),
      if (!widget.addingChild) _privacyPage(),
      _readyPage(),
    ];
    final index = _page;
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    if (index > 0 || widget.addingChild)
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => index > 0 ? _go(index - 1) : Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    for (var i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == index ? 22 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: i == index ? ES.turquoise : ES.cardLine,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(controller: _pages, physics: const NeverScrollableScrollPhysics(), children: pages),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scroll(List<Widget> children) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight - 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: children),
          ),
        ),
      ),
    ),
  );

  Widget _welcome() {
    return _scroll([
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Milo(size: 140, glow: 0.4),
          Pip(size: 130, shape: MouthShape.ah),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Welcome to EchoSteps',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      const Text(
        'Playful practice that rewards every sound your child makes, from a tiny hum to a big "aaah".',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, height: 1.4),
      ),
      const SizedBox(height: 10),
      const Hint('This one-minute setup is for grown-ups.', size: 16),
      const SizedBox(height: 28),
      FilledButton(key: const ValueKey('onboarding-start'), onPressed: () => _go(1), child: const Text('Get started')),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () async {
          final restored = await Navigator.of(
            context,
          ).push<bool>(MaterialPageRoute(builder: (_) => const SignInView(restoring: true)));
          if (restored == true && mounted && Services.of(context).store.isSetUp) {
            Services.of(context).applySettings();
            Navigator.of(context).pushAndRemoveUntil(fadeRoute(const HubView()), (_) => false);
          }
        },
        child: const Text('I already have an account: restore progress'),
      ),
    ]);
  }

  Widget _childPage() {
    return _scroll([
      const Text(
        'What should we call our superstar?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('nickname'),
        controller: _name,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(hintText: 'Nickname', counterText: ''),
      ),
      const SizedBox(height: 6),
      const Hint('Optional. A nickname is best; please don\'t use a full name.'),
      const SizedBox(height: 22),
      const Text('Age', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          for (final a in ageGroups) Pill(label: a, selected: _age == a, onTap: () => setState(() => _age = a)),
        ],
      ),
      const SizedBox(height: 24),
      const Text('Choose a buddy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      // Two 136dp buddy cards need 304dp; scale them down on narrow phones (e.g. 360dp with
      // Samsung's display zoom) instead of overflowing.
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final b in Buddy.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: BouncyButton(
                  label: b.displayName,
                  onTap: () => setState(() => _buddy = b),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 136,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ES.card,
                      borderRadius: BorderRadius.circular(ES.radius),
                      border: Border.all(color: _buddy == b ? ES.sunshine : ES.cardLine, width: _buddy == b ? 4 : 2),
                    ),
                    child: Column(
                      children: [
                        BuddyFace(pip: b == Buddy.pip, size: 96),
                        Text(b.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      FilledButton(key: const ValueKey('onboarding-next'), onPressed: () => _go(_page + 1), child: const Text('Next')),
    ]);
  }

  Widget _privacyPage() {
    final s = Services.of(context);
    final granted = _mic?.isGranted ?? false;
    return _scroll([
      const Text(
        'Sound and privacy',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Microphone', icon: Icons.mic_rounded),
            const Text(
              'EchoSteps listens for your child\'s sounds while they play. Sound is analysed on this device in real time '
              'and is never recorded, saved or uploaded.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (VoiceEngine.synthVoice || granted)
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: ES.mint),
                  SizedBox(width: 8),
                  Text('Microphone is on', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              )
            else
              FilledButton.icon(
                key: const ValueKey('allow-mic'),
                onPressed: _askMic,
                icon: const Icon(Icons.mic_rounded),
                label: Text(_mic?.isPermanentlyDenied == true ? 'Open settings' : 'Allow microphone'),
              ),
            if (_mic != null && !granted && !VoiceEngine.synthVoice) ...[
              const SizedBox(height: 8),
              const Hint('Without the microphone, the games still respond to touch.'),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Cloud backup',
              icon: Icons.cloud_rounded,
              trailing: Switch(
                key: const ValueKey('backup-switch'),
                value: _backup && s.cloud.available,
                onChanged: s.cloud.available ? (v) => setState(() => _backup = v) : null,
              ),
            ),
            const Text(
              'Keeps progress safe if this device is lost or replaced. Stored with Google Firebase: the nickname, age group, '
              'settings and practice numbers. Never audio. You can turn this off or delete it at any time in the Parent Zone.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 6),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => openLink(context, Links.privacy),
              child: const Text('Read the privacy policy'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(key: const ValueKey('privacy-next'), onPressed: () => _go(_page + 1), child: const Text('Next')),
    ]);
  }

  Widget _readyPage() {
    final name = _name.text.trim().isEmpty ? 'our superstar' : _name.text.trim();
    return _scroll([
      Bob(child: BuddyFace(pip: _buddy == Buddy.pip, size: 180)),
      const SizedBox(height: 14),
      Text(
        'All set for $name!',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      const Hint(
        'Tip: sit with your child, make sounds together and celebrate every try. The lock at the top of the '
        'main screen leads to the Parent Zone.',
        size: 16,
      ),
      const SizedBox(height: 30),
      Pulse(
        child: BouncyButton(
          label: 'Start playing',
          onTap: _finish,
          child: Container(
            key: const ValueKey('start-playing'),
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 22),
            decoration: BoxDecoration(
              color: ES.coral,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [BoxShadow(color: ES.coral.withValues(alpha: 0.5), blurRadius: 24)],
            ),
            child: Text(
              widget.addingChild ? 'Add child' : 'Start Playing',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ES.canvasDeep),
            ),
          ),
        ),
      ),
    ]);
  }
}
