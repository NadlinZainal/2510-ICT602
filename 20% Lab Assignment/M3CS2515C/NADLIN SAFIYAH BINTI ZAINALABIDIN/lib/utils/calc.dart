import 'dart:math' as math;

/// Calculation helpers for carry marks and required final exam scores.

/// Compute the partial percentage (weighted partials) using the weights:
/// testWeight, assignmentWeight, projectWeight should sum to partialWeight.
double computePartialPercent({
  required double test,
  required double assignment,
  required double project,
  double testWeight = 0.20,
  double assignmentWeight = 0.10,
  double projectWeight = 0.20,
}) {
  return (test * testWeight) + (assignment * assignmentWeight) + (project * projectWeight);
}

/// Compute required final exam mark (0..100, un-clamped) to reach targetTotal (0..100).
/// finalWeight is the fraction (e.g., 0.5 for 50%).
/// Formula: requiredFinal = (targetTotal - partialPercent) / finalWeight
double computeRequiredFinal({
  required double partialPercent,
  required double targetTotal,
  double finalWeight = 0.5,
}) {
  return (targetTotal - partialPercent) / finalWeight;
}

/// Convenience: compute required final from raw partial scores.
double requiredFinalFromScores({
  required double test,
  required double assignment,
  required double project,
  required double targetTotal,
  double finalWeight = 0.5,
}) {
  final partial = computePartialPercent(test: test, assignment: assignment, project: project);
  return computeRequiredFinal(partialPercent: partial, targetTotal: targetTotal, finalWeight: finalWeight);
}

/// Clamp a score into the 0..100 range.
double clampScore(double value) => value.isNaN ? 0.0 : (value < 0 ? 0.0 : (value > 100 ? 100.0 : value));

/// Estimate the likelihood (0..100%) that a student can achieve the required
/// final exam mark. This is a simple heuristic using a logistic curve so that
/// lower required marks map to higher probabilities and very high required
/// marks approach 0%.
///
/// - `requiredFinal` is the (unclamped) percentage needed on the final (0..100+).
/// Returns a value in 0..100 representing estimated percent chance.
double estimateChancePercent(double requiredFinal) {
  if (requiredFinal.isNaN) return 0.0;
  if (requiredFinal > 100) return 0.0;
  if (requiredFinal <= 0) return 99.0;

  // Logistic: p = 1 - sigmoid((r - 50) / 10)
  final x = (requiredFinal - 50.0) / 10.0;
  // Use standard sigmoid( z ) = 1/(1+exp(-z)). We invert it so that lower
  // requiredFinal -> higher probability: p = 1 - sigmoid(x)
  final sigmoid = 1.0 / (1.0 + math.exp(-x));
  final p = (1.0 - sigmoid) * 100.0;
  return p.clamp(0.0, 100.0);
}
