import 'dart:ui';
import 'package:flutter/material.dart';

class SilkyScrollController extends ScrollController {
  late final ScrollController clientController;

  SilkyScrollPosition? currentsSilkyScrollPosition;

  SilkyScrollController({required this.clientController});

  void setPointerDeviceKind(PointerDeviceKind pointerDeviceKind) {
    if (currentsSilkyScrollPosition != null) {
      currentsSilkyScrollPosition!.kind = pointerDeviceKind;
    }
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics,
      ScrollContext context, ScrollPosition? oldPosition) {
    currentsSilkyScrollPosition = SilkyScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      initialPixels: initialScrollOffset,
    );
    return currentsSilkyScrollPosition!;
  }

  @override
  void attach(ScrollPosition position) {
    clientController.attach(position);
    super.attach(position);
  }

  @override
  void detach(ScrollPosition position) {
    clientController.detach(position);
    super.detach(position);
  }
}

class SilkyScrollPosition extends ScrollPositionWithSingleContext {
  SilkyScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required double super.initialPixels,
  });

  PointerDeviceKind kind = PointerDeviceKind.trackpad;

  @override
  void pointerScroll(double delta) {
    if (kind != PointerDeviceKind.mouse) {
      super.pointerScroll(delta);
      return;
    }
  }
}
