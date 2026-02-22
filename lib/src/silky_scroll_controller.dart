import 'dart:ui';
import 'package:flutter/material.dart';

/// A [ScrollController] that intercepts mouse‑wheel events.
///
/// [SilkyScroll] creates this controller internally. It delegates
/// position management to the user-supplied (or auto-created)
/// [clientController] so that offsets stay in sync.
final class SilkyScrollController extends ScrollController {
  SilkyScrollController({required this.clientController});

  late final ScrollController clientController;

  SilkyScrollPosition? currentSilkyScrollPosition;

  void setPointerDeviceKind(PointerDeviceKind pointerDeviceKind) {
    if (currentSilkyScrollPosition != null) {
      currentSilkyScrollPosition!.kind = pointerDeviceKind;
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    currentSilkyScrollPosition = SilkyScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      initialPixels: initialScrollOffset,
    );
    return currentSilkyScrollPosition!;
  }

  @override
  void attach(ScrollPosition position) {
    // Guard: only attach to clientController if not already attached,
    // preventing duplicate position registration.
    if (!clientController.positions.contains(position)) {
      clientController.attach(position);
    }
    super.attach(position);
  }

  @override
  void detach(ScrollPosition position) {
    // Guard: only detach from clientController if still attached.
    if (clientController.positions.contains(position)) {
      clientController.detach(position);
    }
    super.detach(position);
  }
}

/// A scroll position that filters [pointerScroll] based on the
/// current [PointerDeviceKind], allowing [SilkyScroll] to handle
/// mouse-wheel events with its own animation pipeline.
final class SilkyScrollPosition extends ScrollPositionWithSingleContext {
  SilkyScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required double super.initialPixels,
  });

  PointerDeviceKind kind = PointerDeviceKind.trackpad;

  /// When `true`, [goBallistic] is suppressed to prevent Flutter's
  /// physics-based spring simulation from fighting with the
  /// Ticker-driven smooth-scroll / recoil animation.
  ///
  /// Without this, every [jumpTo] call during overscroll triggers
  /// [BouncingScrollPhysics.createBallisticSimulation], which starts
  /// a spring that pulls the offset back — while our Ticker pushes
  /// it forward.  The two fight each other every frame, producing
  /// visible stutter.
  bool silkyTickerActive = false;

  @override
  void goBallistic(double velocity) {
    if (silkyTickerActive) return;
    super.goBallistic(velocity);
  }

  @override
  void pointerScroll(double delta) {
    if (kind != PointerDeviceKind.mouse) {
      super.pointerScroll(delta);

      return;
    }
  }
}
