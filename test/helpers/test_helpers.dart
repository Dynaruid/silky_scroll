import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:silky_scroll/src/silky_scroll_mouse_pointer_manager.dart';
import 'package:silky_scroll/src/silky_scroll_state.dart';

/// Builds a minimal scrollable widget tree with the given [controller].
Widget pumpSilkyScroll({
  required ScrollController controller,
  int itemCount = 50,
  double itemHeight = 100,
}) {
  return MaterialApp(
    home: ListView.builder(
      controller: controller,
      itemCount: itemCount,
      itemBuilder: (_, i) => SizedBox(height: itemHeight, child: Text('$i')),
    ),
  );
}

/// Creates a [SilkyScrollState] with sensible defaults for testing.
SilkyScrollState createTestState({
  ScrollController? scrollController,
  ScrollPhysics physics = const ScrollPhysics(),
  Duration edgeLockingDelay = const Duration(milliseconds: 650),
  double scrollSpeed = 1,
  Duration silkyScrollDuration = const Duration(milliseconds: 700),
  Curve animationCurve = Curves.easeOutQuart,
  bool isVertical = true,
  bool enableScrollBubbling = false,
  bool debugMode = false,
  void Function(double delta)? onScroll,
  void Function(double delta)? onEdgeOverScroll,
  Function(PointerDeviceKind)? setManualPointerDeviceKind,
  SilkyScrollMousePointerManager? manager,
}) {
  manager ??= SilkyScrollMousePointerManager();
  return SilkyScrollState(
    scrollController: scrollController,
    widgetScrollPhysics: physics,
    edgeLockingDelay: edgeLockingDelay,
    scrollSpeed: scrollSpeed,
    silkyScrollDuration: silkyScrollDuration,
    animationCurve: animationCurve,
    isVertical: isVertical,
    enableScrollBubbling: enableScrollBubbling,
    debugMode: debugMode,
    onScroll: onScroll,
    onEdgeOverScroll: onEdgeOverScroll,
    setManualPointerDeviceKind: setManualPointerDeviceKind,
    silkyScrollMousePointerManager: manager,
  );
}
