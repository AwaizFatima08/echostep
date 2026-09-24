import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Grown-ups-only check before the Parent Zone or anything that leaves the
/// child's world (Google Play Families Policy).
///
/// A multiplication question with three big answers: easy for an adult, out
/// of reach for a toddler. A wrong answer quietly asks another question; no
/// lockout to frustrate a parent. (A 3-second hold, as the PDD suggested, is
/// something toddlers do by accident.)
Future<bool> showParentGate(BuildContext context, {math.Random? random}) async {
  final ok = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => ParentGate(random: random),
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ),
  );
  return ok ?? false;
}

class ParentGate extends StatefulWidget {
  const ParentGate({super.key, this.random});
  final math.Random? random;

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate> {
  late final math.Random _rand = widget.random ?? math.Random();
  late int _a, _b;
  late List<int> _choices;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    _a = 3 + _rand.nextInt(7);
    _b = 3 + _rand.nextInt(7);
    final answer = _a * _b;
    final set = <int>{answer};
    while (set.length < 3) {
      final d = (_rand.nextInt(4) + 1) * (_rand.nextBool() ? 1 : -1) * (_rand.nextBool() ? 1 : _a);
      if (answer + d > 0) set.add(answer + d);
    }
    _choices = set.toList()..shuffle(_rand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 26),
          decoration: BoxDecoration(
            color: ES.card,
            borderRadius: BorderRadius.circular(ES.radius),
            border: Border.all(color: ES.cardLine, width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_rounded, color: ES.lilac),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('For grown-ups', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('What is $_a × $_b?', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  _wrong ? 'Not quite. Here is another one.' : 'Tap the right answer to continue.',
                  style: TextStyle(color: _wrong ? ES.sunshine : ES.muted, fontSize: 15),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final c in _choices)
                      SizedBox(
                        width: 100,
                        height: 72,
                        child: OutlinedButton(
                          key: ValueKey('gate-$c'),
                          onPressed: () {
                            if (c == _a * _b) {
                              Navigator.pop(context, true);
                            } else {
                              setState(() {
                                _wrong = true;
                                _next();
                              });
                            }
                          },
                          child: Text('$c', style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Answers the gate in tests: finds the question and taps the right answer.
int gateAnswer(String question) {
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(question)!;
  return int.parse(m.group(1)!) * int.parse(m.group(2)!);
}
