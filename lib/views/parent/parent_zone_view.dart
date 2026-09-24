import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/services.dart';
import '../../widgets/characters.dart';
import 'family_tab.dart';
import 'progress_tab.dart';
import 'settings_tab.dart';

/// Grown-ups' area behind the parent gate: progress, settings, family and
/// account.
class ParentZoneView extends StatefulWidget {
  const ParentZoneView({super.key});

  @override
  State<ParentZoneView> createState() => _ParentZoneViewState();
}

class _ParentZoneViewState extends State<ParentZoneView> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = Services.of(context);
      s.speech.hush();
      s.sound.music(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return ListenableBuilder(
      listenable: s.store,
      builder: (context, _) {
        final child = s.store.active;
        if (child == null) {
          // Signed out or every child removed: leave; the app restarts setup.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          });
          return const Scaffold();
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Parent Zone'),
            actions: [if (s.store.children.length > 1) _ChildSwitcher(active: child)],
          ),
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: _tab,
              children: [
                ProgressTab(child: child),
                SettingsTab(child: child),
                const FamilyTab(),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.insights_rounded), label: 'Progress'),
              NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Settings'),
              NavigationDestination(icon: Icon(Icons.family_restroom_rounded), label: 'Family & account'),
            ],
          ),
        );
      },
    );
  }
}

class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({required this.active});
  final ChildProfile active;

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return PopupMenuButton<ChildProfile>(
      tooltip: 'Switch child',
      color: ES.card,
      onSelected: (c) {
        s.store.active = c;
        s.applySettings();
      },
      itemBuilder: (_) => [
        for (final c in s.store.children)
          PopupMenuItem(
            value: c,
            child: Row(
              children: [
                BuddyFace(pip: c.buddy == Buddy.pip, size: 32),
                const SizedBox(width: 8),
                Text(c.displayName, style: TextStyle(fontWeight: c.id == active.id ? FontWeight.w700 : null)),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            BuddyFace(pip: active.buddy == Buddy.pip, size: 36),
            const SizedBox(width: 4),
            Text(active.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
