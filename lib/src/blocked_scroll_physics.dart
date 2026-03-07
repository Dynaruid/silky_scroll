import 'package:flutter/material.dart';

/// Scroll physics that completely blocks scrolling.
///
/// Used internally by [SilkyScroll] to temporarily disable scroll
/// when the scrollable content has reached an edge.
final class BlockedScrollPhysics extends NeverScrollableScrollPhysics {
  const BlockedScrollPhysics({super.parent});

  @override
  BlockedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BlockedScrollPhysics(parent: buildParent(ancestor));
  }
}

/// Scroll physics that blocks scrolling in one direction only.
///
/// Used for touch-based edge locking so that inward scrolling (away from
/// the edge) remains possible while outward scrolling is suppressed.
final class DirectionalBlockedScrollPhysics extends ScrollPhysics {
  const DirectionalBlockedScrollPhysics({
    required this.blockedDirection,
    super.parent,
  });

  /// The edge direction to block.
  ///
  /// * `-1` — at the start edge: blocks drag that moves viewport toward start.
  /// * `1`  — at the end edge: blocks drag that moves viewport toward end.
  final int blockedDirection;

  @override
  DirectionalBlockedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return DirectionalBlockedScrollPhysics(
      blockedDirection: blockedDirection,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // In Flutter's scroll system:
    //   pixels_new = pixels - applyPhysicsToUserOffset(position, offset)
    //
    // At the start edge (blockedDirection == -1):
    //   outward drag has offset > 0 → pixels decreases → blocked
    // At the end edge (blockedDirection == 1):
    //   outward drag has offset < 0 → pixels increases → blocked
    //
    // Compactly: outward when blockedDirection * offset < 0
    if (blockedDirection * offset < 0) return 0.0;
    return super.applyPhysicsToUserOffset(position, offset);
  }
}
