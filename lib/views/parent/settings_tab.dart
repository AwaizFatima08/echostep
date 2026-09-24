import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/services.dart';
import '../../widgets/parent_widgets.dart';
import 'sound_check_view.dart';

/// Per-child play settings and device sound settings.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.child});
  final ChildProfile child;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  ChildProfile get c => widget.child;

  void _changed() {
    final s = Services.of(context);
    s.store.childUpdated(c);
    s.applySettings();
    setState(() {});
  }

  void _deviceChanged() {
    final s = Services.of(context);
    s.store.save();
    s.applySettings();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final st = c.settings;
    final dev = s.store.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('Echo Safari level for ${c.displayName}', icon: Icons.flag_rounded),
              Wrap(
                spacing: 10,
                children: [
                  Pill(
                    label: 'Explore',
                    selected: st.level == PlayLevel.explore,
                    onTap: () {
                      st.level = PlayLevel.explore;
                      _changed();
                    },
                  ),
                  Pill(
                    label: 'Practise',
                    selected: st.level == PlayLevel.practise,
                    onTap: () {
                      st.level = PlayLevel.practise;
                      _changed();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Hint(
                st.level == PlayLevel.explore
                    ? 'Explore: any sound grows the flower. Best for children who are just starting to vocalize.'
                    : 'Practise: the target sound grows the flower three times faster; other sounds still help, so no try is wasted.',
              ),
              const SizedBox(height: 12),
              const Text('Age group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final a in ageGroups)
                    ChoiceChip(
                      label: Text(a),
                      selected: c.ageGroup == a,
                      onSelected: (_) {
                        c.ageGroup = a;
                        _changed();
                      },
                    ),
                ],
              ),
              Hint(
                'Sets how long a sound is held (${c.holdSeconds} s) or how many syllables (${c.syllablesNeeded}) grow a flower.',
                size: 13,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Microphone', icon: Icons.mic_rounded),
              Row(
                children: [
                  const Text('Less', style: TextStyle(color: ES.muted)),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('sensitivity'),
                      value: st.sensitivity,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      label: st.sensitivity.toStringAsFixed(2),
                      onChanged: (v) => setState(() => st.sensitivity = v),
                      onChangeEnd: (_) => _changed(),
                    ),
                  ),
                  const Text('More', style: TextStyle(color: ES.muted)),
                ],
              ),
              const Hint(
                'Raise it for a very quiet child; lower it if background noise sets things off. '
                'EchoSteps also adapts to room noise by itself.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SoundCheckView(child: c))),
                icon: const Icon(Icons.graphic_eq_rounded),
                label: const Text('Test the microphone'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Comfort', icon: Icons.spa_rounded),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Calm mode'),
                subtitle: const Text('Fewer bubbles, no stars, gentler motion.'),
                value: st.calmMode,
                onChanged: (v) {
                  st.calmMode = v;
                  _changed();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Spoken encouragement'),
                subtitle: const Text('Greetings and praise. Echo Safari always says the target sound.'),
                value: st.promptsOn,
                onChanged: (v) {
                  st.promptsOn = v;
                  _changed();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All picture cards'),
                subtitle: const Text('Show every card now instead of unlocking them in Echo Safari.'),
                value: st.unlockAllCards,
                onChanged: (v) {
                  st.unlockAllCards = v;
                  _changed();
                },
              ),
              const SizedBox(height: 6),
              const Text('Daily play time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in const [0, 10, 15, 20, 30])
                    ChoiceChip(
                      label: Text(m == 0 ? 'No limit' : '$m min'),
                      selected: st.dailyMinutes == m,
                      onSelected: (_) {
                        st.dailyMinutes = m;
                        _changed();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(right: 10, bottom: 6),
                child: Hint(
                  'When time is up, Milo says goodnight. Picture cards stay available: communication is never limited.',
                  size: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('This device', icon: Icons.phone_android_rounded),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sound effects'),
                value: dev.sfxOn,
                onChanged: (v) {
                  dev.sfxOn = v;
                  _deviceChanged();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Soft background music'),
                subtitle: const Text('Only on screens that don\'t listen.'),
                value: dev.musicOn,
                onChanged: (v) {
                  dev.musicOn = v;
                  _deviceChanged();
                },
              ),
              const SizedBox(height: 4),
              const Text('Speaking speed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Row(
                children: [
                  const Text('Slow', style: TextStyle(color: ES.muted)),
                  Expanded(
                    child: Slider(
                      value: dev.speechRate,
                      min: 0.2,
                      max: 0.6,
                      divisions: 4,
                      onChanged: (v) => setState(() => dev.speechRate = v),
                      onChangeEnd: (_) {
                        _deviceChanged();
                        s.speech.say('Hi ${c.displayName}! Let\'s play!');
                      },
                    ),
                  ),
                  const Text('Normal', style: TextStyle(color: ES.muted)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
