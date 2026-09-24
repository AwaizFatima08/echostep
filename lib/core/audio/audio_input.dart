import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'dsp.dart';
import 'synth_voice.dart';

/// Where voice samples come from: the real microphone, or a synthetic voice
/// for tests, the emulator and store screenshots.
abstract class AudioInput {
  /// Starts capture; emits mono float samples at [kSampleRate].
  Future<Stream<Float32List>> start();
  Future<void> stop();
}

class MicInput implements AudioInput {
  final _rec = AudioRecorder();

  static Future<bool> granted() async {
    try {
      return (await Permission.microphone.status).isGranted;
    } catch (_) {
      return false; // no platform (tests) or plugin unavailable
    }
  }

  /// Asks for the microphone. Returns the resulting status so the parent
  /// screen can offer "Open settings" when it's permanently denied.
  static Future<PermissionStatus> request() => Permission.microphone.request();

  @override
  Future<Stream<Float32List>> start() async {
    final bytes = await _rec.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: kSampleRate,
        numChannels: 1,
        // The app talks to the child through the speaker; cancel that echo so
        // its own prompts never count as the child's voice.
        echoCancel: true,
        autoGain: false,
        noiseSuppress: false,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
          // Bluetooth SCO needs BLUETOOTH_CONNECT, which we don't ask for.
          manageBluetooth: false,
        ),
      ),
    );
    return bytes.map(pcm16ToFloat);
  }

  @override
  Future<void> stop() async {
    if (await _rec.isRecording()) await _rec.stop();
  }
}

/// Plays a scripted synthetic voice in real time. Drives the whole app on
/// devices with no microphone (the emulator, tests, store screenshots).
class SynthInput implements AudioInput {
  SynthInput({this.script});

  /// Pieces to loop through; defaults to a varied demo performance.
  final List<Float32List>? script;
  Timer? _timer;
  StreamController<Float32List>? _ctrl;

  /// A varied demo "child": hums, vowels, babble and pauses.
  static List<Float32List> demoScript() {
    final s = SynthVoice(seed: 3);
    return [
      s.silence(1.2),
      s.childVowel(Vowel.ah, seconds: 1.6, f0: 300, amp: 0.25),
      s.silence(0.9),
      s.babble(count: 3, f0: 320, amp: 0.3),
      s.silence(1.4),
      s.vowel(seconds: 2.0, f0: 240, f0End: 460, f1: 700, f2: 1200, amp: 0.12),
      s.silence(0.8),
      s.hum(seconds: 1.4, f0: 270, amp: 0.2),
      s.silence(0.6),
      s.childVowel(Vowel.ee, seconds: 1.2, f0: 380, amp: 0.05),
      s.silence(2.0),
    ];
  }

  /// A child practising one Echo Safari target, with breaths between.
  static List<Float32List> targetScript(String targetId) {
    final s = SynthVoice(seed: 5);
    Float32List piece() => switch (targetId) {
      'mmm' => s.hum(seconds: 2.0, f0: 280, amp: 0.25),
      'ba' || 'ma' || 'da' => s.babble(count: 4, f0: 300, amp: 0.3),
      _ => s.childVowel(
        Vowel.values.firstWhere((v) => v.name == targetId, orElse: () => Vowel.ah),
        seconds: 2.0,
        f0: 300,
        amp: 0.3,
      ),
    };
    return [s.silence(0.6), piece(), s.silence(0.5), piece(), s.silence(0.5)];
  }

  @override
  Future<Stream<Float32List>> start() async {
    final pieces = script ?? demoScript();
    final all = SynthVoice.concat(pieces);
    var pos = 0;
    const chunk = 512;
    _ctrl = StreamController<Float32List>();
    _timer = Timer.periodic(const Duration(milliseconds: 32), (_) {
      final out = Float32List(chunk);
      for (var i = 0; i < chunk; i++) {
        out[i] = all[pos];
        pos = (pos + 1) % all.length;
      }
      _ctrl?.add(out);
    });
    return _ctrl!.stream;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    // Don't wait for the done event: the engine cancels its subscription
    // right after, and a pending close must never delay the next screen's mic.
    unawaited(_ctrl?.close());
    _ctrl = null;
  }
}

/// Eases [current] toward [target] at [rate] per second, frame-rate independent.
double smoothTo(double current, double target, double rate, double dt) =>
    target + (current - target) * math.exp(-rate * dt);
