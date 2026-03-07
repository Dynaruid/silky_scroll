import 'dart:math';
import 'package:flutter/material.dart';

/// Threshold (in logical pixels) used for sub-pixel edge comparison.
const double _kEdgeThreshold = 0.5;

/// Pure edge-detection and locking utilities.
///
/// Extracted from [SilkyScrollState] to follow the Single
/// Responsibility Principle.
@immutable
final class SilkyEdgeDetector {
  const SilkyEdgeDetector();

  /// Returns `-1` if at the top/start edge with velocity toward it,
  /// `1` if at the bottom/end edge with velocity toward it,
  /// and `0` otherwise.
  ///
  /// [velocity] is the signed scroll velocity (px / frame).  Only the
  /// sign selects which edge to test; the magnitude is clamped to a
  /// small lookahead window.  Velocities below 0.5 px/frame are
  /// treated as stationary and always return `0`.
  int checkOffsetAtEdge(double velocity, ScrollController controller) {
    if (!controller.hasClients || velocity.abs() < _kEdgeThreshold) return 0;

    final double offset = controller.offset;
    final double maxExtent = controller.position.maxScrollExtent;

    if (velocity < 0) {
      return (max(velocity, -2) + offset) < _kEdgeThreshold ? -1 : 0;
    }
    final double dest = min(velocity, 2) + offset;
    return (dest - maxExtent).abs() < _kEdgeThreshold || dest > maxExtent
        ? 1
        : 0;
  }
}
