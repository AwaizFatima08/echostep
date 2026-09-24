import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/content.dart';
import '../models/child.dart';
import 'progress.dart';

/// The one-page (or two) SLP report: a clean summary a parent can show a
/// speech therapist (PDD §5.4). It reports practice, not diagnosis.
class Report {
  static const _ink = PdfColor.fromInt(0xFF1A1A2E);
  static const _muted = PdfColor.fromInt(0xFF5E5E78);
  static const _teal = PdfColor.fromInt(0xFF2FA89F);
  static const _coral = PdfColor.fromInt(0xFFFF6B6B);
  static const _line = PdfColor.fromInt(0xFFDADAE6);

  static String _date(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';

  static String _mins(double m) => m < 1 && m > 0 ? '<1' : m.round().toString();

  static String _mode(String m) => switch (m) {
    'spark' => 'Sound Spark',
    'safari' => 'Echo Safari',
    _ => 'My Cards',
  };

  static String _status(String s) => switch (s) {
    'mastered' => 'Mastered*',
    'practised' => 'Practised',
    'tried' => 'Tried',
    _ => 'Not yet',
  };

  /// Builds the PDF. Fonts are passed in so tests can build it without the
  /// asset bundle.
  static Future<Uint8List> build(
    ChildProfile c, {
    int days = 30,
    DateTime? now,
    pw.Font? regular,
    pw.Font? bold,
  }) async {
    final p = Progress(c, now: now);
    final daily = p.daily(days);
    final recent = p.recent(days).toList();
    final sums = p.targetSummaries(days: days);
    final playMin = daily.fold<double>(0, (s, d) => s + d.playMinutes);
    final voiceMin = daily.fold<double>(0, (s, d) => s + d.voiceMinutes);
    final vocal = daily.fold<int>(0, (s, d) => s + d.vocalizations);
    final attempts = sums.values.fold<int>(0, (s, t) => s + t.attempts);
    final completions = sums.values.fold<int>(0, (s, t) => s + t.completions);
    final generated = p.now;

    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(title: 'EchoSteps report: ${c.displayName}', author: 'EchoSteps', theme: theme);

    pw.Widget stat(String label, String value) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _ink),
            ),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      ),
    );

    final maxMin = math.max(1.0, daily.map((d) => d.playMinutes).fold<double>(0, math.max));
    final chart = pw.Container(
      height: 90,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (final d in daily)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      height: 70 * (d.playMinutes - d.voiceMinutes).clamp(0, maxMin) / maxMin,
                      color: PdfColors.grey300,
                    ),
                    pw.Container(height: 70 * d.voiceMinutes.clamp(0, maxMin) / maxMin, color: _teal),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      d.day.day == 1 || d == daily.first || d == daily.last ? '${d.day.day}/${d.day.month}' : '',
                      style: const pw.TextStyle(fontSize: 6, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    pw.Widget cell(String t, {bool head = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        t,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: head ? pw.FontWeight.bold : null, color: head ? _ink : null),
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('EchoSteps practice report', style: const pw.TextStyle(fontSize: 7, color: _muted)),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ],
        ),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'EchoSteps practice report',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${c.displayName} · age group ${c.ageGroup}',
                      style: const pw.TextStyle(fontSize: 12, color: _ink),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Last $days days',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _teal),
                  ),
                  pw.Text(
                    '${_date(daily.first.day)} – ${_date(daily.last.day)}',
                    style: const pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                  pw.Text('Generated ${_date(generated)}', style: const pw.TextStyle(fontSize: 8, color: _muted)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1FAF9)),
            child: pw.Text(
              'This is a summary of home practice in the EchoSteps app, not a clinical assessment. Sound detection is '
              'automatic and approximate (tuned for children\'s voices; results vary with the device and room). '
              'Sounds marked "Mastered*" were confirmed by a parent or therapist, not by the app.',
              style: const pw.TextStyle(fontSize: 8.5, color: _ink),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              stat('days active', '${p.activeDays(days)}'),
              stat('minutes played', _mins(playMin)),
              stat('minutes of voice', _mins(voiceMin)),
              stat('vocalizations', '$vocal'),
              stat('Echo Safari completions / tries', '$completions / $attempts'),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Daily activity (grey: minutes played, teal: minutes of voice)',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          pw.SizedBox(height: 6),
          chart,
          pw.SizedBox(height: 14),
          pw.Text(
            'Sounds',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: _line, width: 0.5)),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(0.9),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1.4),
              5: pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F4F8)),
                children: [
                  cell('Sound', head: true),
                  cell('Target', head: true),
                  cell('Status', head: true),
                  cell('Completed / tries ($days d)', head: true),
                  cell('Voice time ($days d)', head: true),
                  cell('All-time completions', head: true),
                ],
              ),
              for (final t in targets)
                pw.TableRow(
                  children: [
                    cell(t.label),
                    cell(t.phoneme),
                    cell(_status(p.status(t))),
                    cell('${sums[t.id]!.completions} / ${sums[t.id]!.attempts}'),
                    cell('${sums[t.id]!.voiceSeconds.round()} s'),
                    cell('${c.practised[t.id] ?? 0}'),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'How targets are counted: vowels (ah, oo, ee, oh) and the hum (mmm) grow a flower while the sound is held '
            '(${c.holdSeconds} s of voice for this age group); ba, ma and da count repeated syllables '
            '(${c.syllablesNeeded} for this age group). Level: ${c.settings.level == PlayLevel.explore ? 'Explore (any sound counts)' : 'Practise (the target sound counts three times more)'}.',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Recent sessions',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          pw.SizedBox(height: 4),
          if (recent.isEmpty)
            pw.Text('No sessions in this period.', style: const pw.TextStyle(fontSize: 9, color: _muted))
          else
            pw.Table(
              border: pw.TableBorder(horizontalInside: const pw.BorderSide(color: _line, width: 0.5)),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F4F8)),
                  children: [
                    cell('Date', head: true),
                    cell('Activity', head: true),
                    cell('Sound', head: true),
                    cell('Minutes', head: true, align: pw.TextAlign.right),
                    cell('Vocalizations', head: true, align: pw.TextAlign.right),
                    cell('Voice (s)', head: true, align: pw.TextAlign.right),
                    cell('Avg level', head: true, align: pw.TextAlign.right),
                  ],
                ),
                for (final s in recent.reversed.take(20))
                  pw.TableRow(
                    children: [
                      cell(_date(s.start)),
                      cell(_mode(s.mode)),
                      cell(s.target == null ? '–' : (targetById(s.target!)?.label ?? s.target!)),
                      cell((s.durationSeconds / 60).toStringAsFixed(1), align: pw.TextAlign.right),
                      cell('${s.vocalizations}', align: pw.TextAlign.right),
                      cell(s.voiceSeconds.toStringAsFixed(0), align: pw.TextAlign.right),
                      cell(s.avgDb <= -119 ? '–' : '${s.avgDb.toStringAsFixed(0)} dBFS', align: pw.TextAlign.right),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            'All time: ${c.totalSessions} sessions, ${_mins(c.totalSeconds / 60)} minutes, '
            '${c.totalVocalizations} vocalizations.',
            style: const pw.TextStyle(fontSize: 9, color: _ink),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Therapist notes',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _coral),
          ),
          for (var i = 0; i < 4; i++)
            pw.Container(margin: const pw.EdgeInsets.only(top: 18), height: 0.5, color: _line),
        ],
      ),
    );
    return doc.save();
  }

  /// Builds the report with the app's fonts and opens the share sheet.
  static Future<void> share(ChildProfile c, {int days = 30}) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Andika-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Andika-Bold.ttf'));
    final bytes = await build(c, days: days, regular: regular, bold: bold);
    final dir = await getTemporaryDirectory();
    final safe = c.displayName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final now = DateTime.now();
    final file = File(
      '${dir.path}/EchoSteps_${safe}_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'EchoSteps practice report: ${c.displayName}',
        text: 'EchoSteps practice report for ${c.displayName} (last $days days).',
      ),
    );
  }
}
