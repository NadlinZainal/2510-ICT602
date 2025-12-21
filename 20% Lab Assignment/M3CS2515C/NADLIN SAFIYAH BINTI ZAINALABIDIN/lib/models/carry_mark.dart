import 'package:cloud_firestore/cloud_firestore.dart';

class CarryMark {
  final String studentId;
  final String studentName;
  final double test;
  final double assignment;
  final double project;
  final Timestamp updatedAt;
  final String? feedback;

  CarryMark({
    required this.studentId,
    required this.studentName,
    required this.test,
    required this.assignment,
    required this.project,
    this.feedback,
    Timestamp? updatedAt,
  }) : updatedAt = updatedAt ?? Timestamp.now();

  double get partialPercent => (test * 0.20) + (assignment * 0.10) + (project * 0.20);

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'studentName': studentName,
        'test': test,
        'assignment': assignment,
        'project': project,
    'updatedAt': updatedAt,
    'feedback': feedback,
      };

  factory CarryMark.fromMap(Map<String, dynamic> map) {
    return CarryMark(
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      test: (map['test'] as num?)?.toDouble() ?? 0.0,
      assignment: (map['assignment'] as num?)?.toDouble() ?? 0.0,
      project: (map['project'] as num?)?.toDouble() ?? 0.0,
      feedback: map['feedback'] as String?,
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
