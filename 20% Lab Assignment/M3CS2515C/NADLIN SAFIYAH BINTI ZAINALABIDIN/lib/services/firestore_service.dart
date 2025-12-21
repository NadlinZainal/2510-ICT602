import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/carry_mark.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save or update a carry mark under `courses/{courseId}/carrymarks/{studentId}`
  Future<void> saveCarryMark(String courseId, CarryMark cm) async {
    final ref = _db.collection('courses').doc(courseId).collection('carrymarks').doc(cm.studentId);
    await ref.set(cm.toMap(), SetOptions(merge: true));
  }

  /// Get a stream of carry marks for a course
  Stream<List<CarryMark>> streamCarryMarks(String courseId) {
    final ref = _db.collection('courses').doc(courseId).collection('carrymarks').orderBy('studentName');
    return ref.snapshots().map((snap) => snap.docs.map((d) => CarryMark.fromMap(d.data())).toList());
  }

  /// Get a single carry mark
  Future<CarryMark?> getCarryMark(String courseId, String studentId) async {
    final doc = await _db.collection('courses').doc(courseId).collection('carrymarks').doc(studentId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CarryMark.fromMap(doc.data()!);
  }
}
