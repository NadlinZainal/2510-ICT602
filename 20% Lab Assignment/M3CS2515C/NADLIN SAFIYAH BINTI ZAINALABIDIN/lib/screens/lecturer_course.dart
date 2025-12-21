import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import 'course_editor.dart';
import '../services/firestore_service.dart';
import '../models/carry_mark.dart';

class LecturerCourse extends StatelessWidget {
  const LecturerCourse({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final email = auth.currentProfile?.email ?? 'lecturer';
  const courseId = 'ICT602';
  final svc = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer - ICT602'),
        actions: [IconButton(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Welcome, $email', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Enter or edit Carry Marks for ICT602.'),
                  const SizedBox(height: 6),
                  const Text('Partial weights: Test 20%, Assignment 10%, Project 20% (Final 50%).'),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseEditor(courseId: courseId))), child: const Text('Add Carry Mark (New')),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: StreamBuilder<List<CarryMark>>(
                    stream: svc.streamCarryMarks(courseId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) return const Center(child: Text('No carry marks yet'));
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final cm = list[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                            child: ListTile(
                              leading: CircleAvatar(child: Text(cm.studentName.isNotEmpty ? cm.studentName[0].toUpperCase() : cm.studentId[0])),
                              title: Text(cm.studentName.isNotEmpty ? cm.studentName : cm.studentId),
                              subtitle: Text('Test ${cm.test}  Assignment ${cm.assignment}  Project ${cm.project}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CourseEditor(courseId: courseId, carryMark: cm)));
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
