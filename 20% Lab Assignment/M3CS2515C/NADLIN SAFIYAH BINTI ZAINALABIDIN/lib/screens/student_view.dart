import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/calc.dart';
import '../services/firestore_service.dart';
import '../models/carry_mark.dart';

class StudentView extends StatefulWidget {
  const StudentView({super.key});

  @override
  State<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<StudentView> {
  final _testCtrl = TextEditingController();
  final _assignmentCtrl = TextEditingController();
  final _projectCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final _targetFinalCtrl = TextEditingController();

  @override
  void dispose() {
    _testCtrl.dispose();
    _assignmentCtrl.dispose();
    _projectCtrl.dispose();
    _feedbackCtrl.dispose();
    _targetFinalCtrl.dispose();
    super.dispose();
  }

  CarryMark? _loadedCarryMark;

  @override
  void initState() {
    super.initState();
    _loadCarryMarkIfAny();
  }

  Future<void> _loadCarryMarkIfAny() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final svc = FirestoreService();
    final courseId = 'ICT602';

    // Try likely keys in order: email (original identifier), uid
    final candidates = <String>[];
    final profile = auth.currentProfile;
    if (profile != null) {
      if (profile.email.isNotEmpty) candidates.add(profile.email);
      candidates.add(profile.uid);
      if (profile.displayName != null && profile.displayName!.isNotEmpty) candidates.add(profile.displayName!);
    }

    for (final id in candidates) {
      try {
        final cm = await svc.getCarryMark(courseId, id);
        if (cm != null) {
          if (!mounted) return;
          setState(() {
            _loadedCarryMark = cm;
            _testCtrl.text = cm.test.toString();
            _assignmentCtrl.text = cm.assignment.toString();
            _projectCtrl.text = cm.project.toString();
            _feedbackCtrl.text = cm.feedback ?? '';
          });
          return;
        }
      } catch (_) {
        // ignore and try next
      }
    }
    // no carry mark found — leave fields as entered by user
  }

  Color _colorForChance(double chance) {
    if (chance >= 75) return Colors.green;
    if (chance >= 50) return Colors.orange;
    if (chance >= 25) return Colors.deepOrange;
    return Colors.red;
  }

  double _parse(TextEditingController c) => double.tryParse(c.text) ?? 0.0;

  Map<String, double> gradeTargets = const {
    'A+ (90-100)': 90,
    'A (80-89)': 80,
    'A- (75-79)': 75,
    'B+ (70-74)': 70,
    'B (65-69)': 65,
    'B- (60-64)': 60,
    'C+ (55-59)': 55,
    'C (50-54)': 50,
  };

  String _gradeForTotal(double total) {
    // Find the highest grade where total >= threshold
    final entries = gradeTargets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in entries) {
      if (total >= e.value) return e.key;
    }
    return 'F (<50)';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final email = auth.currentProfile?.email ?? 'student';

    final test = _parse(_testCtrl);
    final assignment = _parse(_assignmentCtrl);
    final project = _parse(_projectCtrl);
    final partial = computePartialPercent(test: test, assignment: assignment, project: project);

