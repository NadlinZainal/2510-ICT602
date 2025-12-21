import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
// debug imports removed

import '../services/auth_service.dart';
import 'admin_landing.dart';
import 'lecturer_course.dart';
import 'student_view.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    // Clear previous field errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text);
  
      final role = auth.currentProfile?.role ?? 'student';
      // ignore: avoid_print
      print('Signed in, role=$role');
      if (!mounted) return;
      final message = 'Signed in as $role';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 800)));
      await Future.delayed(const Duration(milliseconds: 800));
      Widget dest;
      switch (role) {
        case 'admin':
          dest = const AdminLanding();
          break;
        case 'lecturer':
          dest = const LecturerCourse();
          break;
        default:
          dest = const StudentView();
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => dest));
  } on FirebaseAuthException catch (e) {
      // Provide friendly messages for common auth errors and inline field errors
      String message = 'Authentication error';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email/username.';
        setState(() => _emailError = message);
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password. Please try again.';
        setState(() => _passwordError = message);
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
        setState(() => _emailError = message);
      } else {
        message = e.message ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $message')));
        // Also show a blocking dialog with the error so it's very visible in the emulator
        final debugInfo = kDebugMode ? '\n\nDebug log:\n${auth.lastLog}' : '';
        await _showErrorDialog('Login failed', '$message$debugInfo');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
        final debugInfo = kDebugMode ? '\n\nDebug log:\n${auth.lastLog}' : '';
        await _showErrorDialog('Login failed', '$e$debugInfo');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final displayName = null;

    // Simple role selector dialog
    final role = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = 'student';
        return AlertDialog(
          title: const Text('Select role for new account'),
          content: StatefulBuilder(builder: (c, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(value: 'student', groupValue: selected, title: const Text('Student'), onChanged: (v) => setState(() => selected = v!)),
                RadioListTile<String>(value: 'lecturer', groupValue: selected, title: const Text('Lecturer'), onChanged: (v) => setState(() => selected = v!)),
                RadioListTile<String>(value: 'admin', groupValue: selected, title: const Text('Admin'), onChanged: (v) => setState(() => selected = v!)),
              ],
            );
          }),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(selected), child: const Text('Create'))
          ],
        );
      },
    );

    if (role == null) return;

    setState(() => _busy = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      await auth.signUp(email: email, password: password, displayName: displayName, role: role);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created and signed in')));

      final newRole = auth.currentProfile?.role ?? role;
      if (!mounted) return;
      Widget dest;
      switch (newRole) {
        case 'admin':
          dest = const AdminLanding();
          break;
        case 'lecturer':
          dest = const LecturerCourse();
          break;
        default:
          dest = const StudentView();
      }

      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => dest));
  } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Create account failed';
  if (e.code == 'weak-password') message = 'The password provided is too weak.';
  if (e.code == 'email-already-in-use') message = 'The account already exists for that email/username.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create account failed: $message')));
        await _showErrorDialog('Create account failed', message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create account failed: $e')));
        await _showErrorDialog('Create account failed', '$e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primary, child: const Icon(Icons.school, color: Colors.white, size: 28)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('CarryMark', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Sign in to continue', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: InputDecoration(labelText: 'Email/Username', errorText: _emailError),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter email or username';
                            if (_emailError != null) return _emailError;
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passCtrl,
                          decoration: InputDecoration(labelText: 'Password', errorText: _passwordError),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter password';
                            if (_passwordError != null) return _passwordError;
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _busy ? null : _createAccount, child: const Text('Create account')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
