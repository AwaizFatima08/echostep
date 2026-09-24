import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/child.dart';
import '../../services/cloud_sync.dart';
import '../../services/services.dart';
import '../../widgets/characters.dart';
import '../../widgets/parent_widgets.dart';
import '../onboarding/onboarding_view.dart';
import 'account_views.dart';

/// Children on this device, cloud backup and the account.
class FamilyTab extends StatefulWidget {
  const FamilyTab({super.key});

  @override
  State<FamilyTab> createState() => _FamilyTabState();
}

class _FamilyTabState extends State<FamilyTab> {
  bool _busy = false;

  Services get s => Services.of(context);

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit(ChildProfile c) async {
    final name = TextEditingController(text: c.nickname);
    var age = c.ageGroup;
    var buddy = c.buddy;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: ES.card,
          title: const Text('Edit child'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final a in ageGroups)
                      ChoiceChip(label: Text(a), selected: age == a, onSelected: (_) => set(() => age = a)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final b in Buddy.values)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => set(() => buddy = b),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: buddy == b ? ES.sunshine : Colors.transparent, width: 3),
                          ),
                          child: Column(
                            children: [
                              BuddyFace(pip: b == Buddy.pip, size: 64),
                              Text(b.displayName),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved == true) {
      c
        ..nickname = name.text.trim()
        ..ageGroup = age
        ..buddy = buddy;
      s.store.childUpdated(c);
      setState(() {});
    }
    name.dispose();
  }

  Future<void> _childMenu(ChildProfile c, String action) async {
    if (action == 'edit') return _edit(c);
    if (action == 'reset') {
      if (await confirm(
        context,
        title: 'Reset ${c.displayName}\'s progress?',
        message: 'Clears sessions, sounds practised and unlocked cards. Settings stay.',
        action: 'Reset',
        destructive: true,
      )) {
        s.store.resetProgress(c);
        setState(() {});
      }
    }
    if (action == 'remove') {
      if (!mounted) return;
      if (await confirm(
        context,
        title: 'Remove ${c.displayName}?',
        message: 'Deletes this child and all their progress from this device and from the cloud backup.',
        action: 'Remove',
        destructive: true,
      )) {
        await s.store.deleteChild(c);
        s.applySettings();
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _setBackup(bool on) async {
    var deleteExisting = false;
    if (!on && s.cloud.user != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ES.card,
          title: const Text('Turn off cloud backup?'),
          content: const Text(
            'New progress will stay on this device only. What should happen to the copy already in the cloud?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('Keep it')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ES.coral, foregroundColor: ES.canvasDeep),
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Delete it'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      deleteExisting = choice == 'delete';
    }
    setState(() => _busy = true);
    await s.cloud.setBackup(on, deleteExisting: deleteExisting);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut() async {
    if (!await confirm(
      context,
      title: 'Sign out of this device?',
      message:
          'The children will be removed from this device. Their progress stays in your account; sign in again to get it back.',
      action: 'Sign out',
    )) {
      return;
    }
    await s.cloud.pushAll();
    await s.cloud.signOut();
  }

  Future<void> _deleteAll() async {
    final linked = s.cloud.state.value.mode == CloudMode.linked;
    if (!await confirm(
      context,
      title: 'Delete everything?',
      message:
          'This permanently deletes every child, all progress on this device and in the cloud'
          '${linked ? ', and your EchoSteps account' : ''}. It can\'t be undone.',
      action: 'Delete everything',
      destructive: true,
    )) {
      return;
    }
    String? password;
    if (linked) {
      if (!mounted) return;
      password = await _askPassword();
      if (password == null) return;
    }
    setState(() => _busy = true);
    try {
      if (s.cloud.available && s.cloud.user != null) {
        await s.cloud.deleteAccount(password: password);
      } else {
        await s.store.clearAll();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(authMessage(e));
      }
    }
  }

  Future<String?> _askPassword() {
    final pw = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ES.card,
        title: const Text('Confirm with your password'),
        content: TextField(
          controller: pw,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, pw.text), child: const Text('Confirm')),
        ],
      ),
    ).whenComplete(pw.dispose);
  }

  String _ago(DateTime? t) {
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return ' · synced just now';
    if (d.inHours < 1) return ' · synced ${d.inMinutes} min ago';
    return ' · synced ${d.inHours} h ago';
  }

  @override
  Widget build(BuildContext context) {
    final store = s.store;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Children', icon: Icons.child_care_rounded),
              for (final c in store.children)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: BuddyFace(pip: c.buddy == Buddy.pip, size: 48),
                  title: Text(c.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'Age ${c.ageGroup} · ${c.buddy.displayName}${c.id == store.active?.id ? ' · playing now' : ''}',
                  ),
                  onTap: () => _edit(c),
                  trailing: PopupMenuButton<String>(
                    color: ES.card,
                    onSelected: (a) => _childMenu(c, a),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'reset', child: Text('Reset progress')),
                      PopupMenuItem(value: 'remove', child: Text('Remove child')),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final added = await Navigator.of(
                    context,
                  ).push<bool>(MaterialPageRoute(builder: (_) => const OnboardingView(addingChild: true)));
                  if (added == true && mounted) setState(() {});
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add a child'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<CloudState>(
          valueListenable: s.cloud.state,
          builder: (context, st, _) => PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  'Cloud backup',
                  icon: Icons.cloud_rounded,
                  trailing: Switch(
                    value: store.settings.cloudBackup && st.mode != CloudMode.unavailable,
                    onChanged: _busy || st.mode == CloudMode.unavailable ? null : _setBackup,
                  ),
                ),
                Text(switch (st.mode) {
                  CloudMode.unavailable => 'Not available on this device. Progress is saved on this device.',
                  CloudMode.off => 'Off. Progress is saved on this device only.',
                  CloudMode.waiting => 'Waiting for an internet connection…',
                  CloudMode.guest => 'On, saved to this device\'s private backup${_ago(st.lastSync)}.',
                  CloudMode.linked => 'On, signed in as ${st.email}${_ago(st.lastSync)}.',
                }, style: const TextStyle(fontSize: 16, height: 1.35)),
                if (st.mode == CloudMode.guest) ...[
                  const SizedBox(height: 6),
                  const Hint('To keep progress when you change phones, add an email and password.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAccountView())),
                    icon: const Icon(Icons.devices_rounded),
                    label: const Text('Save progress across devices'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInView())),
                    child: const Text('I already have an account'),
                  ),
                ],
                if (st.mode == CloudMode.linked) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await s.cloud.pushAll();
                          if (mounted) _snack('Backed up.');
                        },
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Sync now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
                if (st.mode == CloudMode.off || st.mode == CloudMode.waiting) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: s.cloud.available
                        ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInView()))
                        : null,
                    child: const Text('Sign in to an existing account'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Privacy', icon: Icons.privacy_tip_rounded),
              const Hint(
                'The microphone is analysed on this device and never recorded or uploaded. EchoSteps has no ads '
                'and no tracking.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  TextButton(onPressed: () => openLink(context, Links.privacy), child: const Text('Privacy policy')),
                  TextButton(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'EchoSteps',
                      applicationVersion: '1.0.0',
                      applicationLegalese: 'Pictures: Noto Color Emoji (Google, Apache 2.0). Font: Andika (SIL, OFL).',
                    ),
                    child: const Text('Licences'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('delete-everything'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ES.coral,
                  side: const BorderSide(color: ES.coral, width: 1.5),
                ),
                onPressed: _busy ? null : _deleteAll,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Delete account and all data'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Hint(
            'EchoSteps 1.0.0 · An educational practice app, not a medical device or a substitute for therapy.',
            size: 12,
          ),
        ),
      ],
    );
  }
}
