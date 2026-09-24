import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/cloud_sync.dart';
import '../../services/services.dart';
import '../../widgets/parent_widgets.dart';

String? _emailError(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Please enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'That email doesn\'t look right';
  return null;
}

/// Adds an email and password to the current (guest) account so progress
/// can be restored on another device. Nothing is lost: the account keeps
/// its ID and data.
class CreateAccountView extends StatefulWidget {
  const CreateAccountView({super.key});

  @override
  State<CreateAccountView> createState() => _CreateAccountViewState();
}

class _CreateAccountViewState extends State<CreateAccountView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Services.of(context).cloud.createAccount(_email.text, _pw.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account created. Progress is saved across devices.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Save progress across devices')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Hint(
              'Add an email and password to this device\'s backup. Everything saved so far stays, and you can sign in on a '
              'new phone or tablet to continue.',
              size: 16,
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _emailError,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('password'),
              controller: _pw,
              obscureText: !_show,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password (8+ characters)',
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              validator: (v) => (v ?? '').length < 8 ? 'Please use at least 8 characters' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('password2'),
              controller: _pw2,
              obscureText: !_show,
              decoration: const InputDecoration(labelText: 'Password again'),
              validator: (v) => v != _pw.text ? 'The passwords don\'t match' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: ES.coral, fontSize: 15)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Create account'),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => openLink(context, Links.privacy), child: const Text('Privacy policy')),
          ],
        ),
      ),
    );
  }
}

/// Signs in to an existing account: this device's children are merged into
/// it and the account's children are downloaded.
class SignInView extends StatefulWidget {
  const SignInView({super.key, this.restoring = false});

  /// Opened from first-run setup to restore progress on a new device.
  final bool restoring;

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = Services.of(context);
    try {
      await s.cloud.signIn(_email.text, _pw.text);
      if (!mounted) return;
      final n = s.store.children.length;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signed in. $n ${n == 1 ? 'child' : 'children'} on this device.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final err = _emailError(_email.text);
    if (err != null) {
      setState(() => _error = 'Enter your email above first, then tap "Forgot password".');
      return;
    }
    try {
      await Services.of(context).cloud.sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('If ${_email.text.trim()} has an account, a reset email is on its way.')));
    } catch (e) {
      setState(() => _error = authMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final hasLocal = s.store.isSetUp;
    return Scaffold(
      appBar: AppBar(title: Text(widget.restoring ? 'Restore progress' : 'Sign in')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Hint(
              hasLocal
                  ? 'The children on this device will be added to that account, and its children will be added here.'
                  : 'Sign in with the email and password you used to save progress on your other device.',
              size: 16,
            ),
            if (!s.cloud.available) ...[
              const SizedBox(height: 12),
              const Text('Cloud accounts aren\'t available on this device.', style: TextStyle(color: ES.coral)),
            ],
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _emailError,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('password'),
              controller: _pw,
              obscureText: !_show,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _show ? 'Hide password' : 'Show password',
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Please enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _busy ? null : _reset, child: const Text('Forgot password?')),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: ES.coral, fontSize: 15)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || !s.cloud.available ? null : _submit,
              child: _busy
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(widget.restoring ? 'Restore' : 'Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
