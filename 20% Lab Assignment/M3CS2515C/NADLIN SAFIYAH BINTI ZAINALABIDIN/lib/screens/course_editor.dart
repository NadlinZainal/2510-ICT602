import 'package:flutter/material.dart';

import '../models/carry_mark.dart';
import '../services/firestore_service.dart';

class CourseEditor extends StatefulWidget {
  final String courseId;
  final CarryMark? carryMark;

  const CourseEditor({super.key, required this.courseId, this.carryMark});

  @override
  State<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<CourseEditor> {
  final _formKey = GlobalKey<FormState>();
  final _studentId = TextEditingController();
  final _studentName = TextEditingController();
  final _test = TextEditingController();
  final _assignment = TextEditingController();
  final _project = TextEditingController();
  bool _busy = false;

  final _fs = FirestoreService();

  @override
  void initState() {
    super.initState();
    final cm = widget.carryMark;
    if (cm != null) {
      _studentId.text = cm.studentId;
      _studentName.text = cm.studentName;
      _test.text = cm.test.toString();
      _assignment.text = cm.assignment.toString();
      _project.text = cm.project.toString();
    }
  }

  @override
  void dispose() {
    _studentId.dispose();
    _studentName.dispose();
    _test.dispose();
    _assignment.dispose();
    _project.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final cm = CarryMark(
        studentId: _studentId.text.trim(),
        studentName: _studentName.text.trim(),
        test: double.tryParse(_test.text) ?? 0.0,
        assignment: double.tryParse(_assignment.text) ?? 0.0,
        project: double.tryParse(_project.text) ?? 0.0,
      );
      await _fs.saveCarryMark(widget.courseId, cm);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course Editor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: TextFormField(controller: _studentId, decoration: const InputDecoration(labelText: 'Student ID'), validator: (v) => (v == null || v.isEmpty) ? 'Enter student id' : null)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _studentName, decoration: const InputDecoration(labelText: 'Student name'), validator: (v) => (v == null || v.isEmpty) ? 'Enter student name' : null)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _test, decoration: const InputDecoration(labelText: 'Test (0-100)'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? 'Enter test score' : null)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _assignment, decoration: const InputDecoration(labelText: 'Assignment (0-100)'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? 'Enter assignment score' : null)),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _project, decoration: const InputDecoration(labelText: 'Project (0-100)'), keyboardType: TextInputType.number, validator: (v) => (v == null || v.isEmpty) ? 'Enter project score' : null)),
                    ]),
                    const SizedBox(height: 16),
                    if (widget.carryMark?.feedback != null && widget.carryMark!.feedback!.isNotEmpty) ...[
                      const Text('Student feedback/request:'),
                      const SizedBox(height: 6),
                      Text(widget.carryMark!.feedback!),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton(onPressed: _busy ? null : _save, child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Carry Mark')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
