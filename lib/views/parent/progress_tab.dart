import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/content.dart';
import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/progress.dart';
import '../../services/report.dart';
import '../../services/services.dart';
import '../../widgets/growth_tree.dart';
import '../../widgets/parent_widgets.dart';

/// PDD §5: the Vocal Growth Tree, weekly activity, the phoneme spectrum,
/// totals and the therapist report.
class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key, required this.child});
  final ChildProfile child;

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  bool _sharing = false;

  ChildProfile get c => widget.child;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await Report.share(c);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Couldn\'t create the report. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Progress(c);
    final tree = TreeStats.of(c);
    final week = p.daily(7);
    final todayMin = week.last.playMinutes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle('${c.displayName}\'s Vocal Growth Tree', icon: Icons.park_rounded),
              AspectRatio(
                aspectRatio: 1.25,
                child: CustomPaint(painter: GrowthTreePainter(tree, seed: c.id.hashCode)),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Fact(Icons.graphic_eq_rounded, _count(c.totalVocalizations, 'vocalization'), 'roots'),
                  _Fact(Icons.timer_rounded, '${todayMin.round()} min today', 'trunk'),
                  _Fact(Icons.calendar_month_rounded, _count(tree.activeDays, 'active day'), 'branches'),
                  _Fact(Icons.local_florist_rounded, '${_count(tree.practised.length, 'sound')} practised', 'flowers'),
                  _Fact(Icons.star_rounded, '${tree.mastered.length} mastered', 'stars'),
                ],
              ),
              if (c.totalSessions == 0) ...[
                const SizedBox(height: 10),
                const Hint('The tree grows with every sound. Play Sound Spark or Echo Safari to see it sprout.'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('This week', icon: Icons.bar_chart_rounded),
              SizedBox(height: 180, child: _WeekChart(week)),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _Legend(color: ES.turquoise, label: 'Minutes of voice'),
                  _Legend(color: ES.cardLine, label: 'Minutes played'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Sounds', icon: Icons.record_voice_over_rounded),
              const Hint(
                'Tap a sound for details and to mark it mastered once you or your therapist hear it reliably.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in targets) _SoundChip(target: t, status: p.status(t), onTap: () => _soundSheet(t, p)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('All time', icon: Icons.emoji_events_rounded),
              Row(
                children: [
                  _Big(c.totalVocalizations.toString(), 'vocalizations'),
                  _Big('${(c.totalSeconds / 60).round()}', 'minutes played'),
                  _Big(
                    (c.totalVoiceSeconds / 60).toStringAsFixed(c.totalVoiceSeconds < 600 ? 1 : 0),
                    'minutes of voice',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('share-report'),
          onPressed: _sharing ? null : _share,
          icon: _sharing
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Report for therapist (PDF)'),
        ),
        const SizedBox(height: 6),
        const Center(child: Hint('A summary of the last 30 days to share by email, WhatsApp or Drive.', size: 13)),
      ],
    );
  }

  Future<void> _soundSheet(SoundTarget t, Progress p) async {
    final s = Services.of(context);
    final sum = p.targetSummaries()[t.id]!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ES.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ES.radius))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t.label,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: t.color),
                    ),
                    const SizedBox(width: 10),
                    Text(t.phoneme, style: const TextStyle(fontSize: 20, color: ES.muted)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(t.tip, style: const TextStyle(fontSize: 16, height: 1.4)),
                const SizedBox(height: 14),
                Text(
                  'Completed ${sum.completions} of ${sum.attempts} tries · ${sum.voiceSeconds.round()} s of voice',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unlocks: ${t.cards.map((id) => cardById(id)?.word ?? id).join(', ')}',
                  style: const TextStyle(color: ES.muted),
                ),
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mastered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Confirmed by you or your therapist. The app never decides this.'),
                  value: c.mastered.contains(t.id),
                  onChanged: (v) {
                    s.store.setMastered(c, t.id, v);
                    setSheet(() {});
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart(this.days);
  final List<DayActivity> days;

  @override
  Widget build(BuildContext context) {
    final maxY = math.max(5.0, days.map((d) => d.playMinutes).fold<double>(0, math.max) * 1.2);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: math.max(1, (maxY / 4).roundToDouble()),
          getDrawingHorizontalLine: (_) => const FlLine(color: ES.cardLine, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => ES.canvasDeep,
            getTooltipItem: (group, _, _, _) {
              final d = days[group.x];
              return BarTooltipItem(
                '${d.playMinutes.toStringAsFixed(1)} min played\n${d.voiceMinutes.toStringAsFixed(1)} min voice',
                const TextStyle(fontFamily: ES.font, color: ES.cream, fontSize: 13),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: math.max(1, (maxY / 4).roundToDouble()),
              getTitlesWidget: (v, meta) =>
                  Text(v.round().toString(), style: const TextStyle(color: ES.muted, fontSize: 12)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final d = days[v.toInt()].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(names[d.weekday - 1], style: const TextStyle(color: ES.muted, fontSize: 12)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].playMinutes,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  color: ES.cardLine,
                  rodStackItems: [
                    BarChartRodStackItem(0, math.min(days[i].voiceMinutes, days[i].playMinutes), ES.turquoise),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: ES.muted, fontSize: 13)),
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text, this.part);
  final IconData icon;
  final String text;
  final String part;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Shown as the tree\'s $part',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: ES.canvasDeep, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ES.mint),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    ),
  );
}

class _Big extends StatelessWidget {
  const _Big(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ES.sunshine),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: ES.muted),
        ),
      ],
    ),
  );
}

class _SoundChip extends StatelessWidget {
  const _SoundChip({required this.target, required this.status, required this.onTap});
  final SoundTarget target;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = status == 'practised' || status == 'mastered';
    return InkWell(
      key: ValueKey('sound-${target.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 88, minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? target.color.withValues(alpha: 0.9) : ES.canvasDeep,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: status == 'new' ? ES.cardLine : target.color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  target.label,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: filled ? ES.canvasDeep : ES.cream),
                ),
                if (status == 'mastered') const Icon(Icons.star_rounded, size: 18, color: ES.canvasDeep),
              ],
            ),
            Text(switch (status) {
              'mastered' => 'mastered',
              'practised' => 'practised',
              'tried' => 'tried',
              _ => 'not yet',
            }, style: TextStyle(fontSize: 12, color: filled ? ES.canvasDeep : ES.muted)),
          ],
        ),
      ),
    );
  }
}

/// "1 active day", "3 active days".
String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
