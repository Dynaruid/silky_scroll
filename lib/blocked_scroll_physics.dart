import 'package:flutter/material.dart';

class BlockedScrollPhysics extends NeverScrollableScrollPhysics {
  const BlockedScrollPhysics({super.parent});

  @override
  BlockedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BlockedScrollPhysics(parent: buildParent(ancestor));
  }
}
