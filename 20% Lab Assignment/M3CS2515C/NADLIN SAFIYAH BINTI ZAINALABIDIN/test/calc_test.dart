import 'package:flutter_test/flutter_test.dart';
import 'package:carrymark_app/utils/calc.dart';

void main() {
  test('required final happy path', () {
    // Example: test=70, assignment=60, project=80
    // partial = 70*0.2 + 60*0.1 + 80*0.2 = 14 + 6 + 16 = 36
    // To reach total 80: required = (80 - 36) / 0.5 = 44 / 0.5 = 88
    final partial = computePartialPercent(test: 70, assignment: 60, project: 80);
    expect(partial, closeTo(36.0, 0.0001));
    final req = computeRequiredFinal(partialPercent: partial, targetTotal: 80, finalWeight: 0.5);
    expect(req, closeTo(88.0, 0.0001));
  });

  test('required final impossible target (>100)', () {
    // If partial is 0 and target is 95, required = 95/0.5 = 190 (>100)
    final partial = computePartialPercent(test: 0, assignment: 0, project: 0);
    final req = computeRequiredFinal(partialPercent: partial, targetTotal: 95, finalWeight: 0.5);
    expect(req, greaterThan(100.0));
  });
}
