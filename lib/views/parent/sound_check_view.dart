import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/audio/audio_input.dart';
import '../../core/audio/dsp.dart';
import '../../core/audio/voice_analyzer.dart';
import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/services.dart';
import '../../widgets/parent_widgets.dart';

/// Grown-ups' microphone check: shows what EchoSteps hears, live, so a
/// parent can set the sensitivity for their child and room.
class SoundCheckView extends StatefulWidget {
  const SoundCheckView({super.key, required this.child});
  final ChildProfile child;

  @override
  State<SoundCheckView> createState() => _SoundCheckViewState();
}

class _SoundCheckViewState extends State<SoundCheckView> with SingleTickerProviderStateMixin {
  late final Services _s = Services.of(context);
  late final Ticker _ticker = createTicker((_) => _tick());
  bool? _micOn;
  VoiceFrame _f = VoiceFrame.silent;
  double _level = 0;
  int _vocal = 0, _syll = 0;
  String _heard = '–';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    _s.voice.sensitivity = widget.child.settings.sensitivity;
    final ok = await _s.voice.start(owner: this);
    if (!mounted) return;
    setState(() => _micOn = ok);
    if (ok) {
      _s.voice.drain();
      _ticker.start();
    }
  }

  void _tick() {
    final frames = _s.voice.drain();
    for (final f in frames) {
      _vocal += f.vocalizations;
      _syll += f.syllables;
      if (f.hum) {
        _heard = 'mmm (hum)';
      } else if (f.vowel != null) {
        _heard = switch (f.vowel!) {
          Vowel.ah => 'ah',
          Vowel.oh => 'oh',
          Vowel.oo => 'oo',
          Vowel.ee => 'ee',
        };
      }
    }
    if (frames.isNotEmpty) _f = frames.last;
    _level += (_f.level - _level) * 0.25;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _s.voice.stop(owner: this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _s.voice.analyzer;
    final c = widget.child;
    return Scaffold(
      appBar: AppBar(title: const Text('Microphone check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_micOn == false)
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Microphone is off', icon: Icons.mic_off_rounded),
                  const Hint('EchoSteps needs the microphone to react to sounds. Audio is never recorded or uploaded.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final st = await MicInput.request();
                      if (st.isPermanentlyDenied) await openAppSettings();
                      if (st.isGranted) _start();
                    },
                    child: const Text('Allow microphone'),
                  ),
                ],
              ),
            )
          else ...[
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Loudness', icon: Icons.graphic_eq_rounded),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: _level.clamp(0.0, 1.0),
                      minHeight: 26,
                      backgroundColor: ES.canvasDeep,
                      color: _f.voiced ? ES.turquoise : ES.cardLine,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _f.voiced ? 'Hearing a sound' : 'Quiet (below the noise gate)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _f.voiced ? ES.mint : ES.muted),
                  ),
                  const SizedBox(height: 4),
                  Hint(
                    'Room noise ${dbfs(a.noise.rmsLevel).toStringAsFixed(0)} dBFS · gate ${dbfs(a.gateRms).toStringAsFixed(0)} dBFS'
                    ' · now ${_f.db.toStringAsFixed(0)} dBFS',
                    size: 13,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('What EchoSteps hears', icon: Icons.hearing_rounded),
                  _row('Pitch', _f.pitched ? '${_f.pitchHz.round()} Hz' : '–'),
                  _row('Sounds like', _heard),
                  _row('Vocalizations', '$_vocal'),
                  _row('Syllables', '$_syll'),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => setState(() {
                      _vocal = 0;
                      _syll = 0;
                      _heard = '–';
                    }),
                    child: const Text('Reset counts'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle('Sensitivity for ${c.displayName}', icon: Icons.tune_rounded),
                  Slider(
                    value: c.settings.sensitivity,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: c.settings.sensitivity.toStringAsFixed(2),
                    onChanged: (v) {
                      setState(() => c.settings.sensitivity = v);
                      _s.voice.sensitivity = v;
                    },
                    onChangeEnd: (_) => _s.store.childUpdated(c),
                  ),
                  const Hint(
                    'Try: stay quiet (the bar should stay empty), then have your child hum or say "aaah" '
                    '(it should light up). Adjust until quiet sounds register but the room doesn\'t.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(k, style: const TextStyle(fontSize: 16, color: ES.muted)),
        ),
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
