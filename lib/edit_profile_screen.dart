// edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Moved OUTSIDE of the State class
class SplitName {
  final String first;
  final String last;
  const SplitName(this.first, this.last);
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _smsOptIn = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      _emailController.text = user.email ?? '';

      final snap =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (snap.exists) {
        final data = snap.data() ?? {};

        final fullName =
            (data['fullName'] as String?)?.trim() ??
            _combineName(
              (data['firstName'] as String?)?.trim(),
              (data['lastName'] as String?)?.trim(),
              (data['name'] as String?)?.trim(),
            );

        _fullNameController.text = fullName;
        _phoneController.text = (data['phone'] as String?) ?? '';
        _smsOptIn = (data['notifications'] is Map &&
                (data['notifications']['smsEnabled'] is bool))
            ? (data['notifications']['smsEnabled'] as bool)
            : false;
        _avatarUrl = (data['avatarUrl'] as String?);
      }
    } catch (_) {
      // ignore read errors
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  SplitName _splitFullName(String full) {
    final parts = full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return const SplitName('Friend', '');
    if (parts.length == 1) return SplitName(_cap(parts.first), '');
    return SplitName(_cap(parts.first), _cap(parts.sublist(1).join(' ')));
  }

  String _combineName(String? first, String? last, String? fallback) {
    if ((first ?? '').isNotEmpty || (last ?? '').isNotEmpty) {
      return [first ?? '', last ?? ''].where((s) => s.trim().isNotEmpty).join(' ').trim();
    }
    return fallback ?? '';
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Please enter your email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _validatePhone(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final ok = RegExp(r'^\+?[0-9 \-().]{7,}$').hasMatch(value);
    if (!ok) return 'Enter a valid phone number';
    return null;
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset email: $e')),
      );
    }
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final full = _fullNameController.text.trim();
    final split = _splitFullName(full);
    final newEmail = _emailController.text.trim();
    final newPassword = _passwordController.text;
    final phone = _phoneController.text.trim();

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': full,
        'firstName': split.first,
        'lastName': split.last,
        'phone': phone,
        'avatarUrl': _avatarUrl,
        'notifications': {'smsEnabled': _smsOptIn},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (full.isNotEmpty && full != (user.displayName ?? '')) {
        await user.updateDisplayName(full);
      }

      if (newEmail.isNotEmpty && newEmail != (user.email ?? '')) {
        await user.verifyBeforeUpdateEmail(newEmail);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent to update your email.'),
            ),
          );
        }
      }

      if (newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated.')),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _sendPasswordResetEmail,
            child: const Text('Reset via Email'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage:
                                    (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                        ? NetworkImage(_avatarUrl!)
                                        : null,
                                child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                    ? const Icon(Icons.person, size: 36, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  color: theme.colorScheme.primary,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () async {
                                      // TODO: avatar picker logic
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(6.0),
                                      child: Icon(Icons.edit, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _fullNameController.text.isEmpty
                                  ? 'Your Name'
                                  : _fullNameController.text,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _fullNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone (for SMS alerts)',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: _validatePhone,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Switch(
                                  value: _smsOptIn,
                                  onChanged: (v) => setState(() => _smsOptIn = v),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Receive SMS notifications (alerts, updates)',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New password (optional)',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _saveChanges,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Save changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Note: Password resets are sent via email. SMS notifications '
                    'require a messaging provider (e.g., Twilio) and consent.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
    );
  }
}
