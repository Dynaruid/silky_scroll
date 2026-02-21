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

  /// Returns `-1` if at the top/start edge, `1` if at the bottom/end edge,
  /// and `0` if not at an edge.
  int checkOffsetAtEdge(double verticalDelta, ScrollController controller) {
    if (!controller.hasClients) return 0;

    final double offset = controller.offset;
    final double maxExtent = controller.position.maxScrollExtent;

    return switch (verticalDelta) {
      final d when d.isNegative =>
        (max(d, -2) + offset) < _kEdgeThreshold ? -1 : 0,
      final d => () {
        final dest = min(d, 2) + offset;
        return (dest - maxExtent).abs() < _kEdgeThreshold || dest > maxExtent
            ? 1
            : 0;
      }(),
    };
  }
}
