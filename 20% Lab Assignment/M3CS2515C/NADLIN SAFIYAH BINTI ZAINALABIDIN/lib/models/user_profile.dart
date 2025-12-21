class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String role;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    required this.role,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      role: map['role'] as String? ?? 'student',
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role,
      };
}
