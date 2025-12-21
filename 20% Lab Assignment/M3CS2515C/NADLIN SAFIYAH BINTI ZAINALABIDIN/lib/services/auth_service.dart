import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = true;
  UserProfile? currentProfile;
  String lastLog = '';

  void _appendLog(String msg) {
    lastLog = '${DateTime.now().toIso8601String()} - $msg\n${lastLog.length > 4000 ? lastLog.substring(0, 4000) : lastLog}';
    print(msg);
  }

  AuthService() {
    _auth.authStateChanges().listen((user) async {
      isLoading = true;
      notifyListeners();

      if (user == null) {
        currentProfile = null;
        isLoading = false;
        notifyListeners();
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final map = doc.data()!;
        currentProfile = UserProfile.fromMap({...map, 'uid': user.uid});
      } else {
        currentProfile = UserProfile(uid: user.uid, email: user.email ?? '', displayName: user.displayName, role: 'student');
      }

      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final originalIdentifier = email;
      var authEmail = _authEmailFromIdentifier(email);
      _appendLog('AuthService.signIn: attempting sign in for $email -> authEmail=$authEmail');
      UserCredential? credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(email: authEmail, password: password);
      } on FirebaseAuthException catch (e) {
        _appendLog('AuthService.signIn: primary signIn exception ${e.code}');
        // If user not found and the user supplied a short identifier (no @),
        // try to lookup a matching user profile in Firestore and retry with
        // the identifier stored there (this allows username-style login).
        if (e.code == 'user-not-found' && !originalIdentifier.contains('@')) {
          try {
            _appendLog('AuthService.signIn: trying fallback lookup for identifier=$originalIdentifier');
            final q = await _firestore.collection('users').where('email', isEqualTo: originalIdentifier).limit(1).get();
            if (q.docs.isEmpty) {
              // also try displayName match as a fallback
              final q2 = await _firestore.collection('users').where('displayName', isEqualTo: originalIdentifier).limit(1).get();
              if (q2.docs.isNotEmpty) {
                final doc = q2.docs.first;
                final storedIdentifier = doc.data()['email'] as String? ?? originalIdentifier;
                final fallbackAuthEmail = _authEmailFromIdentifier(storedIdentifier);
                _appendLog('AuthService.signIn: found profile by displayName, storedIdentifier=$storedIdentifier -> fallbackAuthEmail=$fallbackAuthEmail');
                credential = await _auth.signInWithEmailAndPassword(email: fallbackAuthEmail, password: password);
              }
            } else {
              final doc = q.docs.first;
              final storedIdentifier = doc.data()['email'] as String? ?? originalIdentifier;
              final fallbackAuthEmail = _authEmailFromIdentifier(storedIdentifier);
              _appendLog('AuthService.signIn: found profile by email field, storedIdentifier=$storedIdentifier -> fallbackAuthEmail=$fallbackAuthEmail');
              credential = await _auth.signInWithEmailAndPassword(email: fallbackAuthEmail, password: password);
            }
          } catch (fallbackErr) {
            _appendLog('AuthService.signIn: fallback lookup/signIn failed: $fallbackErr');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
  final user = credential?.user;
  if (user != null) {
        _appendLog('AuthService.signIn: signed in uid=${user.uid}');
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          currentProfile = UserProfile.fromMap({...doc.data()!, 'uid': user.uid});
          _appendLog('AuthService.signIn: loaded profile role=${currentProfile?.role}');
        } else {
          // Determine role from the identifier the user supplied (email param)
          final determinedRole = _determineRoleFromIdentifier(email);
          currentProfile = UserProfile(uid: user.uid, email: email, displayName: user.displayName, role: determinedRole);
          // Persist the profile so next sign-ins pick up the role. Don't block
          // sign-in if the write fails due to security rules — log and continue.
          try {
            await _firestore.collection('users').doc(user.uid).set(currentProfile!.toMap());
            _appendLog('AuthService.signIn: no profile doc, created with role=$determinedRole');
          } catch (e) {
            _appendLog('AuthService.signIn: failed to write profile doc: $e');
          }
        }
      } else {
        _appendLog('AuthService.signIn: signIn returned null user');
        throw FirebaseAuthException(code: 'no-user', message: 'Sign in did not return a user');
      }
    } catch (e) {
      // log and rethrow so UI can handle the exception
      _appendLog('AuthService.signIn: exception $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
  /// - If identifier equals 'root' or 'admin' (case-insensitive) => 'admin'
  /// - If identifier is numeric and in range 2018000000..2025999999 => 'student'
  /// - If identifier contains alphabetic characters => 'lecturer'
  /// - Otherwise defaults to 'lecturer'.
  String _determineRoleFromIdentifier(String identifier) {
    final id = identifier.trim();
    final lower = id.toLowerCase();
    if (lower == 'root' || lower == 'admin') return 'admin';

    // If email-like (contains @), use local-part
    final local = id.contains('@') ? id.split('@').first : id;

  final digitsOnly = RegExp(r'^\d+$');
    if (digitsOnly.hasMatch(local)) {
      try {
        final value = int.parse(local);
        if (value >= 2018000000 && value <= 2025999999) return 'student';
        // numeric but outside range -> treat as lecturer/staff
        return 'lecturer';
      } catch (_) {
        return 'lecturer';
      }
    }

    // If contains any alphabetic chars, treat as staff/lecturer
    final alpha = RegExp(r'[A-Za-z]');
    if (alpha.hasMatch(local)) return 'lecturer';

    return 'lecturer';
  }

  Future<void> signUp({required String email, required String password, String? displayName, String role = 'student'}) async {
    isLoading = true;
    notifyListeners();
    try {
  // Normalize and create with an auth-email if user supplied a numeric id or short id
  final authEmail = _authEmailFromIdentifier(email);
  _appendLog('AuthService.signUp: creating user for $email -> authEmail=$authEmail role=$role');
  final credential = await _auth.createUserWithEmailAndPassword(email: authEmail, password: password);
      final user = credential.user;
      if (user != null) {
        _appendLog('AuthService.signUp: created uid=${user.uid}');
        // update display name if provided
        if (displayName != null && displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
  // store the original identifier in profile.email so UI shows what user entered
  final profile = UserProfile(uid: user.uid, email: email, displayName: displayName, role: role);
        // write profile doc
        await _firestore.collection('users').doc(user.uid).set(profile.toMap());
        currentProfile = profile;
        _appendLog('AuthService.signUp: profile written role=${profile.role}');
      } else {
        _appendLog('AuthService.signUp: createUser returned null user');
      }
    } catch (e) {
      _appendLog('AuthService.signUp: exception $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Convert a user-supplied identifier into an email address suitable for
  /// Firebase Email/Password authentication when the identifier is not an
  /// email. This lets users sign up with plain numeric IDs or short names.
  String _authEmailFromIdentifier(String identifier) {
    final id = identifier.trim();
    if (id.contains('@')) return id; // already an email

    final lower = id.toLowerCase();
    if (lower == 'root' || lower == 'admin') return 'admin@local.carrymark';

    final local = id;
    final digitsOnly = RegExp(r'^\d+$');
    if (digitsOnly.hasMatch(local)) {
      try {
        final value = int.parse(local);
        if (value >= 2018000000 && value <= 2025999999) return '$local@student.carrymark.local';
        return '$local@staff.carrymark.local';
      } catch (_) {
        return '$local@staff.carrymark.local';
      }
    }

    // fallback: treat as staff name
    return '$local@staff.carrymark.local';
  }

  Future<void> signOut() async {
    await _auth.signOut();
    currentProfile = null;
    notifyListeners();
  }
}
