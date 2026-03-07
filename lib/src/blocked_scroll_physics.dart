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