  final hasCarryMark = _loadedCarryMark != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student View'),
        actions: [
          IconButton(
            tooltip: 'Explain grades and likelihood',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('How to read the results'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Current partial percent:'),
                        Text('- Contribution so far from tests, assignments and project using the course weights.'),
                        SizedBox(height: 8),
                        Text('Required final:'),
                        Text('- The score you need on the final exam so your total course mark reaches the target grade.'),
                        SizedBox(height: 8),
                        Text('Likelihood:'),
                        Text('- A heuristic probability (0-100%) that you can achieve that required final mark.'),
                        Text('- Lower required final -> higher likelihood. This is an estimate only.'),
                      ],
                    ),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
                ),
              );
            },
          ),
          IconButton(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout))
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Hello, $email', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (hasCarryMark)
                        Flexible(
                          flex: 0,
                          child: Text('Loaded: ${_loadedCarryMark!.studentName}', style: const TextStyle(color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Enter your partial scores (0-100):'),
                  // New card: allow student to enter a target final exam mark and see
                  // the resulting total and grade immediately.
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Try a target final exam mark:'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextField(controller: _targetFinalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target final (%)'))),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              final target = double.tryParse(_targetFinalCtrl.text) ?? 0.0;
                              final finalWeight = 0.5;
                              final total = partial + (target * finalWeight);
                              final clampedTotal = total.clamp(0.0, 100.0);
                              final grade = _gradeForTotal(clampedTotal);
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Projected result'),
                                  content: SingleChildScrollView(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Target final: ${target.toStringAsFixed(1)}%'),
                                      const SizedBox(height: 8),
                                      Text('Projected total: ${clampedTotal.toStringAsFixed(2)}%'),
                                      const SizedBox(height: 8),
                                      Text('Estimated grade: $grade'),
                                    ]),
                                  ),
                                  actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
                                ),
                              );
                            },
                            child: const Text('Calculate'),
                          ),
                        ])
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: _testCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Test (0-100)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _assignmentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Assignment (0-100)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _projectCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Project (0-100)'))),
                  ])
                ])),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Correction request / feedback (optional):'),
                  const SizedBox(height: 8),
                  TextField(controller: _feedbackCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe any discrepancy or request correction...')),
                  const SizedBox(height: 8),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        final auth = Provider.of<AuthService>(context, listen: false);
                        final svc = FirestoreService();
                        final courseId = 'ICT602';

                        final profile = auth.currentProfile;
                        String studentId = profile?.email ?? profile?.uid ?? 'unknown_student';

                        final cm = CarryMark(
                          studentId: studentId,
                          studentName: profile?.displayName ?? studentId,
                          test: double.tryParse(_testCtrl.text) ?? 0.0,
                          assignment: double.tryParse(_assignmentCtrl.text) ?? 0.0,
                          project: double.tryParse(_projectCtrl.text) ?? 0.0,
                          feedback: _feedbackCtrl.text.trim(),
                        );

                        try {
                          await svc.saveCarryMark(courseId, cm);
                          if (mounted) {
                            setState(() {
                              _loadedCarryMark = cm;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback submitted')));
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
                        }
                      },
                      child: const Text('Request correction'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(onPressed: () => _feedbackCtrl.clear(), child: const Text('Clear')),
                  ])
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Required final exam mark to reach each target grade:'),
                  const SizedBox(height: 8),
                  ...gradeTargets.entries.map((e) {
                    final raw = computeRequiredFinal(partialPercent: partial, targetTotal: e.value, finalWeight: 0.5);
                    final clamped = clampScore(raw);
                    final display = raw > 100 ? 'Impossible (need ${raw.toStringAsFixed(1)} > 100)' : '${clamped.toStringAsFixed(1)}%';
                    final chance = estimateChancePercent(raw);
                    final label = raw > 100
                        ? 'Impossible'
                        : (chance >= 75
                            ? 'Very likely'
                            : (chance >= 50 ? 'Likely' : (chance >= 25 ? 'Unlikely' : 'Very unlikely')));

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.key),
                        subtitle: Text('Required final: $display — $label'),
                        trailing: SizedBox(
                          width: 120,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: (chance / 100).clamp(0.0, 1.0), minHeight: 8, color: _colorForChance(chance), backgroundColor: Colors.grey.shade300),
                              ),
                              const SizedBox(height: 6),
                              Text('${chance.toStringAsFixed(0)}%', style: TextStyle(color: _colorForChance(chance), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _handleCalculate, child: const Text('Recalculate')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCalculate() {
    final test = _parse(_testCtrl);
    final assignment = _parse(_assignmentCtrl);
    final project = _parse(_projectCtrl);
    final partial = computePartialPercent(test: test, assignment: assignment, project: project);

    // If all inputs are zero and fields are empty, warn the user
    final allEmpty = _testCtrl.text.trim().isEmpty && _assignmentCtrl.text.trim().isEmpty && _projectCtrl.text.trim().isEmpty;
    if (allEmpty) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No input'),
          content: const Text('Please enter at least one partial score before calculating.'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
      return;
    }

    final results = gradeTargets.entries.map((e) {
      final raw = computeRequiredFinal(partialPercent: partial, targetTotal: e.value, finalWeight: 0.5);
      final clamped = clampScore(raw);
      final display = raw > 100 ? 'Impossible (need ${raw.toStringAsFixed(1)} > 100)' : '${clamped.toStringAsFixed(1)}%';
      return '${e.key}: $display';
    }).join('\n');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calculation results'),
        content: SingleChildScrollView(child: Text('Partial percent: ${partial.toStringAsFixed(2)}%\n\n$results')),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }
}
