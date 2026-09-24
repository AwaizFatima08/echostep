import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

/// Public pages (Firebase Hosting, project echosteps-homilabs).
abstract final class Links {
  static const privacy = 'https://echosteps-homilabs.web.app/privacy';
  static const deleteAccount = 'https://echosteps-homilabs.web.app/delete-account';
}

Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t open $url')));
  }
}

/// Rounded panel for grown-up screens.
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = ES.card});
  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(ES.radius),
      border: Border.all(color: ES.cardLine, width: 1.5),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon, this.trailing});
  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        if (icon != null) ...[Icon(icon, color: ES.turquoise, size: 22), const SizedBox(width: 8)],
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Muted explanatory text.
class Hint extends StatelessWidget {
  const Hint(this.text, {super.key, this.size = 15});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: ES.muted, fontSize: size, height: 1.35),
  );
}

/// Selectable pill (age groups, levels).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.selected, required this.onTap, this.color = ES.turquoise});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 84, minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : ES.card,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: selected ? color : ES.cardLine, width: 2),
          ),
          // Center with size factors keeps the pill as small as its label
          // (plain alignment would stretch it across a Wrap).
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: selected ? ES.canvasDeep : ES.cream),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple "Are you sure?" dialog.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: ES.card,
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 16, height: 1.35)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: ES.coral, foregroundColor: ES.canvasDeep) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
